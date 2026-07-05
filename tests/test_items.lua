local h = dofile("tests/helpers.lua")
local mini_test = require("mini.test")

local child = mini_test.new_child_neovim()
local eq = mini_test.expect.equality
local new_set = mini_test.new_set

local T = new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
      child.lua('bareline = require("bareline")')
      child.lua("bareline.setup()")
    end,
    post_once = function()
      child.stop()
    end,
  },
})

-- =================================================================================================
-- vim_mode

-- stylua: ignore start
T["vim_mode"] = new_set({
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

T["vim_mode"]["parametrized"] = function(keys, expected)
  child.type_keys(keys)
  child.lua_func(function()
    local item = require("bareline").items.vim_mode
    item.callback(item.var)
  end)
  eq(child.b[child.lua_get("bareline.items.vim_mode.var")], expected)
end

-- =================================================================================================
-- filepath

T["filepath"] = new_set({})

T["filepath"]["[No Name]"] = function()
  child.lua_func(function()
    local item = require("bareline").items.filepath
    item.callback(item.var)
  end)
  eq(child.b[child.lua_get("bareline.items.filepath.var")], "[No Name]")
end

T["filepath"]["trim current working dir"] = new_set({
  parametrize = {
    -- Happy path.
    {
      {
        cd = h.resources_dir,
        edit = "test.txt",
      },
      "test.txt",
    },
    -- The displayed filepath should be *absolute* when the file opened with `:e` is not within cwd.
    -- The user home part in the displayed filepath should be substituted with the caret symbol (~).
    {
      {
        cd = h.resources_dir .. "/dir_b",
        edit = h.resources_dir .. "/dir_a/nested/a.txt",
      },
      string.gsub(h.resources_dir, h.escape_lua_pattern(os.getenv("HOME")), "~")
        .. "/dir_a/nested/a.txt",
    },
    -- The filepath in stl should be *relative* to cwd when a *relative* filepath is used in `:e`.
    {
      {
        cd = h.resources_dir .. "/dir_a",
        edit = "nested/a.txt",
      },
      "nested/a.txt",
    },
    -- The filepath in stl should be *relative* to cwd when an *absolute* filepath is used in `:e`.
    {
      {
        cd = h.resources_dir .. "/dir_a",
        edit = h.resources_dir .. "/dir_a/nested/a.txt",
      },
      "nested/a.txt",
    },
  },
})

T["filepath"]["trim current working dir"]["parametrized"] = function(setup, expected)
  child.lua_func(function(s)
    vim.cmd.cd(s.cd)
    vim.cmd.edit(s.edit)
    local item = require("bareline").items.filepath
    item.callback(item.var)
  end, setup)
  eq(child.b[child.lua_get("bareline.items.filepath.var")], expected)
end

T["filepath"]["terminal buffer"] = function()
  child.cmd("term")
  -- Check that the buffer variable was set by the `TermOpen` autocmd.
  -- Don't call the callback manually since the autocmd should trigger it.
  local result = child.b[child.lua_get("bareline.items.filepath.var")]
  eq(string.match(result, "^term://"), "term://")
end

-- =================================================================================================
-- mhr

T["mhr"] = new_set({})

T["mhr"]["include %m%h%r when [No Name]"] = function()
  child.lua_func(function()
    local item = require("bareline").items.mhr
    item.callback(item.var)
  end)
  eq(child.b[child.lua_get("bareline.items.mhr.var")], "%m%h%r")
end

T["mhr"]["include %m%h%r in file"] = function()
  child.cmd("edit " .. h.resources_dir .. "/test.txt")
  child.lua_func(function()
    local item = require("bareline").items.mhr
    item.callback(item.var)
  end)
  eq(child.b[child.lua_get("bareline.items.mhr.var")], "%m%h%r")
end

T["mhr"]["include %h%r in Vim help file"] = function()
  child.lua_func(function()
    vim.cmd.help()
    local item = require("bareline").items.mhr
    item.callback(item.var)
  end)
  eq(child.b[child.lua_get("bareline.items.mhr.var")], "%h%r")
end

T["mhr"]["include %h%r in 'nomodifiable' buf"] = function()
  child.lua_func(function()
    vim.bo.modifiable = false
    local item = require("bareline").items.mhr
    item.callback(item.var)
  end, setup)
  eq(child.b[child.lua_get("bareline.items.mhr.var")], "%h%r")
end

-- T["items"]["mhr"]["exclude %m as per boolean config (in [No Name])"] = function()
--   eq(child.lua_get("bareline.items.mhr:config({ display_modified = false }):get()"), "%h%r")
--
--   child.cmd("new")
--   child.lua("item = bareline.items.mhr")
--   child.lua("item.callback(item.var, item.opts)")
--   eq(child.b[child.lua_get("bareline.items.mhr.var")], "%m%h%r")
-- end
--
-- T["items"]["mhr"]["exclude %m as per function config"] = function()
--   eq(
--     child.lua_get([[bareline.items.mhr:config({
--           display_modified = function()
--             return false
--           end
--         }):get()]]),
--     "%h%r"
--   )
-- end
--
-- T["items"]["mhr"]["include %m as per function config"] = function()
--   eq(
--     child.lua_get([[bareline.items.mhr:config({
--           display_modified = function()
--             return true
--           end
--         }):get()]]),
--     "%m%h%r"
--   )
-- end

-- =================================================================================================
-- indent_style

-- stylua: ignore start
T["indent_style"] = new_set({
  parametrize = {
    { vim.NIL,  vim.NIL,  "tabs:8"   }, -- Nvim defaults.
    { false,    4,        "tabs:4"   },
    { true,     2,        "spaces:2" },
    { true,     4,        "spaces:4" },
  }
})
-- stylua: ignore end

T["indent_style"]["parametrized"] = function(expandtab, tabstop, expected)
  if expandtab ~= vim.NIL then
    child.bo.expandtab = expandtab
  end
  if tabstop ~= vim.NIL then
    child.bo.tabstop = tabstop
  end
  child.lua_func(function()
    local item = require("bareline").items.indent_style
    item.callback(item.var)
  end)
  eq(child.b[child.lua_get("bareline.items.indent_style.var")], expected)
end

-- =================================================================================================
-- end_of_line

T["end_of_line"] = new_set({
  parametrize = {
    { ":set eol<CR>", vim.NIL },
    { ":set noeol<CR>", "noeol" },
  },
})

T["end_of_line"]["parametrized"] = function(keys, expected)
  child.type_keys(keys)
  child.lua_func(function()
    local item = require("bareline").items.end_of_line
    item.callback(item.var)
  end)
  eq(child.b[child.lua_get("bareline.items.end_of_line.var")], expected)
end

-- =================================================================================================
-- diagnostics

T["diagnostics"] = new_set({
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

T["diagnostics"]["parametrized"] = function(diagnostics, expected)
  child.api.nvim_create_namespace("test")
  local test_ns = child.api.nvim_get_namespaces().test
  child.diagnostic.set(test_ns, 0, diagnostics)
  child.lua_func(function()
    local item = require("bareline").items.diagnostics
    item.callback(item.var)
  end)
  eq(child.b[child.lua_get("bareline.items.diagnostics.var")], expected)
end

-- =================================================================================================
-- cwd

T["cwd"] = new_set({
  -- stylua: ignore start
  parametrize = {
    { h.resources_dir, vim.NIL,    "resources" },
    { h.resources_dir, "test.txt", "resources" },
    { vim.env.HOME,    vim.NIL,    "~" }
  }
  -- stylua: ignore end
})

T["cwd"]["display in file"] = function(dir, filename, expected)
  child.cmd("cd " .. dir)
  if filename ~= vim.NIL then
    child.cmd("edit " .. filename)
  end
  child.lua_func(function()
    local item = require("bareline").items.current_working_dir
    item.callback(item.var)
  end)
  eq(child.b[child.lua_get("bareline.items.current_working_dir.var")], expected)
end

-- =================================================================================================
-- plugin_name

T["plugin_name"] = new_set({})

T["plugin_name"]["quickfix"] = new_set({
  parametrize = {
    { "test.txt", ":copen<CR>", "[Quickfix List]" },
    { "test.txt", ":vimgrep /test/ %<CR>:copen<CR>", "[Quickfix List] :vimgrep /test/ test.txt" },
    { "test.txt", ":lvimgrep /test/ %<CR>:lopen<CR>", "[Location List] :lvimgrep /test/ test.txt" },
  },
})

T["plugin_name"]["quickfix"]["parametrized"] = function(filename, keys, expected)
  child.cmd("cd " .. h.resources_dir)
  child.cmd("edit " .. filename)
  child.type_keys(keys)
  child.lua_func(function()
    local item = require("bareline").items.plugin_name
    item.callback(item.var)
  end)
  local var_value = child.b[child.lua_get("bareline.items.plugin_name.var")]
  eq(child.api.nvim_eval_statusline(var_value, {}).str, expected)
end

T["plugin_name"]["no quickfix"] = new_set({
  parametrize = {
    { "NvimTree", "[nvimtree]" },
    -- A "lua" filetype does not indicate a plugin buf, however the plugin_name BareItem simply
    -- always falls back to the filetype when the buf is neither the quickfix nor the loclist.
    { "lua", "[lua]" },
  },
})

T["plugin_name"]["no quickfix"]["parametrized"] = function(filetype, expected)
  child.bo.filetype = filetype
  child.lua_func(function()
    local item = require("bareline").items.plugin_name
    item.callback(item.var)
  end)
  eq(child.b[child.lua_get("bareline.items.plugin_name.var")], expected)
end

return T
