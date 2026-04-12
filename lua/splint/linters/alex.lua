local pattern = "%s*(%d+):(%d+)-(%d+):(%d+)%s+(%w+)%s+(.-)%s+%s+(%g+)%s+%g+"
local groups = { "lnum", "col", "end_lnum", "end_col", "severity", "message", "code" }
local severity_map = {
  warning = vim.diagnostic.severity.WARN,
  error = vim.diagnostic.severity.ERROR,
}

return {
  cmd = "alex",
  stdin = true,
  stream = "stderr",
  ignore_exitcode = true,
  args = {
    "--stdin",
    function(ctx)
      if vim.bo[ctx.bufnr].filetype == "html" then
        return "--html"
      elseif vim.bo[ctx.bufnr].filetype ~= "markdown" then
        return "--text"
      end
    end,
  },
  parser = require("splint.parser").from_pattern(
    pattern,
    groups,
    severity_map,
    { severity = vim.diagnostic.severity.WARN, source = "alex" }
  ),
}
