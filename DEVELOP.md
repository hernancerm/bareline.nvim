# Development of bareline.nvim

## Writing the Vim help file

The Vim help file [bareline.txt](./doc/bareline.txt) is generated from the plugin file
[bareline.lua](./lua/bareline.lua) using
[mini.doc](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-doc.md). Ensure you have
installed mini.doc in your Neovim, then execute the following in the bareline project:

```
:lua MiniDoc.generate()
```

This uses the configuration in [minidoc.lua](./scripts/minidoc.lua) to generate the help file.

Recommended format options to facilitate proper hard wrapping:

```lua
-- Set default formatting options.
vim.o.formatoptions = "tcqjrn"
-- Improve pattern recognition for lists.
vim.o.formatlistpat = [[^\s*\d\+[\]:.)}\t ]\s*\|\s*[-*•]\s*]]
```

## Navigating bareline.lua

The entire plugin is in the single file [bareline.lua](./lua/bareline.lua). This is so the help file
is simpler to generate. To navigate the file, consider populating the location list using this
command:

```
:lgrep '^-- [A-Z:\s]+$' %
```

Each part of the code is separated by comments with all caps, e.g., `-- COMPONENTS`.

## Code conventions

Lua:
- Every identifier is named in snake_case, except classes which use PascalCase.
- The identifier `h` holds helper functions and values, not meant to be made public.
