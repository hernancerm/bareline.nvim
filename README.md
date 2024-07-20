# bareline.nvim

Configure your statusline with ease.

## Features

- Simple configuration.
- Batteries included experience.
- Data providers to use this plugin as a library, if you so wish.

## Requirements

- Works on Neovim 0.10.0. Not tested on other versions.

## Installation

Use your favorite package manager. For example, [Lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "hernancerm/bareline.nvim"
},
```

The function `require("barelilne").setup({config})` needs to be called for the default statusline to
be drawn. Lazy.nvim does this automatically using the snippet above.

## Default config

Bareline comes with sensible defaults to provide a batteries included experience. Demo:

<table>
  <tr>
    <th>Window state</th>
    <th>Appearance</th>
  </tr>
  <tr>
    <td>Active</td>
    <td><img src="./media/demo_active.png" alt="Active statusline"></th>
  </tr>
  <tr>
    <td>Inactive</td>
    <td><img src="./media/demo_inactive.png" alt="Inactive statusline"></th>
  </tr>
  <tr>
    <td>Plugin</td>
    <td><img src="./media/demo_plugin.png" alt="Plugin statusline"></th>
  </tr>
</table>

Defaults config table:

```lua
{
  -- Function which takes a single argument, the `statusline` table. Based
  -- on the draw method, `statusline` might need to contain more than one
  -- statusline definition. With the default, 3 statuslines are expected.
  draw_method = bareline.draw_methods.draw_active_inactive_plugin,

  statusline = {
    { -- Statusline 1: Active window.
      { -- Section 1: Left.
        bareline.components.vim_mode,
        bareline.components.get_file_path_relative_to_cwd,
        bareline.components.lsp_servers,
        "%m", "%h", "%r",
      },
      { -- Section 2: Right.
        bareline.components.diagnostics,
        bareline.components.indent_style,
        bareline.components.end_of_line,
        bareline.components.git_branch,
        bareline.components.position,
      },
    },

    { -- Statusline 2: Inactive window.
      { -- Section 1: Left.
        bareline.components.vim_mode:mask(" "),
        bareline.components.get_file_path_relative_to_cwd,
        bareline.components.lsp_servers,
        "%m", "%h", "%r",
      },
      { -- Section 2: Right.
        bareline.components.diagnostics,
        bareline.components.indent_style,
        bareline.components.end_of_line,
        bareline.components.position,
      },
    },

    { -- Statusline 3: Plugin window.
      { -- Section 1: Left.
        bareline.components.plugin_name
      },
      { -- Section 2: Right.
        bareline.components.position
      },
    },
  }
}
```

## Overriding the defaults

Copy/paste the default config table ([Default config](#default-config)) or modify a deep copy of it,
and pass that to `require("bareline").setup({config})`. Example of the latter approach:

```lua
local bareline = require("bareline")
-- Custom component.
local component_prose_mode = function ()
  if string.find(vim.bo.formatoptions, "a") then return "PROSE" end
  return nil
end
-- Overrides to default config.
local config = vim.deepcopy(bareline.default_config)
table.insert(config.statusline[1][1], 2, component_prose_mode)
table.insert(config.statusline[2][1], 2, component_prose_mode)
-- Draw statusline.
bareline.setup(config)
```

## Complete documentation

Please refer to the help file: [bareline.txt](./doc/bareline.txt).

## Similar plugins

- [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim)
- [mini.statusline](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-statusline.md)
- [express_line.nvim](https://github.com/tjdevries/express_line.nvim)
- [vim-airline](https://github.com/vim-airline/vim-airline)
- [lightline.vim](https://github.com/itchyny/lightline.vim)
- [staline.nvim](https://github.com/tamton-aquib/staline.nvim)

## Why yet another statusline plugin?

> In the Steven Spielberg movie "E.T.," why is the alien brown? No reason. In "Love Story," why do
> the two characters fall madly in love with each other? No reason. In Oliver Stone's "JFK," why is
> the President suddenly assassinated by some stranger? No reason. In the excellent "Chain Saw
> Massacre" by Tobe Hooper, why don't we ever see the characters go to the bathroom or wash their
> hands like people do in real life? Absolutely no reason. Worse, in "The Pianist" by Polanski, how
> come this guy has to hide and live like a bum when he plays the piano so well? Once again the
> answer is, no reason. I could go on for hours with more examples. The list is endless. — Rubber
> (2010).

No reason.

## License

[MIT](./LICENSE)

> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. [...]
