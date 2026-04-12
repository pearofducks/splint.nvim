local uv = vim.loop
local api = vim.api
local notify = vim.notify_once or vim.notify
local M = {}

---@type table<integer, table<string, splint.LintProc>>
local running_procs_by_buf = {}

local namespaces = setmetatable({}, {
  __index = function(tbl, key)
    local ns = api.nvim_create_namespace(key)
    rawset(tbl, key, ns)
    return ns
  end,
})

local augroup_name = "splint"


---A table listing which linters to run via `try_lint`.
---The key is the filetype. The values are a list of linter names.
---
---Set `stop_after_first` to `true` to only run the first available linter
---in the list. When set, linters are tried in order. A linter is skipped if:
---  - Its command is not executable
---  - It declares `config_files` and none are found upward from the buffer
---  - It declares `condition` and it returns false
---
---```lua
---require("splint").linters = {
---  python = {"ruff", "mypy"},
---  javascript = {"eslint", "oxlint", stop_after_first = true},
---}
---```
---
---@type table<string, string[]>
M.linters = {}


---Table of linter definitions. Lazy-loads built-in linters from `splint.linters.*`.
---@type table<string, splint.Linter|fun():splint.Linter>
M.available_linters = setmetatable({}, {
  __index = function(_, key)
    local ok, linter = pcall(require, "splint.linters." .. key)
    if ok then
      return linter
    end
    return nil
  end,
})


---@class splint.Linter
---@field name string
---@field cmd string|fun(ctx: splint.Context): string
---@field args? (string|fun(ctx: splint.Context): string)[]
---@field stdin? boolean send content via stdin. Defaults to false
---@field append_fname? boolean auto-append filename when stdin=false. Defaults to true
---@field stream? 'stdout'|'stderr'|'both' defaults to 'stdout'
---@field ignore_exitcode? boolean defaults to true
---@field env? table<string, string>
---@field cwd? string
---@field parser splint.Parser|splint.parse
---@field config_files? string[] known config file names, used by stop_after_first
---@field condition? fun(ctx: splint.Context): boolean

---@class splint.Context
---@field bufnr integer
---@field filename string
---@field dirname string
---@field cwd string

---@alias splint.parse fun(output: string, bufnr: integer, linter_cwd: string): vim.Diagnostic[]

---@class splint.Parser
---@field on_chunk fun(chunk: string)
---@field on_done fun(publish: fun(diagnostics: vim.Diagnostic[]), bufnr: integer, linter_cwd: string)

---@class splint.LintProc
---@field bufnr integer
---@field handle uv.uv_process_t
---@field stdout uv.uv_pipe_t
---@field stderr uv.uv_pipe_t
---@field linter splint.Linter
---@field cwd string
---@field ns integer
---@field cancelled boolean


-- ---------------------------------------------------------------------------
-- Internal: LintProc
-- ---------------------------------------------------------------------------

local LintProc = {}
local linter_proc_mt = { __index = LintProc }

function LintProc:publish(diagnostics)
  if api.nvim_buf_is_valid(self.bufnr) and not self.cancelled then
    vim.diagnostic.set(self.ns, self.bufnr, diagnostics)
  end
  self.stdout:shutdown()
  self.stdout:close()
  self.stderr:shutdown()
  self.stderr:close()
end

function LintProc:cancel()
  self.cancelled = true
  local handle = self.handle
  if not handle or handle:is_closing() then
    return
  end
  handle:kill("sigint")
  vim.defer_fn(function()
    if not handle:is_closing() then
      handle:kill("sigkill")
    end
  end, 2000)
end


-- ---------------------------------------------------------------------------
-- Internal: streaming parsers
-- ---------------------------------------------------------------------------

local parse_failure_msg = "Parser failed. Error message:\n%s\n\nOutput from linter:\n%s\n"

local function accumulate_chunks(parse)
  local chunks = {}
  return {
    on_chunk = function(chunk)
      table.insert(chunks, chunk)
    end,
    on_done = function(publish, bufnr, linter_cwd)
      vim.schedule(function()
        local output = table.concat(chunks)
        if api.nvim_buf_is_valid(bufnr) and output ~= "" then
          local ok, diagnostics
          api.nvim_buf_call(bufnr, function()
            ok, diagnostics = pcall(parse, output, bufnr, linter_cwd)
          end)
          if not ok then
            diagnostics = { {
              bufnr = bufnr, lnum = 0, col = 0,
              message = string.format(parse_failure_msg, diagnostics, output),
              severity = vim.diagnostic.severity.ERROR,
            } }
          end
          publish(diagnostics, bufnr)
        else
          publish({}, bufnr)
        end
      end)
    end,
  }
end

local function split_parser(parser)
  local remaining = 2
  local chunks1, chunks2 = {}, {}
  local function on_done(publish, bufnr, cwd)
    remaining = remaining - 1
    if remaining == 0 then
      for _, c in ipairs(chunks1) do parser.on_chunk(c) end
      for _, c in ipairs(chunks2) do parser.on_chunk(c) end
      parser.on_done(publish, bufnr, cwd)
    end
  end
  return
    { on_chunk = function(c) table.insert(chunks1, c) end, on_done = on_done },
    { on_chunk = function(c) table.insert(chunks2, c) end, on_done = on_done }
end

local function read_output(cwd, bufnr, parser, publish_fn)
  return function(err, chunk)
    assert(not err, err)
    if chunk then
      parser.on_chunk(chunk, bufnr)
    else
      parser.on_done(publish_fn, bufnr, cwd)
    end
  end
end


function LintProc:start_read()
  local self_ = self
  local publish = function(diagnostics) self_:publish(diagnostics) end
  local parser = self.linter.parser
  if type(parser) == "function" then
    parser = accumulate_chunks(parser)
  end
  local stream = self.linter.stream
  local cwd, bufnr = self.cwd, self.bufnr
  if not stream or stream == "stdout" then
    self.stdout:read_start(read_output(cwd, bufnr, parser, publish))
  elseif stream == "stderr" then
    self.stderr:read_start(read_output(cwd, bufnr, parser, publish))
  elseif stream == "both" then
    local p1, p2 = split_parser(parser)
    self.stdout:read_start(read_output(cwd, bufnr, p1, publish))
    self.stderr:read_start(read_output(cwd, bufnr, p2, publish))
  end
end


-- ---------------------------------------------------------------------------
-- Internal: spawn
-- ---------------------------------------------------------------------------

local function eval(x, ctx)
  if type(x) == "function" then
    return x(ctx)
  end
  return x
end

---@param linter splint.Linter
---@param ctx splint.Context
---@param ignore_errors? boolean
---@return splint.LintProc|nil
local function spawn(linter, ctx, ignore_errors)
  local stdin = assert(uv.new_pipe(false))
  local stdout = assert(uv.new_pipe(false))
  local stderr = assert(uv.new_pipe(false))
  local bufnr = ctx.bufnr
  local cwd = ctx.cwd

  local args = {}
  if linter.args then
    for _, a in ipairs(linter.args) do
      table.insert(args, eval(a, ctx))
    end
  end
  if not linter.stdin and linter.append_fname ~= false then
    table.insert(args, ctx.filename)
  end

  local env
  if linter.env then
    env = {}
    if not linter.env["PATH"] then
      table.insert(env, "PATH=" .. os.getenv("PATH"))
    end
    for k, v in pairs(linter.env) do
      table.insert(env, k .. "=" .. v)
    end
  end

  local cmd = eval(linter.cmd, ctx)
  assert(cmd, "Linter definition must have a `cmd` set: " .. vim.inspect(linter))

  local handle, pid_or_err = uv.spawn(cmd, {
    args = args,
    stdio = { stdin, stdout, stderr },
    env = env,
    cwd = cwd,
    detached = true,
  }, function(code)
    if handle and not handle:is_closing() then
      local procs = running_procs_by_buf[bufnr] or {}
      local proc = procs[linter.name] or {}
      if handle == proc.handle then
        procs[linter.name] = nil
        if not next(procs) then
          running_procs_by_buf[bufnr] = nil
        end
      end
      handle:close()
    end
    if code ~= 0 and linter.ignore_exitcode == false then
      vim.schedule(function()
        vim.notify("Linter `" .. cmd .. "` exited with code: " .. code, vim.log.levels.WARN)
      end)
    end
  end)

  if not handle then
    stdout:close()
    stderr:close()
    stdin:close()
    if not ignore_errors then
      vim.notify("Error running " .. cmd .. ": " .. pid_or_err, vim.log.levels.ERROR)
    end
    return nil
  end

  local proc = setmetatable({
    bufnr = bufnr,
    stdout = stdout,
    stderr = stderr,
    handle = handle,
    linter = linter,
    cwd = cwd,
    ns = namespaces[linter.name],
    cancelled = false,
  }, linter_proc_mt)
  proc:start_read()

  if linter.stdin then
    local lines = api.nvim_buf_get_lines(bufnr, 0, -1, true)
    local content = table.concat(lines, "\n") .. "\n"
    stdin:write(content, function()
      stdin:shutdown(function()
        stdin:close()
      end)
    end)
  else
    stdin:close()
  end

  return proc
end


-- ---------------------------------------------------------------------------
-- Internal: resolution
-- ---------------------------------------------------------------------------

---@param ft string
---@return string[] names
---@return boolean stop_after_first
local function resolve_linters(ft)
  local names = M.linters[ft]
  if names then
    return names, names.stop_after_first or false
  end
  local dedup = {}
  for _, sub in ipairs(vim.split(ft, ".", { plain = true })) do
    local linters = M.linters[sub]
    if linters then
      for _, name in ipairs(linters) do
        dedup[name] = true
      end
    end
  end
  return vim.tbl_keys(dedup), false
end

---@param name string
---@return splint.Linter|nil
local function lookup_linter(name)
  local linter = M.available_linters[name]
  if not linter then return nil end
  if type(linter) == "function" then
    linter = linter()
  end
  linter.name = linter.name or name
  return linter
end

---@param bufnr integer
---@return splint.Context
local function build_ctx(bufnr)
  local filename = api.nvim_buf_get_name(bufnr)
  local dirname = vim.fn.fnamemodify(filename, ":h")
  return {
    bufnr = bufnr,
    filename = filename,
    dirname = dirname,
    cwd = vim.fn.getcwd(),
  }
end


-- ---------------------------------------------------------------------------
-- Internal: core lint loop
-- ---------------------------------------------------------------------------

---@param bufnr integer
---@param names? string[]
local function do_lint(bufnr, names)
  local stop_after_first = false
  if not names then
    local ft = vim.bo[bufnr].filetype
    names, stop_after_first = resolve_linters(ft)
  end
  if #names == 0 then return end

  local ctx = build_ctx(bufnr)
  local running_procs = running_procs_by_buf[bufnr] or {}

  for _, name in ipairs(names) do
    local linter = lookup_linter(name)
    if not linter then
      if not stop_after_first then
        notify("Linter `" .. name .. "` not found", vim.log.levels.WARN)
      end
      goto continue
    end

    if stop_after_first then
      if linter.config_files then
        if #vim.fs.find(linter.config_files, { path = ctx.dirname, upward = true }) == 0 then
          goto continue
        end
      end
      if linter.condition and not linter.condition(ctx) then
        goto continue
      end
    end

    -- Use linter.cwd if set, otherwise the editor's cwd
    ctx.cwd = linter.cwd or ctx.cwd

    local proc = running_procs[linter.name]
    if proc then proc:cancel() end
    running_procs[linter.name] = nil

    local ok, result = pcall(spawn, linter, ctx, stop_after_first)
    if ok and result then
      running_procs[linter.name] = result
      if stop_after_first then break end
    elseif not ok and not stop_after_first then
      notify(result --[[@as string]], vim.log.levels.WARN)
    end

    ::continue::
  end

  if stop_after_first and not next(running_procs) then
    notify("No linter available: " .. table.concat(names, ", "), vim.log.levels.WARN)
  end

  running_procs_by_buf[bufnr] = running_procs
end


-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Start linting. Creates autocommands that run configured linters
--- automatically, and a `:Splint` command for manual use.
---
---```lua
---require("splint").enable()
---
----- or with custom events:
---require("splint").enable({ events = { "BufWritePost", "InsertLeave" } })
---```
---
---@param opts? { events?: string[] }
function M.enable(opts)
  opts = opts or {}
  local events = opts.events or { "BufWritePost", "BufReadPost" }
  local group = api.nvim_create_augroup(augroup_name, { clear = true })

  api.nvim_create_autocmd(events, {
    group = group,
    callback = function(ev)
      do_lint(ev.buf)
    end,
  })

  api.nvim_create_user_command("Splint", function(cmd_opts)
    local bufnr = api.nvim_get_current_buf()
    if cmd_opts.args ~= "" then
      do_lint(bufnr, vim.split(cmd_opts.args, "%s+"))
    else
      do_lint(bufnr)
    end
  end, {
    nargs = "?",
    desc = "Run linters on the current buffer",
  })
end

--- Stop linting. Removes autocommands and the `:Splint` command.
function M.disable()
  pcall(api.nvim_del_augroup_by_name, augroup_name)
  pcall(api.nvim_del_user_command, "Splint")
end

return M
