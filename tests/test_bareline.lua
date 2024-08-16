-- Ideas of what to test:
-- - Default config, black box test the final assigned value of 'statusline'.
--   - All window states:
--     - Active window.
--     - Inactive window.
--     - Plugin window.
--   - For each window state, consider edge cases, e.g.:
--     - File name contains Lua pattern special character.
--     - Buffer is unmodifiable.
--     - Buffer does not have an end of line.
--     - Buffer is quick fix list.
--     - Buffer is location list.
-- How to write the tests: https://github.com/echasnovski/mini.nvim

-- See: https://github.com/echasnovski/mini.nvim/blob/main/TESTING.md

-- Define helper aliases.
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

-- Create (but not start) child Neovim object.
local child = MiniTest.new_child_neovim()

-- Define main test set of this file.
local T = new_set({
  -- Register hooks.
  hooks = {
    -- This will be executed before every (even nested) case.
    pre_case = function()
      -- Restart child process with custom 'init.lua' script.
      child.restart({ "-u", "scripts/minimal_init.lua" })
      -- Load tested plugin.
      child.lua([[bareline = require("bareline")]])
    end,
    -- This will be executed one after all tests from this set are finished.
    post_once = child.stop,
  },
})

T["defaults"] = new_set({
  hooks = {
    pre_case = function()
      -- Setup plugin with defaults.
      child.lua([[bareline.setup()]])
    end
  }
})

-- ACTIVE WINDOW

T["defaults"]["active window"] = new_set({})

T["defaults"]["active window"]["no git dir"] = new_set({
  hooks = {
    pre_case = function()
      child.cmd("cd tests/resources/no_git_dir/")
    end
  }
})

T["defaults"]["active window"]["no git dir"]["startup"] = function()
  local expected = " NOR  %f  %m  %h  %r%=  tabs:8  (main)  %02l,%02c/%02L "
  eq(child.wo.statusline, expected)
end

return T
