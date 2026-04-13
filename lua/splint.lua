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


---Last stderr output per linter, for diagnostics via `:checkhealth splint`.
---@type table<string, string>
M.last_stderr = {}


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
---@field sys vim.SystemObj
---@field linter splint.Linter
---@field cwd string
---@field ns integer
---@field cancelled boolean
---@field cancel fun(self: splint.LintProc)


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
---@param cwd string
---@param ignore_errors? boolean
---@return splint.LintProc|nil
local function spawn(linter, ctx, cwd, ignore_errors)
  local bufnr = ctx.bufnr
  local ns = namespaces[linter.name]

  local cmd = eval(linter.cmd, ctx)
  assert(cmd, "Linter definition must have a `cmd` set: " .. vim.inspect(linter))

  local args = {}
  if linter.args then
    for _, a in ipairs(linter.args) do
      args[#args + 1] = eval(a, ctx)
    end
  end
  if not linter.stdin and linter.append_fname ~= false then
    args[#args + 1] = ctx.filename
  end

  -- Parser + publish
  local parser = linter.parser
  if type(parser) == "function" then
    parser = accumulate_chunks(parser)
  end
  local cancelled = false
  local function publish(diagnostics)
    if api.nvim_buf_is_valid(bufnr) and not cancelled then
      vim.diagnostic.set(ns, bufnr, diagnostics)
    end
  end

  -- Stream routing
  local stream = linter.stream or "stdout"
  local stdout_cb, stderr_cb

  if stream == "stdout" then
    stdout_cb = read_output(cwd, bufnr, parser, publish)
    -- capture stderr for healthcheck diagnostics
    M.last_stderr[linter.name] = nil
    stderr_cb = function(_, data)
      if data then
        M.last_stderr[linter.name] = (M.last_stderr[linter.name] or "") .. data
      end
    end
  elseif stream == "stderr" then
    stderr_cb = read_output(cwd, bufnr, parser, publish)
  elseif stream == "both" then
    local p1, p2 = split_parser(parser)
    stdout_cb = read_output(cwd, bufnr, p1, publish)
    stderr_cb = read_output(cwd, bufnr, p2, publish)
  end

  -- Stdin content
  local stdin_data = nil
  if linter.stdin then
    local lines = api.nvim_buf_get_lines(bufnr, 0, -1, true)
    stdin_data = table.concat(lines, "\n") .. "\n"
  end

  local full_cmd = vim.list_extend({ cmd }, args)
  local sys_obj
  local ok, err = pcall(function()
    sys_obj = vim.system(full_cmd, {
      stdin = stdin_data,
      stdout = stdout_cb,
      stderr = stderr_cb,
      cwd = cwd,
      env = linter.env,
      detach = true,
    }, function(result)
      local procs = running_procs_by_buf[bufnr] or {}
      local proc = procs[linter.name]
      if proc and proc.sys == sys_obj then
        procs[linter.name] = nil
        if not next(procs) then
          running_procs_by_buf[bufnr] = nil
        end
      end
      if result.code ~= 0 and linter.ignore_exitcode == false then
        vim.schedule(function()
          vim.notify("Linter `" .. cmd .. "` exited with code: " .. result.code, vim.log.levels.WARN)
        end)
      end
    end)
  end)

  if not ok then
    if not ignore_errors then
      vim.notify("Error running " .. cmd .. ": " .. tostring(err), vim.log.levels.ERROR)
    end
    return nil
  end

  ---@type splint.LintProc
  local proc = {
    bufnr = bufnr,
    sys = sys_obj,
    linter = linter,
    cwd = cwd,
    ns = ns,
    cancelled = false,
    cancel = function(self)
      self.cancelled = true
      cancelled = true
      self.sys:kill("sigint")
      vim.defer_fn(function()
        pcall(function() self.sys:kill("sigkill") end)
      end, 2000)
    end,
  }

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
-- Internal: linter selection
-- ---------------------------------------------------------------------------

---@param names string[]
---@param ctx splint.Context
---@param stop_after_first boolean
---@return {linter: splint.Linter, cwd: string}[]
local function select_linters(names, ctx, stop_after_first)
  local selected = {}
  for _, name in ipairs(names) do
    local linter = lookup_linter(name)
    if not linter then
      if not stop_after_first then
        notify("Linter `" .. name .. "` not found", vim.log.levels.WARN)
      end
    elseif stop_after_first and linter.config_files
      and #vim.fs.find(linter.config_files, { path = ctx.dirname, upward = true }) == 0 then
      -- skip: no config file found
    elseif stop_after_first and linter.condition and not linter.condition(ctx) then
      -- skip: condition not met
    else
      table.insert(selected, {
        linter = linter,
        cwd = linter.cwd or ctx.cwd,
      })
      if stop_after_first then break end
    end
  end
  return selected
end


-- ---------------------------------------------------------------------------
-- Internal: core lint loop
-- ---------------------------------------------------------------------------

---@param bufnr_or_ev integer|table
---@param names? string[]
function M.lint(bufnr_or_ev, names)
  local bufnr = type(bufnr_or_ev) == "table" and bufnr_or_ev.buf or bufnr_or_ev
  local stop_after_first = false
  if not names then
    local ft = vim.bo[bufnr].filetype
    names, stop_after_first = resolve_linters(ft)
  end
  if #names == 0 then return end

  local ctx = build_ctx(bufnr)
  local candidates = select_linters(names, ctx, stop_after_first)
  local running_procs = running_procs_by_buf[bufnr] or {}

  for _, candidate in ipairs(candidates) do
    local linter = candidate.linter

    local proc = running_procs[linter.name]
    if proc then proc:cancel() end
    running_procs[linter.name] = nil

    local ok, result = pcall(spawn, linter, ctx, candidate.cwd, stop_after_first)
    if ok and result then
      running_procs[linter.name] = result
    elseif not ok and not stop_after_first then
      notify(result --[[@as string]], vim.log.levels.WARN)
    end
  end

  running_procs_by_buf[bufnr] = running_procs
end


-- ---------------------------------------------------------------------------
-- User command
-- ---------------------------------------------------------------------------

local function complete_linters()
  local seen = {}
  for _, names in pairs(M.linters) do
    for _, name in ipairs(names) do
      seen[name] = true
    end
  end
  return vim.tbl_keys(seen)
end

api.nvim_create_user_command("Splint", function(cmd_opts)
  local bufnr = api.nvim_get_current_buf()
  if cmd_opts.args ~= "" then
    M.lint(bufnr, vim.split(cmd_opts.args, "%s+")) -- split on whitespace
  else
    M.lint(bufnr)
  end
end, {
  nargs = "?",
  desc = "Run linters on the current buffer",
  complete = complete_linters,
})

return M
