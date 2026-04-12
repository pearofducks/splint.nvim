local severities = {
  warning = vim.diagnostic.severity.WARN,
  error = vim.diagnostic.severity.ERROR,
}

return {
  cmd = function(ctx)
    local local_stylelint = ctx.cwd .. '/node_modules/.bin/stylelint'
    local stat = vim.loop.fs_stat(local_stylelint)
    if stat then
      return local_stylelint
    end
    return "stylelint"
  end,
  config_files = {
    ".stylelintrc", ".stylelintrc.json", ".stylelintrc.yaml", ".stylelintrc.yml",
    ".stylelintrc.js", ".stylelintrc.cjs", ".stylelintrc.mjs",
    "stylelint.config.js", "stylelint.config.cjs", "stylelint.config.mjs",
  },
  stdin = true,
  args = {
    "-f",
    "json",
    "--stdin",
    "--stdin-filename",
    function(ctx)
      return ctx.filename
    end,
  },
  stream = "both",
  ignore_exitcode = true,
  parser = function (output)
    local status, decoded = pcall(vim.json.decode, output)
    if status then
      decoded = decoded[1]
    else
      decoded = {
        warnings = {
          {
            line = 1,
            column = 1,
            text = "Stylelint error, run `stylelint " .. vim.fn.expand("%") .. "` for more info.",
            severity = "error",
            rule = "none",
          },
        },
        errored = true,
      }
    end
    local diagnostics = {}
    for _, message in ipairs(decoded.warnings) do
      table.insert(diagnostics, {
        lnum = message.line - 1,
        col = message.column - 1,
        end_lnum = message.line - 1,
        end_col = message.column - 1,
        message = message.text,
        code = message.rule,
        user_data = {
          lsp = {
            code = message.rule,
          },
        },
        severity = severities[message.severity],
        source = "stylelint",
      })
    end
    return diagnostics
  end
}
