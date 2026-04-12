local binary_name = "eslint_d"
return {
  cmd = function(ctx)
    local local_binary = ctx.cwd .. '/node_modules/.bin/' .. binary_name
    return vim.loop.fs_stat(local_binary) and local_binary or binary_name
  end,
  config_files = {
    "eslint.config.js", "eslint.config.mjs", "eslint.config.cjs",
    "eslint.config.ts", "eslint.config.mts", "eslint.config.cts",
    ".eslintrc.js", ".eslintrc.cjs", ".eslintrc.json", ".eslintrc.yml", ".eslintrc.yaml",
  },
  args = {
    '--format',
    'json',
    '--stdin',
    '--stdin-filename',
    function(ctx) return ctx.filename end,
  },
  stdin = true,
  stream = 'stdout',
  ignore_exitcode = true,
  parser = function(output, bufnr)
    if string.find(output, "Error: Could not find config file") then
      return {}
    end
    local result = require("splint.linters.eslint").parser(output, bufnr)
    for _, d in ipairs(result) do
      d.source = binary_name
    end
    return result
  end
}
