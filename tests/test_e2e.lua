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
        value = "%{%get(b:,'bl_mhr','')%}",
        items = {
          require("bareline").items.mhr,
        },
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
        value = "%{%get(b:,'bl_mhr','')%}",
        items = {
          require("bareline").items.mhr,
        },
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
          .. "%{BlPad(get(b:,'bl_filepath',''))}"
          .. "%m%h%r"
          .. "%="
          .. "%{BlIs(1)}"
          .. "%{%BlInahide('%02l:%02c/%02L')%}"
          .. "%{BlIs(1)}",
        items = {
          require("bareline").items.filepath,
        },
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
    local item_hello = bareline.BareItem:new("bl_hello", function(var)
      vim.b[var] = "Hi!"
    end, {})
    bareline.setup({
      statusline = {
        value = "%{get(b:,'bl_hello','')}",
        items = {
          item_hello,
        },
      },
    })
  end)
  eq(child.api.nvim_eval_statusline(child.wo.statusline, {}).str, "Hi!")
end

T["user-defined BareItem uses bareline.config.items"] = function()
  child.lua_func(function()
    local bareline = require("bareline")
    local item_hello = bareline.BareItem:new("bl_hello", function(var)
      vim.b[var] = "Hi! " .. bareline.config.items.hello.message
    end, {})
    bareline.setup({
      statusline = {
        value = "%{get(b:,'bl_hello','')}",
        items = {
          item_hello,
        },
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

return T
