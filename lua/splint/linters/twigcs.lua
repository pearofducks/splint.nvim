local errorformat = '%f:%l:%c: %trror - %m'

return {
  cmd = 'twigcs',
  stream = 'both',
  ignore_exitcode = true,
  stdin = false,
  args = {
    '--reporter=emacs',
  },
  parser = require('splint.parser').from_errorformat(errorformat, { source = 'twigcs' }),
}
