local h = dofile("tests/helpers.lua")
local mini_test = require("mini.test")

local child = mini_test.new_child_neovim()
local expect_reference_screenshot = mini_test.expect.reference_screenshot
local eq = mini_test.expect.equality
local new_set = mini_test.new_set

-- Unicode Thin Space (U+2009), as drawn by `bareline.space(1)`.
local ts = "\226\128\137"

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
-- Config: bareline.config.items.mhr

T["bareline.config.items.mhr.display_modified = true"] = function()
  child.lua_func(function()
    local bareline = require("bareline")
    bareline.setup({
      statusline = function()
        return { bareline.item("mhr") }
      end,
      items = {
        mhr = {
          display_modified = true,
        },
      },
    })
  end)
  child.type_keys("aTest")
  eq(h.get_child_evaluated_stl(child), "[+]")
end

T["bareline.config.items.mhr.display_modified = false"] = function()
  child.lua_func(function()
    local bareline = require("bareline")
    bareline.setup({
      statusline = function()
        return { bareline.item("mhr") }
      end,
      items = {
        mhr = {
          display_modified = false,
        },
      },
    })
  end)
  child.type_keys("aTest")
  eq(h.get_child_evaluated_stl(child), "")
end

-- =================================================================================================
-- Custom statusline

T["custom statusline"] = function()
  child.lua_func(function()
    local bareline = require("bareline")
    local s = bareline.space
    bareline.setup({
      statusline = function(ctx)
        return {
          "%<",
          bareline.item("filepath", { pad = true }),
          "%m%h%r",
          "%=",
          s(1),
          ctx.active and "%02l:%02c/%02L" or s(14),
          s(1),
        }
      end,
    })
    vim.cmd.new()
  end)
  child.type_keys("aTest")
  expect_reference_screenshot(child.get_screenshot())
end

-- =================================================================================================
-- Statusline parts

---@param statusline string Lua code of the function body, where `bareline` and `ctx` are in scope.
local function setup_statusline(statusline)
  child.lua_func(function(body)
    local bareline = require("bareline")
    local fn = assert(loadstring("local bareline, ctx = ...; " .. body))
    bareline.setup({
      statusline = function(ctx)
        return fn(bareline, ctx)
      end,
    })
  end, statusline)
end

T["text() escapes %"] = function()
  setup_statusline([[return { bareline.text("50%"), "%%" }]])
  eq(h.get_child_evaluated_stl(child), "50%%")
end

T["text() of nil is empty, so it gets neither pad nor wrap"] = function()
  setup_statusline([[return { "a", bareline.text(nil, { pad = true, wrap = { "(", ")" } }), "b" }]])
  eq(h.get_child_evaluated_stl(child), "ab")
end

T["wrap is applied before pad"] = function()
  setup_statusline([[return { bareline.text("x", { pad = true, wrap = { "(", ")" } }) }]])
  eq(h.get_child_evaluated_stl(child), ts .. "(x)" .. ts)
end

T["nil and false parts are skipped, nested lists are flattened"] = function()
  setup_statusline([[return { "a", nil, false, { "b", { "c" } }, "d" }]])
  eq(h.get_child_evaluated_stl(child), "abcd")
end

T["each() applies its opts to each part, and the opts of a part win"] = function()
  setup_statusline([[
    return bareline.each({ pad = true }, {
      bareline.text("a"),
      "|",
      { bareline.text("b") },
      bareline.text("c", { pad = false }),
    })
  ]])
  eq(h.get_child_evaluated_stl(child), ts .. "a" .. ts .. "|" .. ts .. "b" .. ts .. "c")
end

T["inactive = remove, hide"] = function()
  setup_statusline([[
    return {
      "[",
      bareline.text("rm", { inactive = "remove" }),
      bareline.text("hide", { inactive = "hide", pad = true }),
      "]",
    }
  ]])
  child.cmd("new")
  local inactive_win = child.fn.win_getid(2)
  eq(h.get_child_evaluated_stl(child), "[rm" .. ts .. "hide" .. ts .. "]")
  eq(h.get_child_evaluated_stl(child, inactive_win), "[" .. ts:rep(6) .. "]")
end

T["the function runs in the window being drawn"] = function()
  setup_statusline([[return { bareline.text(vim.b.name) }]])
  child.b.name = "below"
  child.cmd("new")
  child.b.name = "above"
  eq(h.get_child_evaluated_stl(child), "above")
  eq(h.get_child_evaluated_stl(child, child.fn.win_getid(2)), "below")
end

T["an error draws the fallback statusline"] = function()
  setup_statusline([[error("boom")]])
  eq(h.get_child_evaluated_stl(child):match("^%[No Name%]"), "[No Name]")
  -- The error is shown once, on the next event loop cycle.
  h.get_child_evaluated_stl(child)
  child.lua("vim.wait(50)")
  local messages = child.api.nvim_exec2("messages", { output = true }).output
  eq(select(2, messages:gsub("Bareline: ", "")), 1)
end

-- =================================================================================================
-- User-defined BareItem

T["user-defined BareItem"] = function()
  child.lua_func(function()
    local bareline = require("bareline")
    bareline.items.hello = bareline.BareItem:new("bl_hello", function(var)
      vim.b[var] = "Hi!"
    end, {})
  end)
  setup_statusline([[return { bareline.item("hello") }]])
  eq(h.get_child_evaluated_stl(child), "Hi!")
end

T["user-defined BareItem uses bareline.config.items"] = function()
  child.lua_func(function()
    local bareline = require("bareline")
    bareline.items.hello = bareline.BareItem:new("bl_hello", function(var)
      vim.b[var] = "Hi! " .. bareline.config.items.hello.message
    end, {})
    bareline.setup({
      statusline = function()
        return { bareline.item("hello") }
      end,
      items = {
        hello = {
          message = "Test",
        },
      },
    })
  end)
  eq(h.get_child_evaluated_stl(child), "Hi! Test")
end

T["item() creates the autocmds of drawn items only"] = function()
  child.lua_func(function()
    local bareline = require("bareline")
    bareline.items.wrap = bareline.BareItem:new("bl_wrap", function(var)
      vim.b[var] = vim.wo.wrap and "wrap" or "nowrap"
    end, { autocmds = { { event = "OptionSet", opts = { pattern = "wrap" } } } })
    bareline.items.list = bareline.BareItem:new("bl_list", function(var)
      vim.b[var] = "list"
    end, { autocmds = { { event = "OptionSet", opts = { pattern = "list" } } } })
  end)
  setup_statusline([[return { bareline.item("wrap") }]])
  eq(h.get_child_evaluated_stl(child), "wrap")
  child.cmd("set nowrap")
  eq(h.get_child_evaluated_stl(child), "nowrap")
  eq(child.lua_get("#vim.api.nvim_get_autocmds({ event = 'OptionSet', pattern = 'list' })"), 0)
end

return T
