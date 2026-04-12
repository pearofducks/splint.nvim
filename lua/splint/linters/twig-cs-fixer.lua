local pattern = '^::(%a+) file=([^,]+),line=(%d+),col=(%d+)::(.+):%d+:%d+ %-%- (.+)'
local groups = { 'severity', 'file', 'lnum', 'col', 'code', 'message' }
local severity_map = {
  ['error'] = vim.diagnostic.severity.ERROR,
}

local bin = 'twig-cs-fixer'
return {
  cmd = function(ctx)
    local local_bin = ctx.cwd .. '/vendor/bin/' .. bin
    return vim.loop.fs_stat(local_bin) and local_bin or bin
  end,
  stdin = false,
  args = {
    'lint',
    '--report',
    'github',
    '--debug',
  },
  stream = 'stdout',
  ignore_exitcode = true,
  parser = require("splint.parser").from_pattern(pattern, groups, severity_map, { ["source"] = "twig-cs-fixer" }),
}
