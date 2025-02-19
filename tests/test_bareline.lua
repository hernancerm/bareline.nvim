---@diagnostic disable: undefined-field, undefined-global

-- See: https://github.com/echasnovski/mini.nvim/blob/main/TESTING.md

if not vim.fn.executable("git") then
  print("Unsatisfied requirement: Git is not installed.\n")
  os.exit(1)
end

local tmp_dir_for_testing = vim.fn.stdpath("data")
  .. "/bareline.nvim/tmp_dir_for_testing"
local h = dofile("tests/helpers.lua")

local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality
local child = MiniTest.new_child_neovim()

local T = new_set({
  hooks = {
    pre_once = function()
      h.rename_gitdir_to_dotdir()
      h.create_git_worktree()
      vim.fn.mkdir(tmp_dir_for_testing, "p")
    end,
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
      child.lua([[bareline = require("bareline")]])
    end,
    post_once = function()
      h.remove_git_worktree()
      h.rename_dotdir_to_gitdir()
      vim.fn.delete(tmp_dir_for_testing, "d")
      child.stop()
    end,
  },
})

T["smoke"] = new_set({
  hooks = {
    pre_case = function()
      child.lua("bareline.setup()")
      child.cmd("cd " .. h.resources_dir .. "/git_dir_branch/")
    end,
  },
})

-- SMOKE

T["smoke"]["active window success"] = function()
  local expected =
    " NOR  %f  %m  %h  %r%=  tabs:8  (main)  git_dir_branch  %02l:%02c/%02L "
  eq(child.wo.statusline, expected)
end

T["smoke"]["inactive window success"] = function()
  child.cmd("new")
  local expected =
    "      %f  %m  %h  %r%=  tabs:8  git_dir_branch  %02l:%02c/%02L "
  local window_ids = child.lua_get("vim.api.nvim_tabpage_list_wins(0)")
  local statusline_window_inactive =
    child.lua_get("vim.wo[" .. window_ids[2] .. "].statusline")
  eq(statusline_window_inactive, expected)
end

T["smoke"]["plugin window success"] = function()
  child.bo.filetype = "test"
  child.bo.buflisted = false
  local expected = " [test]  %m%=%02l:%02c/%02L "
  eq(child.wo.statusline, expected)
end

-- BARE COMPONENT

T["bare_component"] = new_set({})

T["bare_component"][":config()"] = new_set({})

T["bare_component"][":config()"]["user component option"] = new_set({
  hooks = {
    pre_case = function()
      child.lua(
        [[component_transform_file_type = bareline.BareComponent:new(function(opts)
          local transformer = opts.transformer
          if type(transformer) == "function" then
            return transformer(vim.bo.filetype)
          end
          return vim.bo.filetype
        end, {})]]
      )
    end,
  },
  parametrize = {
    { "vim.fn.sha256", vim.fn.sha256("text") },
    { "vim.base64.encode", vim.base64.encode("text") },
  },
})

T["bare_component"][":config()"]["user component option"]["parameterized"] = function(
  transformer,
  expected_value
)
  child.cmd("edit " .. h.resources_dir .. "/foo.txt")
  local actual_value = child.lua_get([[component_transform_file_type
    :config({ transformer = ]] .. transformer .. [[})
    :get()]])
  eq(actual_value, expected_value)
end

T["bare_component"][":config()"]["'mask' built-in option"] = new_set({
  parametrize = {
    { " ", "   " },
    { "*", "***" },
  },
})

T["bare_component"][":config()"]["'mask' built-in option"]["parameterized"] = function(
  char,
  expected_value
)
  local actual_value = child.lua_get(
    [[bareline.components.vim_mode:config({ mask = "]] .. char .. [[" }):get()]]
  )
  eq(actual_value, expected_value)
end

-- COMPONENTS

T["components"] = new_set({
  hooks = {
    pre_case = function()
      child.lua("bareline.setup()")
    end,
  },
})

-- VIM_MODE

T["components"]["vim_mode"] = new_set({
  -- stylua: ignore start
  parametrize = {
    { "",           "NOR" }, -- Normal.
    { "i",          "INS" }, -- Insert.
    { ":",          "CMD" }, -- Command.
    { "v",          "V:C" }, -- Charwise Visual.
    { "V",          "V:L" }, -- Linewise Visual.
    { "<C-q>",      "V:B" }, -- Block Visual.
    { ":term<CR>a", "TER" }, -- Terminal.
  }
,
  -- stylua: ignore end
})

T["components"]["vim_mode"]["parameterized"] = function(keys, expected_vim_mode)
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

T["components"]["plugin_name"]["quickfix list success"] = function()
  child.cmd("copen")
  local plugin_name = child.lua_get("bareline.components.plugin_name:get()")
  eq(plugin_name, child.lua_get("qf"))
end

T["components"]["plugin_name"]["location list success"] = function()
  child.cmd("edit " .. h.resources_dir .. "/foo.txt")
  child.cmd("lvimgrep 'foo' %")
  child.cmd("cd " .. h.resources_dir)
  child.cmd("lopen")
  local plugin_name = child.lua_get("bareline.components.plugin_name:get()")
  eq(plugin_name, child.lua_get("qf"))
end

T["components"]["plugin_name"]["fallback success"] = function()
  child.bo.filetype = "NvimTree"
  local plugin_name = child.lua_get("bareline.components.plugin_name:get()")
  eq(plugin_name, "[nvimtree]")
end

-- INDENT_STYLE

T["components"]["indent_style"] = new_set({
  -- stylua: ignore start
  parametrize = {
    { vim.NIL,  vim.NIL,  "tabs:8"   }, -- Nvim defaults.
    { false,    4,        "tabs:4"   },
    { true,     2,        "spaces:2" },
    { true,     4,        "spaces:4" },
  }
,
  -- stylua: ignore end
})

T["components"]["indent_style"]["parameterized"] = function(
  expandtab,
  tabstop,
  expected_indent_style
)
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

T["components"]["end_of_line"]["parameterized"] = function(keys, expected_eol_marker)
  child.type_keys(keys)
  local eol = child.lua_get("bareline.components.end_of_line:get()")
  eq(eol, expected_eol_marker)
end

-- GIT_HEAD

T["components"]["git_head"] = new_set({})

T["components"]["git_head"]["standard_repo"] = new_set({
  -- stylua: ignore start
  parametrize = {
    { "/git_dir_branch", "(main)" },
    { "/git_dir_hash",   "(f8ac697)" },
    { "/git_dir_tag",    "(03ffbf9)" },
  }
,
  -- stylua: ignore end
})

T["components"]["git_head"]["standard_repo"]["parameterized"] = function(
  git_dir,
  expected_git_head
)
  child.cmd("cd " .. h.resources_dir .. git_dir)
  local git_head = child.lua_get("bareline.components.git_head:get()")
  eq(git_head, expected_git_head)
end

T["components"]["git_head"]["detached working tree"] = function()
  child.cmd("cd " .. tmp_dir_for_testing)
  local git_bare_repo_dir = h.resources_dir .. "/git_dir_bare.git"
  local lua_code = [[bareline.components.git_head:config({
    worktrees = {
      {
        toplevel = "]] .. tmp_dir_for_testing .. [[", gitdir = "]] .. git_bare_repo_dir .. [["
      }
    }
  }):get()]]
  local git_head = child.lua_get(lua_code)
  eq(git_head, "(chasing-cars)")
end

T["components"]["git_head"]["added worktree"] = function()
  child.cmd("cd " .. h.resources_dir .. "/git_dir_branch_worktree")
  local git_head = child.lua_get("bareline.components.git_head:get()")
  eq(git_head, "(hotfix)")
end

-- FILE_PATH_RELATIVE_TO_CWD

T["components"]["file_path_relative_to_cwd"] = new_set({})

T["components"]["file_path_relative_to_cwd"]["%f"] = new_set({})

T["components"]["file_path_relative_to_cwd"]["%f"]["[No Name]"] = function()
  child.cmd("cd " .. h.resources_dir)
  local file_path_relative_to_cwd =
    child.lua_get("bareline.components.file_path_relative_to_cwd:get()")
  eq(file_path_relative_to_cwd, "%f")
end

T["components"]["file_path_relative_to_cwd"]["%f"]["help page"] = function()
  child.cmd("cd " .. h.resources_dir)
  child.cmd("help")
  local file_path_relative_to_cwd =
    child.lua_get("bareline.components.file_path_relative_to_cwd:get()")
  eq(file_path_relative_to_cwd, "%f")
end

T["components"]["file_path_relative_to_cwd"]["trim cwd"] = new_set({
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
      "%<" .. string.gsub(
        h.resources_dir,
        h.escape_lua_pattern(os.getenv("HOME")),
        "~"
      ) .. "/dir_a/dir_a_a/.gitkeep",
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

T["components"]["file_path_relative_to_cwd"]["trim cwd"]["parameterized"] = function(
  setup,
  expected_file_path
)
  child.cmd("cd " .. setup.cd)
  child.cmd("edit " .. setup.edit)
  local file_path_relative_to_cwd =
    child.lua_get("bareline.components.file_path_relative_to_cwd:get()")
  eq(file_path_relative_to_cwd, expected_file_path)
end

T["components"]["file_path_relative_to_cwd"]["sanitize"] = new_set({
  parametrize = {
    { h.resources_dir .. "/injection/%", " %<%% ", " % " },
    { h.resources_dir .. "/injection/%%", " %<%%%% ", " %% " },
    { h.resources_dir .. "/injection/%f%m", " %<%%f%%m ", " %f%m " },
    { h.resources_dir .. "/injection/%{0}", " %<%%{0} ", " %{0} " },
    { h.resources_dir .. "/injection/%{%0%}", " %<%%{%%0%%} ", " %{%0%} " },
    { h.resources_dir .. "/injection/%(0%)", " %<%%(0%%) ", " %(0%) " },
    {
      h.resources_dir .. "/injection/%@B@c.c%X",
      " %<%%@B@c.c%%X ",
      " %@B@c.c%X ",
    },
    { h.resources_dir .. "/injection/%<", " %<%%< ", " %< " },
    { h.resources_dir .. "/injection/%=", " %<%%= ", " %= " },
    {
      h.resources_dir .. "/injection/%#Normal#",
      " %<%%#Normal# ",
      " %#Normal# ",
    },
    { h.resources_dir .. "/injection/%1*%*", " %<%%1*%%* ", " %1*%* " },
  },
})

T["components"]["file_path_relative_to_cwd"]["sanitize"]["parameterized"] = function(
  file,
  expected_statusline,
  expected_evaluated_statusline
)
  child.lua([[
      bareline.setup({
        statuslines = {
          active = {{ bareline.components.file_path_relative_to_cwd }}
        }
      })]])
  child.cmd("cd " .. h.resources_dir .. "/injection")
  child.cmd("edit " .. string.gsub(file, "[%%#]", [[\%0]]))
  eq(child.wo.statusline, expected_statusline)
  eq(
    vim.api.nvim_eval_statusline(child.wo.statusline, {}).str,
    expected_evaluated_statusline
  )
end

T["components"]["file_path_relative_to_cwd"]["lua special chars"] = new_set({})

T["components"]["file_path_relative_to_cwd"]["lua special chars"]["parameterized"] = function()
  local file = h.resources_dir .. "/dir_lua_special_chars_^$()%.[]*+-?/.gitkeep"
  child.lua([[
      bareline.setup({
        statuslines = {
          active = {{ bareline.components.file_path_relative_to_cwd }}
        }
      })]])
  child.cmd("cd " .. h.resources_dir)
  child.cmd("edit " .. string.gsub(file, "[%%#]", [[\%0]]))
  eq(child.wo.statusline, " %<dir_lua_special_chars_^$()%%.[]*+-?/.gitkeep ")
  eq(
    vim.api.nvim_eval_statusline(child.wo.statusline, {}).str,
    " dir_lua_special_chars_^$()%.[]*+-?/.gitkeep "
  )
end

T["components"]["file_path_relative_to_cwd"]["truncate long path"] = new_set({})

T["components"]["file_path_relative_to_cwd"]["truncate long path"]["parameterized"] = function()
  child.lua([[
      bareline.setup({
        statuslines = {
          active = {{ bareline.components.file_path_relative_to_cwd }}
        }
      })]])
  child.cmd("cd " .. h.resources_dir)
  child.cmd("edit 123456789012")
  child.o.columns = 12
  eq(child.wo.statusline, " %<123456789012 ")
  eq(
    vim.api.nvim_eval_statusline(
      child.wo.statusline,
      { maxwidth = child.o.columns }
    ).str,
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

T["components"]["diagnostics"]["parameterized"] = function(
  diagnostics,
  expected_diagnostics
)
  child.api.nvim_create_namespace("test")
  local test_ns = child.api.nvim_get_namespaces().test
  child.diagnostic.set(test_ns, 0, diagnostics)
  eq(
    child.lua_get("bareline.components.diagnostics:get()"),
    expected_diagnostics
  )
end

-- POSITION

T["components"]["position"] = new_set({})

T["components"]["position"]["parameterized"] = function()
  eq(child.lua_get("bareline.components.position:get()"), "%02l:%02c/%02L")
end

-- CWD

T["components"]["cwd"] = new_set({
  parametrize = {
    { "tests/resources/dir_a", "dir_a" },
    { os.getenv("HOME"), "~" },
  },
})

T["components"]["cwd"]["parameterized"] = function(dir, expected_cwd)
  child.cmd("cd " .. dir)
  eq(child.lua_get("bareline.components.cwd:get()"), expected_cwd)
end

-- SETUP

T["setup"] = new_set({})

T["setup"]["fully_custom_statusline"] = new_set({
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

T["setup"]["fully_custom_statusline"]["custom statusline active window success"] = function()
  local expected = " NOR%=%02l:%02c/%02L "
  eq(child.wo.statusline, expected)
end

T["setup"]["fully_custom_statusline"]["custom statusline inactive window success"] = function()
  child.cmd("new")
  local expected = "    %=%02l:%02c/%02L "
  local window_ids = child.lua_get("vim.api.nvim_tabpage_list_wins(0)")
  local statusline_inactive_window =
    child.lua_get("vim.wo[" .. window_ids[2] .. "].statusline")
  eq(statusline_inactive_window, expected)
end

T["setup"]["fully_custom_statusline"]["custom statusline plugin window success"] = function()
  child.bo.filetype = "test"
  child.bo.buflisted = false
  local expected = " [test]%=%02l:%02c/%02L "
  eq(child.wo.statusline, expected)
end

T["setup"]["partially_custom_statusline"] = new_set({
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

T["setup"]["partially_custom_statusline"]["custom statusline active window success"] = function()
  eq(child.wo.statusline, " NOR%=%02l:%02c/%02L ")
end

T["setup"]["partially_custom_statusline"]["default statusline plugin window success"] = function()
  child.bo.filetype = "test"
  child.bo.buflisted = false
  child.bo.modifiable = false
  eq(child.wo.statusline, " [test]  %m%=%02l:%02c/%02L ")
end

T["setup"]["components.git_head"] = function()
  child.cmd("cd " .. tmp_dir_for_testing)
  local git_bare_repo_dir = h.resources_dir .. "/git_dir_bare.git"
  child.lua([[bareline.setup({
    components = {
      git_head = {
        worktrees = {
          {
            toplevel = "]] .. tmp_dir_for_testing .. [[", gitdir = "]] .. git_bare_repo_dir .. [["
          }
        }
      }
    }
  })]])
  eq(
    child.wo.statusline,
    " NOR  %f  %m  %h  %r%=  tabs:8  (chasing-cars)  tmp_dir_for_testing  %02l:%02c/%02L "
  )
end

T["setup"]["configure user component"] = function()
  child.cmd("edit " .. h.resources_dir .. "/foo.txt")
  child.lua(
    [[component_transform_file_type = bareline.BareComponent:new(function(opts)
      local transformer = opts.transformer
      if transformer == nil then
        transformer = bareline.config.components.transform_file_type.transformer
      end
      if type(transformer) == "function" then
        return transformer(vim.bo.filetype)
      end
      return vim.bo.filetype
    end, {})]]
  )
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
