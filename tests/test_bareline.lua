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
    -- This will be executed once before anything else.
    pre_once = function()
      -- Rename `gitdir` dirs to `.git`.
      vim.uv.fs_rename("tests/resources/git_dir_branch/gitdir/",
        "tests/resources/git_dir_branch/.git/")
      vim.uv.fs_rename("tests/resources/git_dir_hash/gitdir/",
        "tests/resources/git_dir_hash/.git/")
      vim.uv.fs_rename("tests/resources/git_dir_tag/gitdir/",
        "tests/resources/git_dir_tag/.git/")
    end,
    -- This will be executed before every (even nested) case.
    pre_case = function()
      -- Restart child process with custom 'init.lua' script.
      child.restart({ "-u", "scripts/minimal_init.lua" })
      -- Load tested plugin.
      child.lua([[bareline = require("bareline")]])
    end,
    -- This will be executed once after all tests are done.
    post_once = function()
      -- Rename `.git` dirs to `gitdir`.
      vim.uv.fs_rename("tests/resources/git_dir_branch/.git/",
        "tests/resources/git_dir_branch/gitdir/")
      vim.uv.fs_rename("tests/resources/git_dir_hash/.git/",
        "tests/resources/git_dir_hash/gitdir/")
      vim.uv.fs_rename("tests/resources/git_dir_tag/.git/",
        "tests/resources/git_dir_tag/gitdir/")
      child.stop()
    end,
  },
})

local bareline_root_dir = vim.uv.cwd()

T["defaults"] = new_set({
  hooks = {
    pre_case = function()
      child.lua([[bareline.setup()]])
      child.cmd("cd /tmp")
    end
  }
})

-- SMOKE

T["defaults"]["basic startup"] = function()
  local expected = " NOR  %f  %m  %h  %r%=  tabs:8  %02l,%02c/%02L "
  eq(child.wo.statusline, expected)
end

-- COMPONENTS

-- GIT_HEAD

T["defaults"]["git_head branch"] = function()
  local expected = " NOR  %f  %m  %h  %r%=  tabs:8  (main)  %02l,%02c/%02L "
  child.cmd("cd " .. bareline_root_dir .. "/tests/resources/git_dir_branch/")
  eq(child.wo.statusline, expected)
end

T["defaults"]["git_head hash"] = function()
  local expected = " NOR  %f  %m  %h  %r%=  tabs:8  (b1a8f4a)  %02l,%02c/%02L "
  child.cmd("cd " .. bareline_root_dir .. "/tests/resources/git_dir_hash/")
  eq(child.wo.statusline, expected)
end

T["defaults"]["git_dir tag"] = function()
  local expected = " NOR  %f  %m  %h  %r%=  tabs:8  (b1a8f4a)  %02l,%02c/%02L "
  child.cmd("cd " .. bareline_root_dir .. "/tests/resources/git_dir_tag/")
  eq(child.wo.statusline, expected)
end

-- VIM_MODE

T["defaults"]["vim_mode normal"] = function()
  local expected = "NOR"
  eq(string.sub(child.wo.statusline, 2, 4), expected)
end

T["defaults"]["vim_mode insert"] = function()
  local expected = "INS"
  child.type_keys("startinsert")
  eq(string.sub(child.wo.statusline, 2, 4), expected)
end

T["defaults"]["vim_mode command"] = function()
  local expected = "CMD"
  child.type_keys(":")
  eq(string.sub(child.wo.statusline, 2, 4), expected)
end

T["defaults"]["vim_mode visual"] = function()
  local expected = "VIS"
  child.type_keys("v")
  eq(string.sub(child.wo.statusline, 2, 4), expected)
end

T["defaults"]["vim_mode visual block"] = function()
  local expected = "VIS"
  child.type_keys("<C-q>")
  eq(string.sub(child.wo.statusline, 2, 4), expected)
end

T["defaults"]["vim_mode terminal"] = function()
  local expected = "TER"
  child.cmd("new|term")
  child.type_keys("a")
  eq(string.sub(child.wo.statusline, 2, 4), expected)
end

return T
