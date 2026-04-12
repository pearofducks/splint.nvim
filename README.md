# splint.nvim

An asynchronous linter plugin for Neovim 0.12+ complementary to the
built-in Language Server Protocol support.

`splint.nvim` spawns linters, parses their output, and reports the results via
the `vim.diagnostic` module. It complements the built-in language server client
for languages where there are no language servers, or where standalone linters
provide better results.

## Installation

Requires Neovim >= 0.12.

```lua
vim.pack.add({ 'pearofducks/splint.nvim' })
```


## Usage

```lua
local splint = require("splint")

splint.linters_by_ft = {
  markdown = { "vale" },
  python = { "ruff", "mypy" },
  javascript = { "eslint" },
}

splint.enable()
```

`enable()` creates autocommands on `BufWritePost` and `BufReadPost` by default.
For more aggressive linting (e.g., as-you-type), pass custom events:

```lua
splint.enable({ events = { "BufWritePost", "BufReadPost", "InsertLeave", "TextChanged" } })
```

To run a specific linter manually, use the `:Splint` command:

```
:Splint cspell
```

### Compound filetypes

If a buffer has a compound filetype like `yaml.ghaction`, you can use either
`ghaction`, `yaml`, or the full `yaml.ghaction` as key in `linters_by_ft`.


### Fallback / stop after first

When you have multiple alternative linters for a filetype, set
`stop_after_first = true` to run only the first available one:

```lua
require("splint").linters_by_ft = {
  javascript = { "eslint", "oxlint", stop_after_first = true },
  python = { "ruff", "pylint", stop_after_first = true },
}
```

When `stop_after_first` is set, linters are tried in order. A linter is
skipped if:

- Its command is not executable
- It declares `config_files` and none are found upward from the buffer
- It declares `condition` and it returns false

The first linter that passes all checks runs. If all are skipped, a warning is
shown.

Many built-in linters ship with `config_files` already set, so
`stop_after_first` works out of the box for common tools. For example, the
built-in `eslint` definition knows about `eslint.config.js`, `.eslintrc.json`,
etc. If your project has an ESLint config, `eslint` will be selected. If it
only has `oxlintrc.json`, `oxlint` will be selected instead.


## Security

Some linters prioritize using an executable relative to the buffer's directory.
For example the `eslint` linter will use `./node_modules/.bin/eslint` if it
exists. The executable runs with your user's permissions. Do not enable splint
in untrusted repositories.


## Available Linters

There is a generic linter called `compiler` that uses the `makeprg` and
`errorformat` options of the current buffer.

Other dedicated linters that are built-in are:

| Tool                                   | Linter name            |
| -------------------------------------- | ---------------------- |
| Set via `makeprg`                      | `compiler`             |
| [actionlint][actionlint]               | `actionlint`           |
| [alex][alex]                           | `alex`                 |
| [ameba][ameba]                         | `ameba`                |
| [ansible-lint][ansible-lint]           | `ansible_lint`         |
| [bandit][bandit]                       | `bandit`               |
| [bash][bash]                           | `bash`                 |
| [bean-check][bean-check]               | `bean_check`           |
| [biomejs][biomejs]                     | `biomejs`              |
| [blocklint][blocklint]                 | `blocklint`            |
| [buf_lint][buf_lint]                   | `buf_lint`             |
| [buildifier][buildifier]               | `buildifier`           |
| [cfn-lint][cfn-lint]                   | `cfn_lint`             |
| [cfn_nag][cfn_nag]                     | `cfn_nag`              |
| [checkbashisms][checkbashisms]         | `checkbashisms`        |
| [checkmake][checkmake]                 | `checkmake`            |
| [checkpatch.pl][checkpatch]            | `checkpatch`           |
| [checkstyle][checkstyle]               | `checkstyle`           |
| [chktex][20]                           | `chktex`               |
| [clang-tidy][23]                       | `clangtidy`            |
| [clazy][30]                            | `clazy`                |
| [clippy][clippy]                       | `clippy`               |
| [clj-kondo][24]                        | `clj-kondo`            |
| [cmakelint][cmakelint]                 | `cmakelint`            |
| [cmake-lint][cmake_format]             | `cmake_lint`           |
| [codespell][18]                        | `codespell`            |
| [commitlint][commitlint]               | `commitlint`           |
| [cppcheck][22]                         | `cppcheck`             |
| [cpplint][cpplint]                     | `cpplint`              |
| [credo][credo]                         | `credo`                |
| [cspell][36]                           | `cspell`               |
| [cue][cue]                             | `cue`                  |
| [curlylint][curlylint]                 | `curlylint`            |
| [dash][dash]                           | `dash`                 |
| [dclint][dclint]                       | `dclint`               |
| [deadnix][deadnix]                     | `deadnix`              |
| [deno][deno]                           | `deno`                 |
| [detect-secrets][detect-secrets]       | `detect-secrets`       |
| [dmypy][dmypy]                         | `dmypy`                |
| [DirectX Shader Compiler][dxc]         | `dxc`                  |
| [djlint][djlint]                       | `djlint`               |
| [dotenv-linter][dotenv-linter]         | `dotenv_linter`        |
| [editorconfig-checker][ec]             | `editorconfig-checker` |
| [erb-lint][erb-lint]                   | `erb_lint`             |
| [ESLint][25]                           | `eslint`               |
| [eslint_d][37]                         | `eslint_d`             |
| [eugene][eugene]                       | `eugene`               |
| [fennel][fennel]                       | `fennel`               |
| [fieldalignment][fieldalignment]       | `fieldalignment`       |
| [fish][fish]                           | `fish`                 |
| [Flake8][13]                           | `flake8`               |
| [flawfinder][35]                       | `flawfinder`           |
| [fortitude][fortitude]                 | `fortitude`            |
| [fsharplint][fsharplint]               | `fsharplint`           |
| [gawk][gawk]                           | `gawk`                 |
| [gdlint (gdtoolkit)][gdlint]          | `gdlint`               |
| [GHDL][ghdl]                          | `ghdl`                 |
| [gitleaks][gitleaks]                   | `gitleaks`             |
| [gitlint][gitlint]                     | `gitlint`              |
| [glslc][glslc]                         | `glslc`                |
| [Golangci-lint][16]                    | `golangcilint`         |
| [hadolint][28]                         | `hadolint`             |
| [hledger][hledger]                     | `hledger`              |
| [hlint][32]                            | `hlint`                |
| [htmlhint][htmlhint]                   | `htmlhint`             |
| [HTML Tidy][12]                        | `tidy`                 |
| [Inko][17]                             | `inko`                 |
| [janet][janet]                         | `janet`                |
| [joker][joker]                         | `joker`                |
| [jshint][jshint]                       | `jshint`               |
| [json5][json5]                         | `json5`                |
| [jsonlint][jsonlint]                   | `jsonlint`             |
| [json.tool][json.py]                   | `json_tool`            |
| [ksh][ksh]                             | `ksh`                  |
| [ktlint][ktlint]                       | `ktlint`               |
| [lacheck][lacheck]                     | `lacheck`              |
| [Languagetool][5]                      | `languagetool`         |
| [lslint][lslint]                       | `lslint`               |
| [ls-lint][ls-lint]                     | `ls_lint`              |
| [luac][luac]                           | `luac`                 |
| [luacheck][19]                         | `luacheck`             |
| [mado][mado]                           | `mado`                 |
| [mago_lint][mago]                      | `mago_lint`            |
| [mago_analyze][mago]                   | `mago_analyze`         |
| [markdownlint][26]                     | `markdownlint`         |
| [markdownlint-cli2][markdownlint-cli2] | `markdownlint-cli2`    |
| [markuplint][markuplint]               | `markuplint`           |
| [mbake][mbake]                         | `mbake`                |
| [mh_lint][miss_hit]                    | `mh_lint`              |
| [mlint][34]                            | `mlint`                |
| [Mypy][11]                             | `mypy`                 |
| [Nagelfar][nagelfar]                   | `nagelfar`             |
| [Nix][nix]                             | `nix`                  |
| [npm-groovy-lint][npm-groovy-lint]     | `npm-groovy-lint`      |
| [oelint-adv][oelint-adv]              | `oelint-adv`           |
| [opa_check][opa_check]                 | `opa_check`            |
| [tofu][tofu]                           | `tofu`                 |
| [oxlint][oxlint]                       | `oxlint`               |
| [perlcritic][perlcritic]               | `perlcritic`           |
| [perlimports][perlimports]             | `perlimports`          |
| [phpcs][phpcs]                         | `phpcs`                |
| [phpinsights][phpinsights]             | `phpinsights`          |
| [phpmd][phpmd]                         | `phpmd`                |
| [php][php]                             | `php`                  |
| [phpstan][phpstan]                     | `phpstan`              |
| [pmd][pmd]                             | `pmd`                  |
| [ponyc][ponyc]                         | `pony`                 |
| [prisma-lint][prisma-lint]             | `prisma-lint`          |
| [proselint][proselint]                 | `proselint`            |
| [protolint][protolint]                 | `protolint`            |
| [psalm][psalm]                         | `psalm`                |
| [puppet-lint][puppet-lint]             | `puppet-lint`          |
| [pycodestyle][pcs-docs]                | `pycodestyle`          |
| [pydocstyle][pydocstyle]               | `pydocstyle`           |
| [Pylint][15]                           | `pylint`               |
| [pyproject-flake8][pflake8]            | `pflake8`              |
| [pyrefly][pyrefly]                     | `pyrefly`              |
| [quick-lint-js][quick-lint-js]         | `quick-lint-js`        |
| [redocly][redocly]                     | `redocly`              |
| [regal][regal]                         | `regal`                |
| [Revive][14]                           | `revive`               |
| [rflint][rflint]                       | `rflint`               |
| [robocop][robocop]                     | `robocop`              |
| [rpmlint][rpmlint]                     | `rpmlint`              |
| [RPM][rpm]                             | `rpmspec`              |
| [rstcheck][rstcheck]                   | `rstcheck`             |
| [rstlint][rstlint]                     | `rstlint`              |
| [RuboCop][rubocop]                     | `rubocop`              |
| [Ruby][ruby]                           | `ruby`                 |
| [Ruff][ruff]                           | `ruff`                 |
| [rumdl][rumdl]                         | `rumdl`                |
| [salt-lint][salt-lint]                 | `saltlint`             |
| [Selene][31]                           | `selene`               |
| [ShellCheck][10]                       | `shellcheck`           |
| [slang][slang]                         | `slang`                |
| [Snakemake][snakemake]                 | `snakemake`            |
| [snyk][snyk]                           | `snyk_iac`             |
| [Solhint][solhint]                     | `solhint`              |
| [Spectral][spectral]                   | `spectral`             |
| [sphinx-lint][sphinx-lint]             | `sphinx-lint`          |
| [sqlfluff][sqlfluff]                   | `sqlfluff`             |
| [sqruff][sqruff]                       | `sqruff`               |
| [squawk][squawk]                       | `squawk`               |
| [standardjs][standardjs]               | `standardjs`           |
| [StandardRB][27]                       | `standardrb`           |
| [statix check][33]                     | `statix`               |
| [stylelint][29]                        | `stylelint`            |
| [svlint][svlint]                       | `svlint`               |
| [SwiftLint][swiftlint]                 | `swiftlint`            |
| [systemd-analyze][systemd-analyze]     | `systemd-analyze`      |
| [systemdlint][systemdlint]             | `systemdlint`          |
| [tclint][tclint]                       | `tclint`               |
| [tflint][tflint]                       | `tflint`               |
| [tfsec][tfsec]                         | `tfsec`                |
| [tlint][tlint]                         | `tlint`                |
| [Tombi][tombi]                         | `tombi`                |
| [trivy][trivy]                         | `trivy`                |
| [ts-standard][ts-standard]             | `ts-standard`          |
| [twig-cs-fixer][twig-cs-fixer]         | `twig-cs-fixer`        |
| [typos][typos]                         | `typos`                |
| [vacuum][vacuum]                       | `vacuum`               |
| [Vala][vala-lint]                      | `vala_lint`            |
| [Vale][8]                              | `vale`                 |
| [Verilator][verilator]                 | `verilator`            |
| [vint][21]                             | `vint`                 |
| [VSG][vsg]                             | `vsg`                  |
| [vulture][vulture]                     | `vulture`              |
| [woke][woke]                           | `woke`                 |
| [write-good][write-good]               | `write_good`           |
| [yamllint][yamllint]                   | `yamllint`             |
| [yq][yq]                              | `yq`                   |
| [zizmor][zizmor]                       | `zizmor`               |
| [zlint][zlint]                         | `zlint`                |
| [zsh][zsh]                             | `zsh`                  |


## Custom Linters

You can register custom linters by adding them to the `linters` table, but
please consider contributing a linter if it is missing.

```lua
require("splint").linters.your_linter_name = {
  cmd = "linter_cmd",
  stdin = true,
  args = {},
  parser = your_parse_function,
}
```

`cmd` and `args` entries can be functions that receive a context table:

```lua
cmd = function(ctx)
  -- ctx.bufnr, ctx.filename, ctx.dirname, ctx.cwd
  return ctx.cwd .. "/node_modules/.bin/my-linter"
end
```

`parser` takes `(output, bufnr, linter_cwd)` and returns a list of
diagnostics (see `:help diagnostic-structure`).

You can generate a parse function from a Lua pattern, from an `errorformat`,
or for [SARIF][sarif] using the functions in `require("splint.parser")`:

### from_errorformat

```lua
parser = require("splint.parser").from_errorformat(errorformat, skeleton)
```

### from_pattern

```lua
parser = require("splint.parser").from_pattern(pattern, groups, severity_map, defaults, opts)
```

`pattern` can be a Lua pattern (`:help lua-pattern`), an LPEG pattern
(`:help vim.lpeg`), or a function `fun(line: string): string[]`.

`groups` specifies the capture order. Available groups: `lnum`, `end_lnum`,
`col`, `end_col`, `message`, `file`, `severity`, `code`.

### for_sarif

```lua
parser = require("splint.parser").for_sarif(skeleton)
```


## Linter config_files

Built-in linters can declare `config_files` — a list of known config file
names for that tool. This is used by `stop_after_first` to determine which
linter is configured for a project. You can override or extend them:

```lua
-- Add a custom config file to an existing linter
local eslint = require("splint").linters.eslint
vim.list_extend(eslint.config_files, { ".my-eslintrc" })
```


## Linter condition

For cases that `config_files` can't express, linters support a `condition`
function. It receives a context table with `bufnr`, `filename`, `dirname`,
and `cwd`:

```lua
require("splint").linters.eslint.condition = function(ctx)
  return ctx.filename:match("_test%.js$") ~= nil
end
```

`condition` is only checked when `stop_after_first` is set.


## Customize built-in linters

You can import a linter and modify its properties:

```lua
local phpcs = require("splint").linters.phpcs
phpcs.args = {
  "-q",
  "--report=json",
  "-",
}
```

Some linters are defined as functions for lazy evaluation. In that case, wrap
them:

```lua
local original = require("splint").linters.terraform_validate
require("splint").linters.terraform_validate = function()
  local linter = original()
  linter.cmd = "my_custom"
  return linter
end
```


## Health check

Run `:checkhealth splint` to see:
- Whether splint is enabled and on which events
- Which linters are configured for the current filetype
- Whether each linter's command is found
- Whether config files are present
- Which linter would be selected with `stop_after_first`


## Display configuration

See `:help vim.diagnostic.config`.

To configure diagnostics per linter, use Neovim's diagnostic namespace:

```lua
vim.diagnostic.config(
  { virtual_text = true },
  vim.api.nvim_create_namespace("eslint")
)
```


## Alternatives

- [ale](https://github.com/dense-analysis/ale)
- [efm-langserver](https://github.com/mattn/efm-langserver)
- [diagnostic-languageserver](https://github.com/iamcco/diagnostic-languageserver)


## Development

```bash
make deps   # one-time: install test dependencies
make test   # run all tests
```

[5]: https://languagetool.org/
[8]: https://github.com/errata-ai/vale
[10]: https://www.shellcheck.net/
[11]: http://mypy-lang.org/
[12]: https://www.html-tidy.org/
[13]: https://flake8.pycqa.org/
[14]: https://github.com/mgechev/revive
[15]: https://pylint.org/
[16]: https://golangci-lint.run/
[17]: https://inko-lang.org/
[18]: https://github.com/codespell-project/codespell
[19]: https://github.com/mpeterv/luacheck
[20]: https://www.nongnu.org/chktex
[21]: https://github.com/Vimjas/vint
[22]: https://github.com/danmar/cppcheck/
[23]: https://clang.llvm.org/extra/clang-tidy/
[24]: https://github.com/clj-kondo/clj-kondo
[25]: https://github.com/eslint/eslint
[26]: https://github.com/DavidAnson/markdownlint
[27]: https://github.com/testdouble/standard
[28]: https://github.com/hadolint/hadolint
[29]: https://github.com/stylelint/stylelint
[30]: https://github.com/KDE/clazy
[31]: https://github.com/Kampfkarren/selene
[32]: https://github.com/ndmitchell/hlint
[33]: https://github.com/NerdyPepper/statix
[34]: https://www.mathworks.com/help/matlab/ref/mlint.html
[35]: https://github.com/david-a-wheeler/flawfinder
[36]: https://github.com/streetsidesoftware/cspell/tree/main/packages/cspell
[37]: https://github.com/mantoni/eslint_d.js
[ansible-lint]: https://docs.ansible.com/lint.html
[pcs-docs]: https://pycodestyle.pycqa.org/en/latest/
[pydocstyle]: https://www.pydocstyle.org/en/stable/
[prisma-lint]: https://github.com/loop-payments/prisma-lint
[checkpatch]: https://docs.kernel.org/dev-tools/checkpatch.html
[checkstyle]: https://checkstyle.org/
[jshint]: https://jshint.com/
[json5]: https://json5.org/
[jsonlint]: https://github.com/zaach/jsonlint
[json.py]: https://docs.python.org/3/library/json.html#module-json.tool
[rflint]: https://github.com/boakley/robotframework-lint
[robocop]: https://github.com/MarketSquare/robotframework-robocop
[vsg]: https://github.com/jeremiah-c-leary/vhdl-style-guide
[vulture]: https://github.com/jendrikseipp/vulture
[yamllint]: https://github.com/adrienverge/yamllint
[cpplint]: https://github.com/cpplint/cpplint
[proselint]: https://github.com/amperser/proselint
[protolint]: https://github.com/yoheimuta/protolint
[cmakelint]: https://github.com/cmake-lint/cmake-lint
[cmake_format]: https://github.com/cheshirekow/cmake_format
[rstcheck]: https://github.com/myint/rstcheck
[rstlint]: https://github.com/twolfson/restructuredtext-lint
[ksh]: https://github.com/ksh93/ksh
[ktlint]: https://github.com/pinterest/ktlint
[php]: https://www.php.net/
[phpcs]: https://github.com/PHPCSStandards/PHP_CodeSniffer
[phpinsights]: https://github.com/nunomaduro/phpinsights
[phpmd]: https://phpmd.org/
[phpstan]: https://phpstan.org/
[psalm]: https://psalm.dev/
[lacheck]: https://www.ctan.org/tex-archive/support/lacheck
[luac]: https://www.lua.org/manual/5.1/luac.html
[credo]: https://github.com/rrrene/credo
[ghdl]: https://github.com/ghdl/ghdl
[gitleaks]: https://github.com/gitleaks/gitleaks
[glslc]: https://github.com/google/shaderc
[rubocop]: https://github.com/rubocop/rubocop
[dxc]: https://github.com/microsoft/DirectXShaderCompiler
[cfn-lint]: https://github.com/aws-cloudformation/cfn-lint
[fennel]: https://github.com/bakpakin/Fennel
[nix]: https://github.com/NixOS/nix
[ruby]: https://github.com/ruby/ruby
[npm-groovy-lint]: https://github.com/nvuillam/npm-groovy-lint
[nagelfar]: https://nagelfar.sourceforge.net/
[oelint-adv]: https://github.com/priv-kweihmann/oelint-adv
[cfn_nag]: https://github.com/stelligent/cfn_nag
[checkbashisms]: https://tracker.debian.org/pkg/devscripts
[checkmake]: https://github.com/mrtazz/checkmake
[ruff]: https://github.com/astral-sh/ruff
[janet]: https://github.com/janet-lang/janet
[bandit]: https://bandit.readthedocs.io/en/latest/
[bash]: https://www.gnu.org/software/bash/
[bean-check]: https://beancount.github.io/docs/running_beancount_and_generating_reports.html#bean-check
[cue]: https://github.com/cue-lang/cue
[curlylint]: https://www.curlylint.org/
[sqlfluff]: https://github.com/sqlfluff/sqlfluff
[sqruff]: https://github.com/quarylabs/sqruff
[squawk]: https://github.com/sbdchd/squawk
[verilator]: https://verilator.org/guide/latest/
[actionlint]: https://github.com/rhysd/actionlint
[buf_lint]: https://github.com/bufbuild/buf
[erb-lint]: https://github.com/shopify/erb-lint
[tfsec]: https://github.com/aquasecurity/tfsec
[tlint]: https://github.com/tighten/tlint
[trivy]: https://github.com/aquasecurity/trivy
[djlint]: https://djlint.com/
[buildifier]: https://github.com/bazelbuild/buildtools/tree/main/buildifier
[solhint]: https://protofire.github.io/solhint/
[perlimports]: https://github.com/perl-ide/App-perlimports
[perlcritic]: https://github.com/Perl-Critic/Perl-Critic
[ponyc]: https://github.com/ponylang/ponyc
[gdlint]: https://github.com/Scony/godot-gdscript-toolkit
[rpmlint]: https://github.com/rpm-software-management/rpmlint
[rpm]: https://rpm.org
[ec]: https://github.com/editorconfig-checker/editorconfig-checker
[dmypy]: https://mypy.readthedocs.io/en/stable/mypy_daemon.html
[deno]: https://github.com/denoland/deno
[standardjs]: https://standardjs.com/
[biomejs]: https://github.com/biomejs/biome
[commitlint]: https://commitlint.js.org
[alex]: https://alexjs.com/
[blocklint]: https://github.com/PrincetonUniversity/blocklint
[woke]: https://docs.getwoke.tech/
[write-good]: https://github.com/btford/write-good
[dotenv-linter]: https://dotenv-linter.github.io/
[puppet-lint]: https://github.com/puppetlabs/puppet-lint
[snakemake]: https://snakemake.github.io
[snyk]: https://github.com/snyk/cli
[spectral]: https://github.com/stoplightio/spectral
[sphinx-lint]: https://github.com/sphinx-contrib/sphinx-lint
[gitlint]: https://github.com/jorisroovers/gitlint
[pflake8]: https://github.com/csachs/pyproject-flake8
[fish]: https://github.com/fish-shell/fish-shell
[zsh]: https://www.zsh.org/
[typos]: https://github.com/crate-ci/typos
[joker]: https://github.com/candid82/joker
[dash]: http://gondor.apana.org.au/~herbert/dash
[deadnix]: https://github.com/astro/deadnix
[salt-lint]: https://github.com/warpnet/salt-lint
[quick-lint-js]: https://quick-lint-js.com
[opa_check]: https://www.openpolicyagent.org/
[oxlint]: https://oxc-project.github.io/
[regal]: https://github.com/StyraInc/regal
[vala-lint]: https://github.com/vala-lang/vala-lint
[systemdlint]: https://github.com/priv-kweihmann/systemdlint
[htmlhint]: https://htmlhint.com/
[markuplint]: https://markuplint.dev/
[markdownlint-cli2]: https://github.com/DavidAnson/markdownlint-cli2
[swiftlint]: https://github.com/realm/SwiftLint
[tclint]: https://github.com/nmoroze/tclint
[tflint]: https://github.com/terraform-linters/tflint
[ameba]: https://github.com/crystal-ameba/ameba
[eugene]: https://github.com/kaaveland/eugene
[clippy]: https://github.com/rust-lang/rust-clippy
[hledger]: https://hledger.org/
[systemd-analyze]: https://man.archlinux.org/man/systemd-analyze.1
[gawk]: https://www.gnu.org/software/gawk/
[yq]: https://mikefarah.gitbook.io/yq
[svlint]: https://github.com/dalance/svlint
[slang]: https://github.com/MikePopoloski/slang
[zizmor]: https://github.com/woodruffw/zizmor
[ts-standard]: https://github.com/standard/ts-standard
[twig-cs-fixer]: https://github.com/VincentLanglet/Twig-CS-Fixer
[fortitude]: https://github.com/PlasmaFAIR/fortitude
[redocly]: https://redocly.com/docs/cli/commands/lint
[sarif]: https://sarifweb.azurewebsites.net/
[pmd]: https://pmd.github.io/
[tofu]: https://opentofu.org/
[lslint]: https://github.com/Makopo/lslint/
[fsharplint]: https://github.com/fsprojects/FSharpLint
[fieldalignment]: https://pkg.go.dev/golang.org/x/tools/go/analysis/passes/fieldalignment
[zlint]: https://donisaac.github.io/zlint/
[dclint]: https://github.com/zavoloklom/docker-compose-linter
[detect-secrets]: https://github.com/Yelp/detect-secrets
[tombi]: https://github.com/tombi-toml/tombi
[mado]: https://github.com/akiomik/mado
[rumdl]: https://github.com/rvben/rumdl
[ls-lint]: https://github.com/loeffel-io/ls-lint
[mago]: https://mago.carthage.software/
[miss_hit]: https://github.com/florianschanda/miss_hit
[pyrefly]: https://pyrefly.org/
[vacuum]: https://quobix.com/vacuum/
[mbake]: https://github.com/EbodShojaei/bake
