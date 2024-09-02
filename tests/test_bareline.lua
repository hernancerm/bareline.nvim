---@diagnostic disable: undefined-field, undefined-global

-- TODO: Pending tests:
-- [ ] File path too long gets truncated at the start.

-- See: https://github.com/echasnovski/mini.nvim/blob/main/TESTING.md

local root = vim.uv.cwd()
local resources = root .. "/tests/resources"
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
      child.cmd("cd " .. resources .. "/git_dir_branch/")
    end
  }
})

-- SMOKE

T["smoke"]["active window success"] = function()
  local expected = " NOR  %f  %m  %h  %r%=  tabs:8  (main)  %02l,%02c/%02L "
  eq(child.wo.statusline, expected)
end

T["smoke"]["inactive window success"] = function()
  child.cmd("new")
  local expected = "      %f  %m  %h  %r%=  tabs:8  %02l,%02c/%02L "
  local window_ids = child.lua_get("vim.api.nvim_tabpage_list_wins(0)")
  local statusline_inactive_window =
    child.lua_get("vim.wo[" .. window_ids[2] .. "].statusline")
  eq(statusline_inactive_window, expected)
end

T["smoke"]["plugin window success"] = function()
  child.bo.filetype = "test"
  child.bo.buflisted = false
  local expected = " [test]  %m%=%02l,%02c/%02L "
  eq(child.wo.statusline, expected)
end

-- COMPONENTS

T["components"] = new_set({
  hooks = {
    pre_case = function()
      child.lua("bareline.setup()")
    end
  }
})

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
  local vim_mode = child.lua_get("bareline.components.vim_mode:get_value()")
  eq(vim_mode, expected_vim_mode)
end

-- PLUGIN_NAME

T["components"]["plugin_name"] = new_set({
  hooks = {
    pre_case = function()
      child.lua([[
        qf = "%t%{exists('w:quickfix_title')? ' '.w:quickfix_title : ''}"
      ]])
    end
  }
})

T["components"]["plugin_name"]["quickfix list success"] = function()
  child.cmd("copen")
  local plugin_name =
    child.lua_get("bareline.components.plugin_name:get_value()")
  eq(plugin_name, child.lua_get("qf"))
end

T["components"]["plugin_name"]["location list success"] = function()
  child.cmd("edit " .. resources .. "/foo.txt")
  child.cmd("lvimgrep 'foo' %")
  child.cmd("cd " .. resources)
  child.cmd("lopen")
  local plugin_name =
    child.lua_get("bareline.components.plugin_name:get_value()")
  eq(plugin_name, child.lua_get("qf"))
end

T["components"]["plugin_name"]["fallback success"] = function()
  child.bo.filetype = "NvimTree"
  local plugin_name =
    child.lua_get("bareline.components.plugin_name:get_value()")
  eq(plugin_name, "[nvimtree]")
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
    { "/tests/resources/git_dir_branch/", "(main)" },
    { "/tests/resources/git_dir_hash/",   "(b1a8f4a)" },
    { "/tests/resources/git_dir_tag/",    "(b1a8f4a)" },
  }
})

T["components"]["git_head"]["success"] = function(git_dir, expected_git_head)
  child.cmd("cd " .. root .. git_dir)
  local git_head = child.lua_get("bareline.components.git_head:get_value()")
  eq(git_head, expected_git_head)
end

-- FILE_PATH_RELATIVE_TO_CWD

T["components"]["file_path_relative_to_cwd"] = new_set({})

T["components"]["file_path_relative_to_cwd"]["%f"] = new_set({})

T["components"]["file_path_relative_to_cwd"]["%f"]["[No Name]"] = function()
  child.cmd("cd " .. resources)
  local file_path_relative_to_cwd = child.lua_get(
    "bareline.components.file_path_relative_to_cwd:get_value()")
  eq(file_path_relative_to_cwd, "%f")
end

T["components"]["file_path_relative_to_cwd"]["%f"]["help page"] = function()
  child.cmd("cd " .. resources)
  child.cmd("help")
  local file_path_relative_to_cwd = child.lua_get(
    "bareline.components.file_path_relative_to_cwd:get_value()")
  eq(file_path_relative_to_cwd, "%f")
end

T["components"]["file_path_relative_to_cwd"]["trim cwd"] = new_set({
  parametrize = {
    { { cd = resources, edit = "test_file.txt" }, "test_file.txt" },
    {
      {
        cd = resources .. "/dir_a",
        edit = "dir_a_a/.gitkeep"
      },
      "dir_a_a/.gitkeep"
    },
    {
      {
        cd = resources .. "/dir_b",
        edit = resources .. "/dir_a/dir_a_a/.gitkeep"
      },
      resources .. "/dir_a/dir_a_a/.gitkeep"
    },
    -- Main test case. An absolute file path is used for `:e`, but the file path
    -- displayed should be relative to the current working directory.
    {
      {
        cd = resources .. "/dir_a",
        edit = resources .. "/dir_a/dir_a_a/.gitkeep"
      },
      "dir_a_a/.gitkeep"
    }
  }
})

T["components"]["file_path_relative_to_cwd"]["trim cwd"]["success"] = function(
    setup, expected_file_path)
  child.cmd("cd " .. setup.cd)
  child.cmd("edit " .. setup.edit)
  local file_path_relative_to_cwd = child.lua_get(
    "bareline.components.file_path_relative_to_cwd:get_value()")
  eq(file_path_relative_to_cwd, expected_file_path)
end

T["components"]["file_path_relative_to_cwd"]["sanitize"] = new_set({
  parametrize = {
    { resources .. "/injection/%", " %% ", " % " },
    { resources .. "/injection/%%", " %%%% ", " %% " },
    { resources .. "/injection/%f%m", " %%f%%m ", " %f%m " },
    { resources .. "/injection/%{0}", " %%{0} ", " %{0} " },
    { resources .. "/injection/%{%0%}", " %%{%%0%%} ", " %{%0%} " },
    { resources .. "/injection/%(0%)", " %%(0%%) ", " %(0%) " },
    { resources .. "/injection/%@B@c.c%X", " %%@B@c.c%%X ", " %@B@c.c%X " },
    { resources .. "/injection/%<", " %%< ", " %< " },
    { resources .. "/injection/%=", " %%= ", " %= " },
    { resources .. "/injection/%#Normal#", " %%#Normal# ", " %#Normal# " },
    { resources .. "/injection/%1*%*", " %%1*%%* ", " %1*%* " }
  }
})

T["components"]["file_path_relative_to_cwd"]["sanitize"]["success"] =
  function(file, expected_statusline, expected_evaluated_statusline)
    child.stop()
    child.restart({ "-u", "scripts/minimal_init.lua", file })
    child.lua([[
    local bareline = require("bareline")
    bareline.setup({
      statusline = {
        { { bareline.components.file_path_relative_to_cwd } },
        { { bareline.components.file_path_relative_to_cwd } },
        { { bareline.components.file_path_relative_to_cwd } }
      }
    })]])
    child.cmd("cd " .. resources .. "/injection")
    eq(child.wo.statusline, expected_statusline)
    eq(
      vim.api.nvim_eval_statusline(child.wo.statusline, {}).str,
      expected_evaluated_statusline
    )
end

T["components"]["file_path_relative_to_cwd"]["lua_special_chars"] = new_set({})

T["components"]["file_path_relative_to_cwd"]["lua_special_chars"]["success"] =
  function()
    local file = resources .. "/dir_lua_special_chars_^$()%.[]*+-?/.gitkeep"
    child.stop()
    child.restart({ "-u", "scripts/minimal_init.lua", file })
    child.lua([[
    local bareline = require("bareline")
    bareline.setup({
      statusline = {
        { { bareline.components.file_path_relative_to_cwd } },
        { { bareline.components.file_path_relative_to_cwd } },
        { { bareline.components.file_path_relative_to_cwd } }
      }
    })]])
    child.cmd("cd " .. resources)
    eq(child.wo.statusline, " dir_lua_special_chars_^$()%%.[]*+-?/.gitkeep ")
    eq(
      vim.api.nvim_eval_statusline(child.wo.statusline, {}).str,
      " dir_lua_special_chars_^$()%.[]*+-?/.gitkeep "
    )
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
      child.cmd("cd " .. resources)
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
