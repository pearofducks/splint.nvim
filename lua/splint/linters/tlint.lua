local bin = 'tlint'

return {
  cmd = function(ctx)
    local local_bin = ctx.cwd .. '/vendor/bin/' .. bin
    return vim.loop.fs_stat(local_bin) and local_bin or bin
  end,
  stdin = false,
  args = { 'lint', '--json' },
  parser = function(output)
    if output == nil then
      return {}
    end

    local diagnostics = {}

    for _, message in ipairs(vim.json.decode(output).errors or {}) do
      table.insert(diagnostics, {
        lnum = message.line - 1,
        col = 0,
        message = message.message,
        source = bin,
      })
    end

    return diagnostics
  end,
}
