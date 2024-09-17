# Developing Bareline

## Vim help file

- The Vim help file [bareline.txt](./doc/bareline.txt) is generated from the plugin file
  [bareline.lua](./lua/bareline.lua) through
  [mini.doc](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-doc.md), using the EX
  command `lua MiniDoc.generate()`. This uses the configuration in
  [minidoc.lua](./scripts/minidoc.lua).
- Recommended format options to facilitate proper hard wrapping:
```lua
-- Set default formatting options.
vim.o.formatoptions = "tcqjrn"
-- Improve pattern recognition for lists.
vim.o.formatlistpat = [[^\s*\d\+[\]:.)}\t ]\s*\|\s*[-*•]\s*]]
```
- Throughout [bareline.lua](./lua/bareline.lua), comments beginning with `DOCS:` indicate something
  important to convey on user-facing documentation. When modifying sections close to these comments,
  honor them.

## Tests

- Tests are run with the EX command `lua MiniTest.run()` through
  [mini.test](https://github.com/echasnovski/mini.test).
- To run all the tests you may run from a shell `make` or `make test`. You need [GNU
  Make](https://www.gnu.org/software/make/).
- Tests should be kept as black-box as possible.

## Tips

- The entire plugin is in the single file [bareline.lua](./lua/bareline.lua). This is so the Vim
  help file is simpler to generate. To navigate the file, consider populating the location list
  using the below EX command. This works since each part of the code is separated by comments with
  all caps, e.g., `-- COMPONENTS`.

```
lgrep '^-- [A-Z:\s]+$' %
```
