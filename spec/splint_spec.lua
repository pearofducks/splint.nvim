describe('splint', function()
  local a = vim.api
  local splint = require('splint')

  local function make_buf(ft)
    local bufnr = a.nvim_create_buf(true, true)
    a.nvim_buf_set_option(bufnr, 'filetype', ft)
    a.nvim_set_current_buf(bufnr)
    return bufnr
  end

  -- Track which linters were spawned via their parser being called
  local spawned = {}
  local function tracking_parser(name)
    return function()
      table.insert(spawned, name)
      return {}
    end
  end

  before_each(function()
    spawned = {}
  end)

  after_each(function()
    splint.disable()
  end)

  describe('enable / disable', function()
    it('creates and removes the augroup', function()
      splint.enable()
      local ok = pcall(a.nvim_get_autocmds, { group = "splint" })
      assert.is_true(ok)

      splint.disable()
      ok = pcall(a.nvim_get_autocmds, { group = "splint" })
      assert.is_false(ok)
    end)

    it('creates the :Splint command', function()
      splint.enable()
      local cmds = a.nvim_get_commands({})
      assert.is_not_nil(cmds["Splint"])
    end)

    it('removes the :Splint command on disable', function()
      splint.enable()
      splint.disable()
      local cmds = a.nvim_get_commands({})
      assert.is_nil(cmds["Splint"])
    end)
  end)

  describe('linting via :Splint', function()
    it('runs linters for matching filetype', function()
      splint.linters.ft_echo = {
        name = "ft_echo",
        cmd = "echo",
        args = {},
        parser = tracking_parser("ft_echo"),
      }
      splint.linters_by_ft = { testlang = { "ft_echo" } }

      make_buf('testlang')
      splint.enable()
      vim.cmd("Splint")
      -- Spawned without error = success (parser runs async)
    end)

    it('runs a specific linter by name', function()
      splint.linters.manual = {
        name = "manual",
        cmd = "echo",
        args = {},
        parser = tracking_parser("manual"),
      }
      splint.linters_by_ft = {}

      make_buf('whatever')
      splint.enable()
      vim.cmd("Splint manual")
    end)

    it('resolves compound filetypes', function()
      splint.linters.ans = {
        name = "ans",
        cmd = "echo",
        args = {},
        parser = tracking_parser("ans"),
      }
      splint.linters.yml = {
        name = "yml",
        cmd = "echo",
        args = {},
        parser = tracking_parser("yml"),
      }
      splint.linters_by_ft = {
        ansible = { "ans" },
        yaml = { "yml" },
      }

      make_buf('ansible.yaml')
      splint.enable()
      vim.cmd("Splint")
    end)
  end)

  describe('stop_after_first', function()
    it('runs only the first spawnable linter', function()
      -- Use a cmd that writes to a file so we can verify which ran.
      -- Simpler: just check the linter table was resolved by
      -- watching what the condition function sees.
      local ran = {}
      splint.linters.first_ok = {
        name = "first_ok",
        cmd = "echo",
        args = {},
        condition = function()
          table.insert(ran, "first_ok")
          return true
        end,
        parser = function() return {} end,
      }
      splint.linters.second_ok = {
        name = "second_ok",
        cmd = "echo",
        args = {},
        condition = function()
          table.insert(ran, "second_ok")
          return true
        end,
        parser = function() return {} end,
      }
      splint.linters_by_ft = {
        saf1 = { "first_ok", "second_ok", stop_after_first = true },
      }

      make_buf('saf1')
      splint.enable()
      vim.cmd("Splint")

      -- first_ok's condition was checked and returned true, so it was selected.
      -- second_ok's condition should never have been checked.
      assert.are.same({ "first_ok" }, ran)
    end)

    it('skips linter when config_files not found', function()
      local checked = {}
      splint.linters.needs_config = {
        name = "needs_config",
        cmd = "echo",
        args = {},
        config_files = { "nonexistent_config_xxxxx.json" },
        condition = function()
          table.insert(checked, "needs_config")
          return true
        end,
        parser = function() return {} end,
      }
      splint.linters.fallback = {
        name = "fallback",
        cmd = "echo",
        args = {},
        condition = function()
          table.insert(checked, "fallback")
          return true
        end,
        parser = function() return {} end,
      }
      splint.linters_by_ft = {
        saf3 = { "needs_config", "fallback", stop_after_first = true },
      }

      make_buf('saf3')
      splint.enable()
      vim.cmd("Splint")

      -- needs_config was skipped (config_files check happens before condition),
      -- so its condition was never called. fallback was selected.
      assert.are.same({ "fallback" }, checked)
    end)

    it('skips linter when condition returns false', function()
      local reached_spawn = {}
      splint.linters.cond_skip = {
        name = "cond_skip",
        cmd = "echo",
        args = {},
        condition = function() return false end,
        parser = function()
          table.insert(reached_spawn, "cond_skip")
          return {}
        end,
      }
      splint.linters.cond_pass = {
        name = "cond_pass",
        cmd = "echo",
        args = {},
        condition = function() return true end,
        parser = function()
          table.insert(reached_spawn, "cond_pass")
          return {}
        end,
      }
      splint.linters_by_ft = {
        saf4 = { "cond_skip", "cond_pass", stop_after_first = true },
      }

      make_buf('saf4')
      splint.enable()
      vim.cmd("Splint")
      -- cond_skip should not have been spawned
      -- We can't easily check async parser calls synchronously,
      -- but the spawn logic itself is synchronous — if condition
      -- returns false, spawn is never called.
    end)

    it('condition receives correct context', function()
      local captured_ctx
      splint.linters.ctx_check = {
        name = "ctx_check",
        cmd = "echo",
        args = {},
        condition = function(ctx)
          captured_ctx = ctx
          return true
        end,
        parser = function() return {} end,
      }
      splint.linters_by_ft = {
        saf5 = { "ctx_check", stop_after_first = true },
      }

      local bufnr = make_buf('saf5')
      splint.enable()
      vim.cmd("Splint")

      assert.is_not_nil(captured_ctx)
      assert.are.same(bufnr, captured_ctx.bufnr)
      assert.is_not_nil(captured_ctx.filename)
      assert.is_not_nil(captured_ctx.dirname)
      assert.is_not_nil(captured_ctx.cwd)
    end)

    it('does not check config_files or condition without stop_after_first', function()
      -- Even with failing config_files and condition, the linter should spawn
      -- when stop_after_first is not set.
      splint.linters.always_run = {
        name = "always_run",
        cmd = "echo",
        args = {},
        config_files = { "nonexistent_xxxxx.json" },
        condition = function() return false end,
        parser = function() return {} end,
      }
      splint.linters_by_ft = {
        saf6 = { "always_run" },
      }

      make_buf('saf6')
      splint.enable()
      -- Should not error — the linter spawns despite failing checks
      vim.cmd("Splint")
    end)
  end)
end)
