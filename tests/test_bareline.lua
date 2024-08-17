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
local h = dofile("tests/helpers.lua")
local root_dir = vim.uv.cwd()

local T = new_set({
  hooks = {
    pre_once = function()
      h.rename_gitdir_to_dotdir()
    end,
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
      child.lua([[bareline = require("bareline")]])
    end,
    post_once = function()
      h.rename_dotdir_to_gitdir()
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

T["components"]["smoke"] = function()
  local expected = " NOR  %f  %m  %h  %r%=  tabs:8  %02l,%02c/%02L "
  eq(child.wo.statusline, expected)
end

-- COMPONENTS

-- VIM_MODE

T["components"]["vim_mode"] = new_set({
  parametrize = {
    { "",           "NOR" }, -- Normal.
    { "i",          "INS" }, -- Insert.
    { ":",          "CMD" }, -- Command.
    { "v",          "VIS" }, -- Charwise Visual.
    { "V",          "VIS" }, -- Linewise Visual.
    { "<C-q>",      "VIS" }, -- Block Visual.
    { ":term<CR>a", "TER" }  -- Terminal.
  }
})

T["components"]["vim_mode"]["success"] = function(keys, expected_vim_mode)
  child.type_keys(keys)
  local vim_mode = string.match(child.wo.statusline, expected_vim_mode)
  eq(vim_mode, expected_vim_mode)
end

-- INDENT_STYLE

T["components"]["indent_style"] = new_set({
  parametrize = {
    { "",   "",   "tabs:8"   }, -- Nvim defaults.
    { false, 4,   "tabs:4"   },
    { true,  2,   "spaces:2" },
    { true,  4,   "spaces:4" },
  }
})

T["components"]["indent_style"]["success"] = function(
    expandtab, tabstop, expected_indent_style)
  if expandtab ~= "" then child.bo.expandtab = expandtab end
  if tabstop ~= "" then child.bo.tabstop = tabstop end
  local indent_style = string.match(child.wo.statusline, expected_indent_style)
  eq(indent_style, expected_indent_style)
end

-- GIT_HEAD

T["components"]["git_head"] = new_set({
  parametrize = {
    { "/tests/resources/git_dir_branch/", "(main)"    },
    { "/tests/resources/git_dir_hash/",   "(b1a8f4a)" },
    { "/tests/resources/git_dir_tag/",    "(b1a8f4a)" },
  }
})

T["components"]["git_head"]["success"] = function(git_dir, expected_git_head)
  child.cmd("cd " .. root_dir .. git_dir)
  local git_head = string.match(
    child.wo.statusline, h.escape_lua_pattern(expected_git_head))
  eq(git_head, expected_git_head)
end

return T
