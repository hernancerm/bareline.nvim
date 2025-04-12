---@diagnostic disable: undefined-field, undefined-global

-- IMPORTANT: This file contains several Unicode Thin Space (U+2009) chars: ` `. These look
-- identical as a regular whitespace. These chars are relevant in the assertions. If you use the
-- kitty terminal, you can highlight them with a mark: <https://sw.kovidgoyal.net/kitty/marks/>.

-- See: https://github.com/echasnovski/mini.nvim/blob/main/TESTING.md

local h = dofile("tests/helpers.lua")

local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality
local child = MiniTest.new_child_neovim()

local T = new_set({
  hooks = {
    pre_once = function()
      h.create_tmp_testing_dir()
      h.rename_git_dirs_for_testing()
      h.create_git_worktree()
    end,
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
      child.lua([[bareline = require("bareline")]])
    end,
    post_once = function()
      h.remove_git_worktree()
      h.rename_git_dirs_for_tracking()
      h.delete_tmp_testing_dir()
      child.stop()
    end,
  },
})

T["smoke"] = new_set({
  hooks = {
    pre_case = function()
      child.lua("bareline.setup()")
      child.cmd("cd " .. h.resources_dir)
      child.cmd("new") -- TODO: Not sure why this is needed.
    end,
  },
})

-- SMOKE

T["smoke"]["active window"] = function()
  child.o.columns = 50
  local expected = " NOR  [No Name]       tabs:8  resources  00:00/01 "
  eq(child.api.nvim_eval_statusline(child.wo.statusline, {}).str, expected)
end

T["smoke"]["inactive window"] = function()
  child.cmd("new")
  child.o.columns = 50
  local expected = "      [No Name]       tabs:8  resources  00:00/01 "
  local window_ids = child.lua_get("vim.api.nvim_tabpage_list_wins(0)")
  local statusline_window_inactive = child.lua_get("vim.wo[" .. window_ids[1] .. "].statusline")
  child.lua([[require("bareline").refresh_statusline()]])
  eq(child.api.nvim_eval_statusline(statusline_window_inactive, {}).str, expected)
end

T["smoke"]["plugin window"] = function()
  child.bo.filetype = "test"
  child.bo.buflisted = false
  child.o.columns = 21
  local expected = " [test]     00:00/01 "
  eq(child.api.nvim_eval_statusline(child.wo.statusline, {}).str, expected)
end

-- VIM_MODE

T["components"] = new_set({
  hooks = {
    pre_case = function()
      child.lua("bareline.setup()")
    end,
  },
})

-- stylua: ignore start
T["components"]["vim_mode"] = new_set({
  parametrize = {
    { "",            "NOR" }, -- Normal.
    { "i",           "INS" }, -- Insert.
    { ":",           "CMD" }, -- Command.
    { "v",           "V:C" }, -- Charwise Visual.
    { "V",           "V:L" }, -- Linewise Visual.
    { "<C-q>",       "V:B" }, -- Block Visual.
    { ":term<CR>a",  "TER" }, -- Terminal.
  }
})
-- stylua: ignore end

T["components"]["vim_mode"]["p"] = function(keys, expected_vim_mode)
  child.type_keys(keys)
  local vim_mode = child.lua_get("bareline.components.vim_mode:get()")
  eq(vim_mode, expected_vim_mode)
end

-- PLUGIN_NAME

T["components"]["plugin_name"] = new_set({
  hooks = {
    pre_case = function()
      child.lua([[
        qf = "%t%{exists('w:quickfix_title')? ' '.w:quickfix_title : ''}"
      ]])
    end,
  },
})

T["components"]["plugin_name"]["quickfix list"] = function()
  child.cmd("copen")
  local plugin_name = child.lua_get("bareline.components.plugin_name:get()")
  eq(plugin_name, child.lua_get("qf"))
end

T["components"]["plugin_name"]["location list"] = function()
  child.cmd("edit " .. h.resources_dir .. "/foo.txt")
  child.cmd("lvimgrep 'foo' %")
  child.cmd("cd " .. h.resources_dir)
  child.cmd("lopen")
  local plugin_name = child.lua_get("bareline.components.plugin_name:get()")
  eq(plugin_name, child.lua_get("qf"))
end

T["components"]["plugin_name"]["fallback"] = function()
  child.bo.filetype = "NvimTree"
  local plugin_name = child.lua_get("bareline.components.plugin_name:get()")
  eq(plugin_name, "[nvimtree]")
end

-- INDENT_STYLE

-- stylua: ignore start
T["components"]["indent_style"] = new_set({
  parametrize = {
    { vim.NIL,  vim.NIL,  "tabs:8"   }, -- Nvim defaults.
    { false,    4,        "tabs:4"   },
    { true,     2,        "spaces:2" },
    { true,     4,        "spaces:4" },
  }
})
-- stylua: ignore end

T["components"]["indent_style"]["p"] = function(expandtab, tabstop, expected_indent_style)
  if expandtab ~= vim.NIL then
    child.bo.expandtab = expandtab
  end
  if tabstop ~= vim.NIL then
    child.bo.tabstop = tabstop
  end
  local indent_style = child.lua_get("bareline.components.indent_style:get()")
  eq(indent_style, expected_indent_style)
end

-- END_OF_LINE

T["components"]["end_of_line"] = new_set({
  parametrize = {
    { ":set eol<CR>", vim.NIL },
    { ":set noeol<CR>", "noeol" },
  },
})

T["components"]["end_of_line"]["p"] = function(keys, expected_eol_marker)
  child.type_keys(keys)
  local eol = child.lua_get("bareline.components.end_of_line:get()")
  eq(eol, expected_eol_marker)
end

-- FILEPATH_RELATIVE_TO_CWD

T["components"]["filepath_relative_to_cwd"] = new_set({})

T["components"]["filepath_relative_to_cwd"]["%f"] = new_set({})

T["components"]["filepath_relative_to_cwd"]["%f"]["[No Name]"] = function()
  child.cmd("cd " .. h.resources_dir)
  local filepath_relative_to_cwd =
    child.lua_get("bareline.components.filepath_relative_to_cwd:get()")
  eq(filepath_relative_to_cwd, "%f")
end

T["components"]["filepath_relative_to_cwd"]["%f"]["[Help]"] = function()
  child.cmd("cd " .. h.resources_dir)
  child.cmd("help")
  local filepath_relative_to_cwd =
    child.lua_get("bareline.components.filepath_relative_to_cwd:get()")
  eq(filepath_relative_to_cwd, "%f")
end

T["components"]["filepath_relative_to_cwd"]["trim cwd"] = new_set({
  parametrize = {
    {
      {
        cd = h.resources_dir,
        edit = "test_file.txt",
      },
      "%<test_file.txt",
    },
    {
      {
        cd = h.resources_dir .. "/dir_a",
        edit = "dir_a_a/.gitkeep",
      },
      "%<dir_a_a/.gitkeep",
    },
    {
      {
        cd = h.resources_dir .. "/dir_b",
        edit = h.resources_dir .. "/dir_a/dir_a_a/.gitkeep",
      },
      "%<"
        .. string.gsub(h.resources_dir, h.escape_lua_pattern(os.getenv("HOME")), "~")
        .. "/dir_a/dir_a_a/.gitkeep",
    },
    -- An absolute file path is used for `:e`, but the file path displayed
    -- should be relative to the current working directory:
    {
      {
        cd = h.resources_dir .. "/dir_a",
        edit = h.resources_dir .. "/dir_a/dir_a_a/.gitkeep",
      },
      "%<dir_a_a/.gitkeep",
    },
    -- If the cwd is not home and a file rooted at home is edited, then the home
    -- portion of the file path should be replaced by `~`.
    {
      {
        cd = h.resources_dir,
        edit = os.getenv("HOME") .. "/this_file_does_not_need_to_exist.txt",
      },
      "%<~/this_file_does_not_need_to_exist.txt",
    },
  },
})

T["components"]["filepath_relative_to_cwd"]["trim cwd"]["p"] = function(setup, expected_filepath)
  child.cmd("cd " .. setup.cd)
  child.cmd("edit " .. setup.edit)
  local filepath_relative_to_cwd =
    child.lua_get("bareline.components.filepath_relative_to_cwd:get()")
  eq(filepath_relative_to_cwd, expected_filepath)
end

T["components"]["filepath_relative_to_cwd"]["truncate long path"] = function()
  child.lua([[
      bareline.setup({
        statuslines = {
          active = {{ bareline.components.filepath_relative_to_cwd }}
        }
      })]])
  child.cmd("cd " .. h.resources_dir)
  child.cmd("edit 123456789012")
  child.o.columns = 12
  eq(child.wo.statusline, " %<123456789012 ")
  eq(
    child.api.nvim_eval_statusline(child.wo.statusline, { maxwidth = child.o.columns }).str,
    " <456789012 "
  )
end

-- DIAGNOSTICS

T["components"]["diagnostics"] = new_set({
  parametrize = {
    {
      {
        {
          lnum = 1,
          col = 1,
          severity = vim.diagnostic.severity.WARN,
        },
      },
      "w:1",
    },
    {
      {
        {
          lnum = 1,
          col = 1,
          severity = vim.diagnostic.severity.ERROR,
        },
        {
          lnum = 1,
          col = 1,
          severity = vim.diagnostic.severity.HINT,
        },
        {
          lnum = 1,
          col = 1,
          severity = vim.diagnostic.severity.WARN,
        },
        {
          lnum = 1,
          col = 2,
          severity = vim.diagnostic.severity.WARN,
        },
      },
      "e:1,w:2,h:1",
    },
  },
})

T["components"]["diagnostics"]["p"] = function(diagnostics, expected_diagnostics)
  child.api.nvim_create_namespace("test")
  local test_ns = child.api.nvim_get_namespaces().test
  child.diagnostic.set(test_ns, 0, diagnostics)
  eq(child.lua_get("bareline.components.diagnostics:get()"), expected_diagnostics)
end

-- POSITION

T["components"]["position"] = function()
  eq(child.lua_get("bareline.components.position:get()"), "%02l:%02c/%02L")
end

-- CWD

T["components"]["cwd"] = new_set({})

T["components"]["cwd"]["display"] = function()
  child.cmd("cd " .. h.resources_dir)
  child.cmd("edit file.txt")
  eq(child.lua_get("bareline.components.cwd:get()"), "resources")
end

T["components"]["cwd"]["display in [No Name]"] = function()
  child.cmd("cd " .. h.resources_dir)
  eq(child.lua_get("bareline.components.cwd:get()"), "resources")
end

T["components"]["cwd"]["display caret (~) when the cwd is the user home"] = function()
  child.cmd("cd ~")
  child.cmd("edit i2o_tye8ieowiu-e8_yroi9ur.txt")
  eq(child.lua_get("bareline.components.cwd:get()"), "~")
end

-- MHR

T["components"]["mhr"] = new_set({})

T["components"]["mhr"]["include %m%h%r in unnamed buf"] = function()
  eq(child.lua_get("bareline.components.mhr:get()"), "%m%h%r")
end

T["components"]["mhr"]["include %m%h%r in buf with file"] = function()
  child.cmd("edit " .. h.resources_dir .. "/foo.txt")
  eq(child.lua_get("bareline.components.mhr:get()"), "%m%h%r")
end

T["components"]["mhr"]["include %h%r in vim help"] = function()
  child.cmd("help")
  eq(child.lua_get("bareline.components.mhr:get()"), "%h%r")
end

T["components"]["mhr"]["exclude %m in 'nomodifiable' buf"] = function()
  child.cmd("edit " .. h.resources_dir .. "/foo.txt")
  child.cmd("set nomodifiable")
  eq(child.lua_get("bareline.components.mhr:get()"), "%h%r")
end

T["components"]["mhr"]["exclude %m as per boolean config"] = function()
  eq(child.lua_get("bareline.components.mhr:config({ display_modified = false }):get()"), "%h%r")
end

T["components"]["mhr"]["exclude %m as per function config"] = function()
  eq(
    child.lua_get([[bareline.components.mhr:config({
          display_modified = function()
            return false
          end
        }):get()]]),
    "%h%r"
  )
end

T["components"]["mhr"]["include %m as per function config"] = function()
  eq(
    child.lua_get([[bareline.components.mhr:config({
          display_modified = function()
            return true
          end
        }):get()]]),
    "%m%h%r"
  )
end

-- SETUP

T["setup"] = new_set({})

T["setup"]["statusline fully custom"] = new_set({
  hooks = {
    pre_case = function()
      child.lua([[
        bareline.setup({
          statuslines = {
            active = {
              { bareline.components.vim_mode },
              { bareline.components.position }
            },
            inactive = {
              { bareline.components.vim_mode:config({ mask = " " }) },
              { bareline.components.position }
            },
            plugin = {
              { bareline.components.plugin_name },
              { bareline.components.position }
            }
          }
        })
      ]])
      child.cmd("cd " .. h.resources_dir)
    end,
  },
})

T["setup"]["statusline fully custom"]["active window"] = function()
  local expected = " NOR%=%02l:%02c/%02L "
  eq(child.wo.statusline, expected)
end

T["setup"]["statusline fully custom"]["inactive window"] = function()
  child.cmd("new")
  local expected = "    %=%02l:%02c/%02L "
  local window_ids = child.lua_get("vim.api.nvim_tabpage_list_wins(0)")
  local statusline_inactive_window = child.lua_get("vim.wo[" .. window_ids[2] .. "].statusline")
  eq(statusline_inactive_window, expected)
end

T["setup"]["statusline fully custom"]["plugin window"] = function()
  child.bo.filetype = "test"
  child.bo.buflisted = false
  local expected = " [test]%=%02l:%02c/%02L "
  eq(child.wo.statusline, expected)
end

T["setup"]["statusline partially custom"] = new_set({
  hooks = {
    pre_case = function()
      child.lua([[
        bareline.setup({
          statuslines = {
            active = {
              { bareline.components.vim_mode },
              { bareline.components.position }
            }
          }
        })
      ]])
      child.cmd("cd " .. h.resources_dir)
    end,
  },
})

T["setup"]["statusline partially custom"]["active window"] = function()
  eq(child.wo.statusline, " NOR%=%02l:%02c/%02L ")
end

T["setup"]["statusline partially custom"]["default statusline for plugin window"] = function()
  child.bo.filetype = "test"
  child.bo.buflisted = false
  child.bo.modifiable = false
  eq(child.wo.statusline, " [test]  %h%r%=%02l:%02c/%02L ")
end

T["setup"]["components.mhr"] = new_set({})

T["setup"]["components.mhr"]["display_modified = false"] = function()
  child.lua([[bareline.setup({
    statuslines = {
      active = {
        {
          bareline.components.vim_mode,
          bareline.components.filepath_relative_to_cwd,
          bareline.components.mhr,
        }
      }
    },
    components = {
      mhr = {
        display_modified = false
      }
    }
  })]])
  eq(child.wo.statusline, " NOR  %f  %h%r ")
end

T["setup"]["components.mhr"]["config() over config.components"] = function()
  child.lua([[bareline.setup({
    statuslines = {
      active = {
        {
          bareline.components.vim_mode,
          bareline.components.filepath_relative_to_cwd,
          bareline.components.mhr:config({ display_modified = true }),
        }
      }
    },
    components = {
      mhr = {
        display_modified = false
      }
    }
  })]])
  eq(child.wo.statusline, " NOR  %f  %m%h%r ")
end

T["setup"]["configure a user component"] = function()
  child.cmd("edit " .. h.resources_dir .. "/foo.txt")
  child.lua([[component_transform_file_type = bareline.BareComponent:new(function(opts)
      local transformer = opts.transformer
      if transformer == nil then
        transformer = bareline.config.components.transform_file_type.transformer
      end
      if type(transformer) == "function" then
        return transformer(vim.bo.filetype)
      end
      return vim.bo.filetype
    end, {})]])
  child.lua([[bareline.setup({
    statuslines = {
      active = {
        {
          component_transform_file_type
        }
      },
      inactive = {{}},
      plugin = {{}}
    },
    components = {
      transform_file_type = {
        transformer = vim.fn.sha256
      }
    }
  })]])
  eq(child.wo.statusline, " " .. vim.fn.sha256("text") .. " ")
end

return T
