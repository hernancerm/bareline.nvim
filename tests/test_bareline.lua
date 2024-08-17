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

local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality
local child = MiniTest.new_child_neovim()
local helpers = dofile("tests/helpers.lua")
local root_dir = vim.uv.cwd()

local T = new_set({
  hooks = {
    pre_once = function()
      helpers.rename_gitdir_to_dotdir()
    end,
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
      child.lua([[bareline = require("bareline")]])
    end,
    post_once = function()
      helpers.rename_dotdir_to_gitdir()
      child.stop()
    end,
  },
})

T["components"] = new_set({
  hooks = {
    pre_case = function()
      child.lua([[bareline.setup()]])
      child.cmd("cd /tmp")
    end
  }
})

-- SMOKE

T["components"]["basic startup"] = function()
  local expected = " NOR  %f  %m  %h  %r%=  tabs:8  %02l,%02c/%02L "
  eq(child.wo.statusline, expected)
end

-- COMPONENTS

-- GIT_HEAD

T["components"]["git_head"] = new_set({
  parametrize = {
    {
      "/tests/resources/git_dir_branch/",
      " NOR  %f  %m  %h  %r%=  tabs:8  (main)  %02l,%02c/%02L "
    },
    {
      "/tests/resources/git_dir_hash/",
      " NOR  %f  %m  %h  %r%=  tabs:8  (b1a8f4a)  %02l,%02c/%02L "
    },
    {
      "/tests/resources/git_dir_tag/",
      " NOR  %f  %m  %h  %r%=  tabs:8  (b1a8f4a)  %02l,%02c/%02L "
    }
  }
})

T["components"]["git_head"]["success"] = function(git_dir, expected_statusline)
  child.cmd("cd " .. root_dir .. git_dir)
  eq(child.wo.statusline, expected_statusline)
end

-- VIM_MODE

T["components"]["vim_mode"] = new_set({
  parametrize = {
    { "",           "NOR" }, -- Normal
    { "i",          "INS" }, -- Insert
    { ":",          "CMD" }, -- Command
    { "v",          "VIS" }, -- Charwise Visual
    { "V",          "VIS" }, -- Linewise Visual
    { "<C-q>",      "VIS" }, -- Block Visual
    { ":term<CR>a", "TER" }  -- Terminal
  }
})

T["components"]["vim_mode"]["success"] = function(keys, expected_vim_mode)
  child.type_keys(keys)
  eq(string.sub(child.wo.statusline, 2, 4), expected_vim_mode)
end

return T
