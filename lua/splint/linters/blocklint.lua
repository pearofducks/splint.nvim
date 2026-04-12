return {
  cmd = "blocklint",
  args = { "--stdin", "--end-pos" },
  stdin = true,
  parser = require("splint.parser").from_errorformat("stdin:%l:%c:%k: %m", {
    source = "blocklint",
    severity = vim.diagnostic.severity.INFO,
  }),
}
