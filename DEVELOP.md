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

- Generate the Vim help file with `make docs`.
- The Vim help file [bareline.txt](./doc/bareline.txt) is generated from
  [bareline.lua](./lua/bareline.lua) through
  [mini.doc](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-doc.md) (configuration
  in [minidoc.lua](./scripts/minidoc.lua)).
- Recommended format options to facilitate proper hard wrapping:

  ```lua
  -- Set default formatting options.
  vim.o.formatoptions = "tcqjrn"
  -- Improve pattern recognition for lists.
  vim.o.formatlistpat = [[^\s*\d\+[\]:.)}\t ]\s*\|\s*[-*•]\s*]]
  ```
- Throughout [bareline.lua](./lua/bareline.lua), comments beginning with `DOCS:` indicate something
  important to convey on documentation. When modifying sections close to these comments, honor them.

## Tests

- To run the unit test at the cursor location: `:lua MiniTest.run_at_location()`. You need to have
  installed: [mini.test](https://github.com/echasnovski/mini.test).
- To run all unit tests: `make test`.
- To run all CI checks: `make testci`.
- Tests should be kept as black-box as possible.
