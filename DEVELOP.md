# Developing Bareline

In case you are already using [Lazy.nvim](https://github.com/folke/lazy.nvim), you can install your
local clone of the plugin as below:

```lua
{
  dir = "/path/to/bareline.nvim",
  opts = {}
},
```

## Versioning

<https://semver.org/>

## Releasing

Follow these manual steps:

1. Tag the commit in the `main` branch with the semver version.
2. Create a GitHub release from the tag.

## Vim help file

- Generate the Vim help file with `make docs`. GNU Make downloads mini.doc so you don't have to.
- The Vim help file [bareline.txt](./doc/bareline.txt) is generated from
  [bareline.lua](./lua/bareline.lua) through
  [mini.doc](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-doc.md) (configuration
  in [minidoc.lua](./scripts/minidoc.lua)).
- Recommended format options to facilitate proper hard wrapping:

```lua
-- Set default formatting options.
vim.o.formatoptions = "tcqjrn"
-- Improve pattern recognition for lists.
vim.o.formatlistpat = [[^\s*\d\+[\]:.)}\t ]\s*\|^\s*[-*•]\s*]]
```

## Tests

Your Neovim must have [mini.test](https://github.com/echasnovski/mini.test) installed to use:

- Nvim ex cmd to run a unit test at the cursor location: `lua MiniTest.run_at_location()`.

Only [GNU Make](https://www.gnu.org/software/make/) required for:

- Shell cmd to run all unit tests: `make test`.
- Shell cmd to run all CI checks: `make testci`.
