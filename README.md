# splint.nvim

Async linter plugin for Neovim 0.12+. Runs linters, parses output, reports via `vim.diagnostic`.

## Install and use

```lua
vim.pack.add({ 'pearofducks/splint.nvim' })

local splint = require("splint")

splint.linters = {
  markdown = { "vale" },
  python = { "ruff", "mypy" },
  javascript = { "eslint" },
}

vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost" }, {
  callback = splint.lint,
})
```

## API

### `splint.lint(bufnr_or_ev, names?)`

Run linters on a buffer. Accepts a buffer number or an autocmd event table
(uses `ev.buf`). When `names` is omitted, linters are resolved from the
buffer's filetype via `splint.linters`.

```lua
-- As an autocmd callback (receives the event table directly)
vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost" }, {
  callback = splint.lint,
})

-- Programmatic use
splint.lint(bufnr)
splint.lint(bufnr, { "eslint", "ruff" })
```

### `:Splint [linter]`

User command registered when the module is loaded. Tab-completes configured
linter names.

```
:Splint          " run linters for current filetype
:Splint cspell   " run a specific linter
```

### Compound filetypes

A buffer with filetype `yaml.ghaction` matches linters registered under
`ghaction`, `yaml`, or `yaml.ghaction`.

### stop_after_first

Run only the first available linter for a filetype:

```lua
splint.linters = {
  javascript = { "eslint", "oxlint", stop_after_first = true },
}
```

Linters are tried in order and skipped if the command isn't found, declared
`config_files` are missing, or a `condition` function returns false.

## Available Linters

See [LINTERS.md](LINTERS.md) for the full list of 180+ built-in linters.

A generic `compiler` linter is also available -- it uses the buffer's `makeprg`
and `errorformat`.

## Customization

### Modify built-in linters

```lua
local phpcs = require("splint").available_linters.phpcs
phpcs.args = { "-q", "--report=json", "-" }
```

Some linters are wrapped in functions for lazy evaluation:

```lua
local original = require("splint").available_linters.terraform_validate
require("splint").available_linters.terraform_validate = function()
  local linter = original()
  linter.cmd = "my_custom"
  return linter
end
```

### config_files

Built-in linters declare `config_files` -- known config filenames for that
tool. Used by `stop_after_first` to pick the right linter. You can extend them:

```lua
local eslint = require("splint").available_linters.eslint
vim.list_extend(eslint.config_files, { ".my-eslintrc" })
```

### condition

For cases `config_files` can't express, use a `condition` function. Only
checked when `stop_after_first` is set:

```lua
require("splint").available_linters.eslint.condition = function(ctx)
  -- ctx: bufnr, filename, dirname, cwd
  return ctx.filename:match("_test%.js$") ~= nil
end
```

### Create new linters

```lua
require("splint").available_linters.my_linter = {
  cmd = "linter_cmd",       -- string or function(ctx)
  args = {},                 -- list of strings or function(ctx)
  stdin = true,              -- send buffer contents via stdin
  parser = parse_function,   -- function(output, bufnr, cwd) -> diagnostic[]
}
```

`parser` returns a list of diagnostics (see `:help diagnostic-structure`).

You can generate a parser using helpers from `require("splint.parser")`:

```lua
-- From errorformat
parser = require("splint.parser").from_errorformat(errorformat, skeleton)

-- From a Lua/LPEG pattern
parser = require("splint.parser").from_pattern(pattern, groups, severity_map, defaults, opts)

-- For SARIF output
parser = require("splint.parser").for_sarif(skeleton)
```

## Health check

`:checkhealth splint` reports:

1. Each open buffer's resolved linters -- command status, config files,
   conditions, and `stop_after_first` selection
2. Recent stderr output from linters (when the linter's output stream is stdout)

## Display configuration

See `:help vim.diagnostic.config`. To configure per linter:

```lua
vim.diagnostic.config(
  { virtual_text = true },
  vim.api.nvim_create_namespace("eslint")
)
```

## Security

Some linters use executables relative to the buffer's directory (e.g. eslint
uses `./node_modules/.bin/eslint`). Don't enable splint in untrusted repos.

## Development

```bash
make deps   # one-time: install test dependencies
make test   # run all tests
```
