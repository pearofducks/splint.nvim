local M = {}
local h = vim.health

function M.check()
  h.start("splint")

  -- Check if enabled
  local ok, aus = pcall(vim.api.nvim_get_autocmds, { group = "splint" })
  if not ok or #aus == 0 then
    h.warn("splint is not enabled. Call `require('splint').enable()`")
  else
    local events = {}
    for _, au in ipairs(aus) do
      events[au.event] = true
    end
    h.ok("enabled (events: " .. table.concat(vim.tbl_keys(events), ", ") .. ")")
  end

  -- Check linters for current buffer's filetype
  local splint = require("splint")
  local ft = vim.bo.filetype
  if ft == "" then
    h.info("current buffer has no filetype set")
    return
  end

  local names = splint.linters_by_ft[ft]
  if not names then
    -- Try compound filetype decomposition
    local dedup = {}
    for _, sub in ipairs(vim.split(ft, ".", { plain = true })) do
      local sub_names = splint.linters_by_ft[sub]
      if sub_names then
        for _, name in ipairs(sub_names) do
          dedup[name] = true
        end
      end
    end
    local keys = vim.tbl_keys(dedup)
    if #keys == 0 then
      h.info("no linters configured for filetype: " .. ft)
      return
    end
    names = keys
  end

  local stop_after_first = names.stop_after_first or false
  if stop_after_first then
    h.info("filetype `" .. ft .. "`: stop_after_first = true")
  end

  local dirname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":h")
  local selected = false

  for i, name in ipairs(names) do
    local linter = splint.linters[name]
    if not linter then
      h.error(name .. " — not found")
      goto continue
    end
    if type(linter) == "function" then
      local fn_ok, result = pcall(linter)
      if not fn_ok then
        h.error(name .. " — failed to resolve: " .. tostring(result))
        goto continue
      end
      linter = result
    end

    -- Resolve cmd
    local cmd = linter.cmd
    if type(cmd) == "function" then
      local fn_ok, result = pcall(cmd, {
        bufnr = 0,
        filename = vim.api.nvim_buf_get_name(0),
        dirname = dirname,
        cwd = vim.fn.getcwd(),
      })
      if fn_ok then
        cmd = result
      else
        cmd = name
      end
    end

    local executable = cmd and vim.fn.executable(cmd) == 1
    local parts = {}

    -- cmd status
    if executable then
      table.insert(parts, "cmd: `" .. cmd .. "` (found)")
    else
      table.insert(parts, "cmd: `" .. tostring(cmd) .. "` (not found)")
    end

    -- config_files status
    if linter.config_files then
      local found = vim.fs.find(linter.config_files, { path = dirname, upward = true })
      if #found > 0 then
        table.insert(parts, "config: " .. found[1])
      else
        table.insert(parts, "config: none found (" .. table.concat(linter.config_files, ", ") .. ")")
      end
    end

    -- stop_after_first selection
    local skipped = false
    if stop_after_first and not selected then
      if not executable then
        skipped = true
      elseif linter.config_files then
        local found = vim.fs.find(linter.config_files, { path = dirname, upward = true })
        if #found == 0 then skipped = true end
      end
      if linter.condition then
        local ctx = {
          bufnr = vim.api.nvim_get_current_buf(),
          filename = vim.api.nvim_buf_get_name(0),
          dirname = dirname,
          cwd = vim.fn.getcwd(),
        }
        if not linter.condition(ctx) then skipped = true end
      end
    end

    local prefix = ""
    if stop_after_first then
      if not selected and not skipped then
        selected = true
        prefix = " (selected)"
      elseif selected then
        prefix = " (skipped — earlier linter selected)"
      elseif skipped then
        prefix = " (skipped)"
      end
    end

    local msg = name .. prefix .. " — " .. table.concat(parts, ", ")
    if not executable then
      h.warn(msg)
    else
      h.ok(msg)
    end

    ::continue::
  end
end

return M
