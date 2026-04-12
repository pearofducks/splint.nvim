local bin = 'phpstan'

return {
  cmd = function(ctx)
    local local_bin = ctx.cwd .. '/vendor/bin/' .. bin
    return vim.loop.fs_stat(local_bin) and local_bin or bin
  end,
  config_files = { "phpstan.neon", "phpstan.neon.dist", "phpstan.dist.neon" },
  args = {
    'analyze',
    '--error-format=json',
    '--no-progress',
  },
  ignore_exitcode = true,
  parser = function(output, bufnr)
    if vim.trim(output) == '' or output == nil then
      return {}
    end

    local file = vim.json.decode(output).files[vim.api.nvim_buf_get_name(bufnr)]

    if file == nil then
      return {}
    end

    local diagnostics = {}

    for _, message in ipairs(file.messages or {}) do
      table.insert(diagnostics, {
        lnum = type(message.line) == 'number' and (message.line - 1) or 0,
        col = 0,
        message = message.message,
        source = bin,
        code = message.identifier,
      })
    end

    return diagnostics
  end,
}
