-- perlimports requires both to read from stdin *and*
-- to have the filename appended.
return function()
  return {
    cmd = 'perlimports',
    stdin = true,
    args = { '--lint', '--json', '--read-stdin', '--filename', function(ctx) return ctx.filename end },
    stream = 'stderr',
    parser = function(output)
      local result = vim.fn.split(output, '\n')
      local diagnostics = {}
      for _, message in ipairs(result) do
        local decoded = vim.json.decode(message)
        table.insert(diagnostics, {
          lnum = decoded.location.start.line - 1,
          col = decoded.location.start.column - 1,
          end_lnum = decoded.location['end'].line - 1,
          end_col = decoded.location['end'].column - 1,
          severity = vim.diagnostic.severity.INFO,
          message = decoded.reason,
        })
      end
      return diagnostics
    end,
  }
end
