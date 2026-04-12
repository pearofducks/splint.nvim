return {
  cmd = "yq",
  stdin = true,
  stream = "stderr",
  ignore_exitcode = true,
  parser = require("splint.parser").from_pattern("line (%d+): (.+)", {
    "lnum",
    "message",
  }, nil, { source = "yq" }),
}
