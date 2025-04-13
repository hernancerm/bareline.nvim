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

T["e2e"] = new_set({
  hooks = {
    pre_case = function()
      child.lua([[bareline.setup({ logging = { enabled = true } })]])
    end,
  },
})

T["e2e"]["active window"] = function()
  -- I do not know why calling `new` is necessary. When not called, the Vim mode, filepath, indent
  -- style and cwd components are missing. Looking at the logs I noticed that `BufEnter` autocmds
  -- are not run (this is only a problem when using `mini.test`), and one of those is responsible
  -- for setting the initial value of the buf-local vars.
  child.cmd("new")
  child.o.columns = 54
  local expected = " NOR  [No Name]       tabs:8  bareline.nvim  00:00/01 "
  eq(child.api.nvim_eval_statusline(child.wo.statusline, {}).str, expected)
end

return T
