local M = {}
local h = vim.health

--- Resolve the cmd string for a linter, using ctx if cmd is a function.
--- Falls back to the linter name if resolution fails.
---@param linter table
---@param name string
---@param ctx? table
---@return string
local function resolve_cmd(linter, name, ctx)
  local cmd = linter.cmd
  if type(cmd) == "function" then
    local ok, result = pcall(cmd, ctx or {})
    if ok and type(result) == "string" then
      return result
    end
    return name
  end
  return cmd or name
end

--- Resolve a linter definition by name.
---@param name string
---@return table|nil linter
---@return string|nil error
local function resolve_linter(name)
  local splint = require("splint")
  local linter = splint.available_linters[name]
  if not linter then
    return nil, "not found"
  end
  if type(linter) == "function" then
    local ok, result = pcall(linter)
    if not ok then
      return nil, "failed to resolve: " .. tostring(result)
    end
    linter = result
  end
  return linter, nil
end


--- Resolve linter names for a filetype, handling compound filetypes.
---@param ft string
---@return string[] names
---@return boolean stop_after_first
local function resolve_linters_for_ft(ft)
  local splint = require("splint")
  local names = splint.linters[ft]
  if names then
    return names, names.stop_after_first or false
  end
  local dedup = {}
  for _, sub in ipairs(vim.split(ft, ".", { plain = true })) do
    local sub_names = splint.linters[sub]
    if sub_names then
      for _, name in ipairs(sub_names) do
        if type(name) == "string" then
          dedup[name] = true
        end
      end
    end
  end
  return vim.tbl_keys(dedup), false
end

--- Build a context table for a buffer (mirrors build_ctx in splint.lua).
---@param bufnr integer
---@return table
local function build_ctx(bufnr)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local dirname = vim.fn.fnamemodify(filename, ":h")
  return {
    bufnr = bufnr,
    filename = filename,
    dirname = dirname,
    cwd = vim.fn.getcwd(),
  }
end

--- Report a single linter's status for a specific buffer context.
---@param name string
---@param ctx table
---@param stop_after_first boolean
---@param selected boolean  whether a prior linter was already selected
---@return boolean selected  updated selected state
local function report_linter(name, ctx, stop_after_first, selected)
  local linter, err = resolve_linter(name)
  if not linter then
    h.error(name .. " — " .. err)
    return selected
  end

  local cmd = resolve_cmd(linter, name, ctx)
  local executable = cmd and vim.fn.executable(cmd) == 1

  local parts = {}

  -- cmd status
  if executable then
    table.insert(parts, "cmd: `" .. cmd .. "` (found)")
  else
    table.insert(parts, "cmd: `" .. tostring(cmd) .. "` (not found)")
  end

  -- config_files status
  local has_config = true
  if linter.config_files then
    local found = vim.fs.find(linter.config_files, { path = ctx.dirname, upward = true })
    if #found > 0 then
      table.insert(parts, "config: " .. found[1])
    else
      has_config = false
      table.insert(parts, "config: none (" .. table.concat(linter.config_files, ", ") .. ")")
    end
  end

  -- condition status
  local condition_met = true
  if linter.condition then
    local cond_ok, cond_result = pcall(linter.condition, ctx)
    if cond_ok then
      condition_met = cond_result
      table.insert(parts, "condition: " .. (cond_result and "met" or "not met"))
    else
      condition_met = false
      table.insert(parts, "condition: error — " .. tostring(cond_result))
    end
  end

  -- stop_after_first selection logic
  local prefix = ""
  if stop_after_first then
    if selected then
      prefix = " (skipped — earlier linter selected)"
    elseif not executable or not has_config or not condition_met then
      prefix = " (skipped)"
    else
      selected = true
      prefix = " (selected)"
    end
  end

  local msg = name .. prefix .. " — " .. table.concat(parts, ", ")
  if not executable then
    h.warn(msg)
  else
    h.ok(msg)
  end

  return selected
end

function M.check()
  -- Per-buffer report
  local bufs = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local ft = vim.bo[bufnr].filetype
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      -- Skip unnamed buffers, health buffers, and buffers with no filetype
      if ft ~= "" and ft ~= "checkhealth" and ft ~= "health" and bufname ~= "" then
        table.insert(bufs, { bufnr = bufnr, ft = ft, name = bufname })
      end
    end
  end

  if #bufs == 0 then
    h.start("splint: open buffers")
    h.info("no open buffers with a filetype")
    return
  end

  table.sort(bufs, function(a, b) return a.name < b.name end)

  for _, buf in ipairs(bufs) do
    local short_name = vim.fn.fnamemodify(buf.name, ":~:.")
    local names, stop_after_first = resolve_linters_for_ft(buf.ft)

    local header = short_name .. " [" .. buf.ft .. "]"
    if stop_after_first then
      header = header .. " (stop_after_first)"
    end

    h.start("splint: " .. header)

    if #names == 0 then
      h.info("no linters configured")
    else
      local ctx = build_ctx(buf.bufnr)
      local selected = false
      for _, name in ipairs(names) do
        if type(name) == "string" then
          selected = report_linter(name, ctx, stop_after_first, selected)
        end
      end
    end
  end

  -- Section: last stderr output from linters
  local splint = require("splint")
  if next(splint.last_stderr) then
    h.start("splint: recent stderr")
    for name, output in pairs(splint.last_stderr) do
      h.warn(name .. ":\n" .. output)
    end
  end
end

return M
