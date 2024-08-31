---@diagnostic disable: undefined-field, undefined-global

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

-- Basic tests, not thorough.

-- See: https://github.com/echasnovski/mini.nvim/blob/main/TESTING.md

local root = vim.uv.cwd()
local h = dofile("tests/helpers.lua")

local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality
local child = MiniTest.new_child_neovim()

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

T["smoke"] = new_set({
  hooks = {
    pre_case = function()
      child.lua("bareline.setup()")
      child.cmd("cd " .. root .. "/tests/resources/git_dir_branch/")
    end
  }
})

-- SMOKE

T["smoke"]["success"] = function()
  local expected = " NOR  %f  %m  %h  %r%=  tabs:8  (main)  %02l,%02c/%02L "
  eq(child.wo.statusline, expected)
end

-- COMPONENTS

-- VIM_MODE

T["components"] = new_set({
  hooks = {
    pre_case = function()
      child.lua("bareline.setup()")
    end
  }
})

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
  local vim_mode = child.lua_get("bareline.components.vim_mode:get_value()")
  eq(vim_mode, expected_vim_mode)
end

-- INDENT_STYLE

T["components"]["indent_style"] = new_set({
  parametrize = {
    { vim.NIL,  vim.NIL,  "tabs:8"   }, -- Nvim defaults.
    { false,    4,        "tabs:4"   },
    { true,     2,        "spaces:2" },
    { true,     4,        "spaces:4" },
  }
})

T["components"]["indent_style"]["success"] = function(
    expandtab, tabstop, expected_indent_style)
  if expandtab ~= vim.NIL then child.bo.expandtab = expandtab end
  if tabstop ~= vim.NIL then child.bo.tabstop = tabstop end
  local indent_style = child.lua_get(
    "bareline.components.indent_style:get_value()")
  eq(indent_style, expected_indent_style)
end

-- END_OF_LINE

T["components"]["end_of_line"] = new_set({
  parametrize = {
    { ":set eol<CR>", vim.NIL },
    { ":set noeol<CR>", "noeol" }
  }
})

T["components"]["end_of_line"]["success"] = function(keys, expected_eol_marker)
  child.type_keys(keys)
  local eol = child.lua_get("bareline.components.end_of_line:get_value()")
  eq(eol, expected_eol_marker)
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
  child.cmd("cd " .. root .. git_dir)
  local git_head = child.lua_get("bareline.components.git_head:get_value()")
  eq(git_head, expected_git_head)
end

-- GET_FILE_PATH_RELATIVE_TO_CWD

T["components"]["get_file_path_relative_to_cwd"] = new_set({
  parametrize = {
    { { cd = "~", edit = vim.NIL }, "%f" },
    { { cd = "~", edit = "test_file.txt" }, "test_file.txt" },
    {
      {
        cd = root .. "/tests/resources/dir_a",
        edit = "dir_a_a/.gitkeep"
      },
      "dir_a_a/.gitkeep"
    },
    {
      {
        cd = root .. "/tests/resources/dir_b",
        edit = root .. "/tests/resources/dir_a/dir_a_a/.gitkeep"
      },
      root .. "/tests/resources/dir_a/dir_a_a/.gitkeep"
    },
    -- Main test case. An absolute file path is used for `:e`, but the file path
    -- displayed should be relative to the current working directory.
    {
      {
        cd = root .. "/tests/resources/dir_a",
        edit = root .. "/tests/resources/dir_a/dir_a_a/.gitkeep"
      },
      "dir_a_a/.gitkeep"
    },
  }
})

T["components"]["get_file_path_relative_to_cwd"]["success"] = function(
    setup, expected_file_path)
  child.cmd("cd " .. setup.cd)
  if setup.edit ~= vim.NIL then child.cmd("edit " .. setup.edit) end
  local file_path_relative_to_cwd = child.lua_get(
    "bareline.components.get_file_path_relative_to_cwd:get_value()")
  eq(file_path_relative_to_cwd, expected_file_path)
end

-- DIAGNOSTICS

T["components"]["diagnostics"] = new_set({
  parametrize = {
    {
      {
        {
          lnum = 1, col = 1,
          severity = vim.diagnostic.severity.WARN
        }
      },
      "w:1"
    },
    {
      {
        {
          lnum = 1, col = 1,
          severity = vim.diagnostic.severity.ERROR
        },
        {
          lnum = 1, col = 1,
          severity = vim.diagnostic.severity.HINT
        },
        {
          lnum = 1, col = 1,
          severity = vim.diagnostic.severity.WARN
        },
        {
          lnum = 1, col = 2,
          severity = vim.diagnostic.severity.WARN
        }
      },
      "e:1,w:2,h:1"
    }
  }
})

T["components"]["diagnostics"]["success"] = function(
    diagnostics, expected_diagnostics)
  child.api.nvim_create_namespace("test")
  local test_ns = child.api.nvim_get_namespaces().test
  child.diagnostic.set(test_ns, 0, diagnostics)
  eq(
    child.lua_get("bareline.components.diagnostics:get_value()"),
    expected_diagnostics
  )
end

-- POSITION

T["components"]["position"] = new_set({})

T["components"]["position"]["success"] = function()
  eq(
    child.lua_get("bareline.components.position:get_value()"),
    "%02l,%02c/%02L"
  )
end

-- SETUP

T["setup"] = new_set({
  hooks = {
    pre_case = function()
      child.lua([[
        local statusline_active = {
          { bareline.components.vim_mode },
          { bareline.components.position }
        }
        local statusline_inactive = {
          { bareline.components.vim_mode:mask(" ") },
          { bareline.components.position }
        }
        local statusline_plugin = {
          { bareline.components.plugin_name },
          { bareline.components.position }
        }
        bareline.setup({
          statusline = {
            statusline_active,
            statusline_inactive,
            statusline_plugin
          }
        })
      ]])
      child.cmd("cd " .. root .. "/tests/resources")
    end
  }
})

T["setup"]["custom statusline active window success"] = function()
  local expected = " NOR%=%02l,%02c/%02L "
  eq(child.wo.statusline, expected)
end

T["setup"]["custom statusline inactive window success"] = function()
  child.cmd("new")
  local expected = "    %=%02l,%02c/%02L "
  local window_ids = child.lua_get("vim.api.nvim_tabpage_list_wins(0)")
  local statusline_inactive_window =
    child.lua_get("vim.wo[" .. window_ids[2] .. "].statusline")
  eq(statusline_inactive_window, expected)
end

T["setup"]["custom statusline plugin window success"] = function()
  child.bo.filetype = "test"
  child.bo.buflisted = false
  local expected = " [test]%=%02l,%02c/%02L "
  eq(child.wo.statusline, expected)
end

return T
