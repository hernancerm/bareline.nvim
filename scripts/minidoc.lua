---@diagnostic disable: undefined-field, undefined-global

-- See: https://github.com/echasnovski/mini.nvim/blob/main/scripts/minidoc.lua

local minidoc = require("mini.doc")
if _G.MiniDoc == nil then minidoc.setup() end

local hooks = vim.deepcopy(MiniDoc.default_hooks)

hooks.write_pre = function(lines)
  -- Remove top `====` delimiter.
  table.remove(lines, 1)

  -- Remove auto-added `----` delimiters.
  lines = vim.tbl_filter(function(line)
    if string.find(line, "^[-]+$") then return false end
    return true
  end, lines)

  -- Process:
  -- - `#delimiter`: Draw a simple section delimiter.
  -- - `#tag`: Add a |tag|, these are the right-aligned words.
  lines = vim.tbl_map(function(line)
    if string.find(line, "^#delimiter$") then
      return string.rep("-", 78)
    end
    if string.find(line, "^#tag [%w%d._]+$") then
      return string.format("%80s", "*" .. vim.fn.split(line, " ")[2] .. "*")
    end
    return line
  end, lines)

  -- If code block has no language, set Lua.
  lines = vim.tbl_map(function(line)
    if string.find(line, "^>$") then
      return ">lua"
    end
    return line
  end, lines)

  -- Use pretty UTF-8 bullet char for asterisk lists.
  lines = vim.tbl_map(function(line)
    if string.find(line, "^[%s%W]*[*] %S+") then
      local pretty_line, _ = line:gsub("*", "•")
      return pretty_line
    end
    return line
  end, lines)

  -- Remove some empty lines.
  for index, line in ipairs(lines) do
    -- Remove immediate empty lines padding code blocks.
    if string.find(line, "^>[a-z]+$") and lines[index + 1] == "" then
      table.remove(lines, index + 1)
    end
    if string.find(line, "^<$") and lines[index - 1] == "" then
      table.remove(lines, index - 1)
    end
    -- Remove immediate empty line after delimiter.
    if string.find(line, "^[-]+$") and lines[index + 1] == "" then
      table.remove(lines, index + 1)
    end
  end

  -- Process:
  -- - `#end` Allows to end the documentation before reaching the end of the
  --   document. This is useful to exclude helpers.
  for index, line in ipairs(lines) do
    if string.find(line, "^#end$") then
      lines = vim.list_slice(lines, 0, index - 1)
      table.insert(lines, " vim:tw=78:ts=8:noet:ft=help:norl:")
    end
  end

  return lines
end

minidoc.generate(
  { "lua/bareline.lua" },
  "doc/bareline.txt",
  { hooks = hooks }
)
