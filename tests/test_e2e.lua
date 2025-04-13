---@diagnostic disable: undefined-field, undefined-global

-- IMPORTANT: This file contains several Unicode Thin Space (U+2009) chars: ` `. These look
-- identical as a regular whitespace. These chars are relevant in the assertions. If you use the
-- kitty terminal, you can highlight them with a mark: <https://sw.kovidgoyal.net/kitty/marks/>.

-- See: <https://github.com/echasnovski/mini.nvim/blob/main/TESTING.md>.

local h = dofile("tests/helpers.lua")

local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality
local child = MiniTest.new_child_neovim()

local T = new_set({
  hooks = {
    pre_once = function()
      h.create_tmp_testing_dir()
    end,
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
      child.lua([[bareline = require("bareline")]])
    end,
    post_once = function()
      h.delete_tmp_testing_dir()
      child.stop()
    end,
  },
})

T["e2e"] = new_set({})

-- DEFAULTS

-- TODO: Test integration with <https://github.com/lewis6991/gitsigns.nvim>.

T["e2e"]["defaults"] = new_set({
  hooks = {
    pre_case = function()
      child.lua([[bareline.setup()]])
      child.cmd("cd " .. h.resources_dir)
    end,
  },
})

T["e2e"]["defaults"]["active buf using bareline.config.statusline"] = function()
  -- TODO: Remove `new` call.
  -- I do not know why calling `new` is necessary. When not called, the Vim mode, filepath, indent
  -- style and cwd components are missing. Looking at the logs I noticed that `BufEnter` autocmds
  -- are not run (this is only a problem when using `mini.test`), and one of those is responsible
  -- for setting the initial value of the buf-local vars.
  child.cmd("new")
  child.o.columns = 50
  local expected = " NOR  [No Name]       tabs:8  resources  00:00/01 "
  eq(child.api.nvim_eval_statusline(child.wo.statusline, {}).str, expected)
end

-- TODO: Implement test.
-- T["e2e"]["defaults"]["inactive buf using bareline.config.statusline"] = function()
-- end

-- TODO: Implement test.
-- T["e2e"]["defaults"]["active buf using bareline.statuslines.alt_statusline.plugin"] = function()
-- end

T["e2e"]["defaults"]["items.mhr.display_modified (true)"] = function()
  child.lua([[bareline.setup({
    statusline = {
      value = "%{%get(b:,'bl_mhr','')%}",
      items = { bareline.items.mhr },
    }
  })]])
  child.o.columns = 12
  local expected = "[+]"
  child.cmd("new") -- TODO: Remove `new` call. Should not be needed.
  child.type_keys("aTest")
  eq(child.api.nvim_eval_statusline(child.wo.statusline, {}).str, expected)
end

-- OVERRIDE DEFAULTS

T["e2e"]["config via setup()"] = new_set({})

T["e2e"]["config via setup()"]["statusline"] = new_set({
  hooks = {
    pre_case = function()
      child.lua([[
        bareline.setup({
          statusline = {
            value = "%<"
            .. "%{BlPad(get(b:,'bl_filepath',''))}"
            .. "%{BlPad(get(b:,'bl_lsp_servers',''))}"
            .. "%m%h%r"
            .. "%="
            .. "%{BlPad(get(b:,'bl_diagnostics',''))}"
            .. "%{BlInarm(BlPad(BlWrap(get(b:,'gitsigns_head',''),'(',')')))}"
            .. "%{BlIs(1)}"
            .. "%02l:%02c/%02L"
            .. "%{BlIs(1)}",
            items = {
              bareline.items.filepath,
              bareline.items.lsp_servers,
              bareline.items.diagnostics,
            },
          },
        })
      ]])
    end,
  },
})

T["e2e"]["config via setup()"]["statusline"]["active buf"] = function()
  child.cmd("new") -- TODO: Remove `new` call. Should not be needed.
  child.o.columns = 24
  local expected = " [No Name]     00:00/01 "
  eq(child.api.nvim_eval_statusline(child.wo.statusline, {}).str, expected)
end

-- TODO: Implement test.
-- T["e2e"]["config via setup()"]["statusline"]["inactive buf"] = function()
-- end

-- TODO: Test user-defined alt_statusline.
-- T["e2e"]["config via setup()"]["plugin stl from alt_statuslines"] = new_set({})

T["e2e"]["config via setup()"]["items.mhr.display_modified = false"] = function()
  child.lua([[bareline.setup({
    statusline = {
      value = "%{%get(b:,'bl_mhr','')%}",
      items = { bareline.items.mhr, },
    },
    items = {
      mhr = {
        display_modified = false
      }
    }
  })]])
  child.cmd("new") -- TODO: Remove `new` call. Should not be needed.
  child.o.columns = 12
  local expected = ""
  eq(child.api.nvim_eval_statusline(child.wo.statusline, {}).str, expected)
end

T["e2e"]["config via setup()"]["user-defined item uses bareline.items"] = function()
  child.lua([[item_hello = bareline.BareItem:new("bl_hello", function(var)
    vim.b[var] = "Hi! " .. bareline.config.items.hello.message
  end, {})]])
  child.lua([[bareline.setup({
    statusline = {
      value = "%{get(b:,'bl_hello','')}",
      items = { item_hello }
    },
    items = {
      hello = {
        message = "My name is Hernán"
      }
    }
  })]])
  child.cmd("new") -- TODO: Remove `new` call. Should not be needed.
  child.o.columns = 21
  local expected = "Hi! My name is Hernán"
  eq(child.api.nvim_eval_statusline(child.wo.statusline, {}).str, expected)
end

return T
