local h = dofile("tests/helpers.lua")
local mini_test = require("mini.test")

local child = mini_test.new_child_neovim()
local expect_reference_screenshot = mini_test.expect.reference_screenshot
local eq = mini_test.expect.equality
local new_set = mini_test.new_set

local T = new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
      child.lua('bareline = require("bareline")')
      -- Do not show the intro screen.
      child.o.shortmess = "ltToOCFI"
    end,
    post_once = function()
      child.stop()
    end,
  },
})

-- =================================================================================================
-- Triad (active, inactive, plugin)

-- IMPORTANT: The golden files contain several Unicode Thin Space (U+2009) chars: ` `.

T["active window"] = function()
  child.lua_func(function(resources_dir)
    require("bareline").setup()
    vim.cmd.cd(resources_dir)
  end, h.resources_dir)
  expect_reference_screenshot(child.get_screenshot())
end

T["inactive window"] = function()
  child.lua_func(function(resources_dir)
    require("bareline").setup()
    vim.cmd.cd(resources_dir)
    vim.cmd.new()
  end, h.resources_dir)
  expect_reference_screenshot(child.get_screenshot())
end

T["plugin window"] = function()
  child.lua_func(function()
    -- Simulate plugin win.
    vim.bo.buflisted = false
    vim.bo.filetype = "NvimTree"
    require("bareline").setup()
  end)
  expect_reference_screenshot(child.get_screenshot())
end

-- =================================================================================================
-- Config: bareline.config.statusline.items.mhr

T["bareline.config.items.mhr.display_modified = true"] = function()
  child.lua_func(function()
    require("bareline").setup({
      statusline = {
        value = "%{%BlItem('mhr')%}",
      },
      items = {
        mhr = {
          display_modified = true,
        },
      },
    })
  end)
  child.type_keys("aTest")
  eq(child.api.nvim_eval_statusline(child.wo.statusline, {}).str, "[+]")
end

T["bareline.config.items.mhr.display_modified = false"] = function()
  child.lua_func(function()
    require("bareline").setup({
      statusline = {
        value = "%{%BlItem('mhr')%}",
      },
      items = {
        mhr = {
          display_modified = false,
        },
      },
    })
  end)
  child.type_keys("aTest")
  eq(child.api.nvim_eval_statusline(child.wo.statusline, {}).str, "")
end

-- =================================================================================================
-- Custom statusline

T["custom statusline"] = function()
  child.lua_func(function()
    require("bareline").setup({
      statusline = {
        value = "%<"
          .. "%{BlPad(BlItem('filepath'))}"
          .. "%m%h%r"
          .. "%="
          .. "%{BlIs(1)}"
          .. "%{%BlInahide('%02l:%02c/%02L')%}"
          .. "%{BlIs(1)}",
      },
    })
    vim.cmd.new()
  end)
  child.type_keys("aTest")
  expect_reference_screenshot(child.get_screenshot())
end

-- =================================================================================================
-- User-defined BareItem

T["user-defined BareItem"] = function()
  child.lua_func(function()
    local bareline = require("bareline")
    bareline.items.hello = bareline.BareItem:new("bl_hello", function(var)
      vim.b[var] = "Hi!"
    end, {})
    bareline.setup({
      statusline = {
        value = "%{BlItem('hello')}",
      },
    })
  end)
  eq(child.api.nvim_eval_statusline(child.wo.statusline, {}).str, "Hi!")
end

T["user-defined BareItem uses bareline.config.items"] = function()
  child.lua_func(function()
    local bareline = require("bareline")
    bareline.items.hello = bareline.BareItem:new("bl_hello", function(var)
      vim.b[var] = "Hi! " .. bareline.config.items.hello.message
    end, {})
    bareline.setup({
      statusline = {
        value = "%{BlItem('hello')}",
      },
      items = {
        hello = {
          message = "Test",
        },
      },
    })
  end)
  eq(child.api.nvim_eval_statusline(child.wo.statusline, {}).str, "Hi! Test")
end

T["BlItem() creates the autocmds of drawn items only"] = function()
  child.lua_func(function()
    local bareline = require("bareline")
    bareline.items.wrap = bareline.BareItem:new("bl_wrap", function(var)
      vim.b[var] = vim.wo.wrap and "wrap" or "nowrap"
    end, { autocmds = { { event = "OptionSet", opts = { pattern = "wrap" } } } })
    bareline.items.list = bareline.BareItem:new("bl_list", function(var)
      vim.b[var] = "list"
    end, { autocmds = { { event = "OptionSet", opts = { pattern = "list" } } } })
    bareline.setup({ statusline = { value = "%{BlItem('wrap')}" } })
  end)
  eq(h.get_child_evaluated_stl(child), "wrap")
  child.cmd("set nowrap")
  eq(h.get_child_evaluated_stl(child), "nowrap")
  eq(child.lua_get("#vim.api.nvim_get_autocmds({ event = 'OptionSet', pattern = 'list' })"), 0)
end

return T
