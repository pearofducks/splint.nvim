local efm = "stdin:%l:%c %m,stdin:%l %m"
return {
  cmd = "markdownlint",
  stdin = true,
  args = { "--stdin" },
  ignore_exitcode = true,
  stream = "stderr",
  parser = require("splint.parser").from_errorformat(efm, {
    source = "markdownlint",
    severity = vim.diagnostic.severity.WARN,
  }),
}
