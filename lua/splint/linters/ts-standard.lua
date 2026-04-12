local binary_name = "ts-standard"
local pattern = "[^:]+:(%d+):(%d+):([^%.]+%.?)%s%(([%a-]+)%)%s?%(?(%a*)%)?"
local groups = { "lnum", "col", "message", "code", "severity" }
local severities = {
  [""] = vim.diagnostic.severity.ERROR,
  ["warning"] = vim.diagnostic.severity.WARN,
}

return {
  cmd = function(ctx)
    local local_binary = ctx.cwd .. '/node_modules/.bin/' .. binary_name
    return vim.loop.fs_stat(local_binary) and local_binary or binary_name
  end,
  stdin = true,
  args = { "--stdin" },
  ignore_exitcode = true,
  parser = require("splint.parser").from_pattern(pattern, groups, severities, { ["source"] = "ts-standard" }, {}),
}
