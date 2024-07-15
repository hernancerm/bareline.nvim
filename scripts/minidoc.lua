---@diagnostic disable: undefined-field, undefined-global

-- See: https://github.com/echasnovski/mini.nvim/blob/main/scripts/minidoc.lua

local minidoc = require("mini.doc")
if _G.MiniDoc == nil then minidoc.setup() end

local hooks = vim.deepcopy(MiniDoc.default_hooks)

hooks.write_pre = function(lines)
  -- Remove first two lines with `====` and `----` delimiters.
  table.remove(lines, 1)
  table.remove(lines, 1)
  return lines
end

minidoc.generate(
  { "lua/bareline.lua" },
  "doc/bareline.txt",
  { hooks = hooks }
)
