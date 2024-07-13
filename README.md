# bareline.nvim

Library to facilitate building simple statuslines.

## Features

- Preset statusline for a batteries included experience.
- Basic data providers and components for building your own statusline.
- Simple.

Not implemented:

- Colors. The colors depend on your color scheme.
- Mouse events.

## Installation

Use your favorite package manager. For example, [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
 {
   "HerCerM/bareline.nvim",
    -- Use the batteries included statusline:
    config = function () require("bareline").presets.bare() end
 }
```

## Usage

Bareline comes with a preset to start using a pre-configured statusline right away. When using this preset as per the snippet below, the information shown in the statusline is different according to the window state.

```lua
require("bareline").presets.bare()
```

<table>
  <tr>
    <th>Window state</th>
    <th>Demo</th>
  </tr>
  <tr>
    <td>Active</td>
    <td><img src="./media/bare_active.png" alt="Active statusline"></th>
  </tr>
  <tr>
    <td>Inactive</td>
    <td><img src="./media/bare_inactive.png" alt="Active statusline"></th>
  </tr>
  <tr>
    <td>Plugin</td>
    <td><img src="./media/bare_plugin.png" alt="Active statusline"></th>
  </tr>
</table>

To change the information the preset displays, use the code below as a template. If the template below is used, then there is no need to call `require("bareline").presets.bare()`.

```lua
local bareline = require("bareline")

vim.o.showmode = false
bareline.draw_methods.draw_active_inactive_plugin {
  -- Active.
  {
    {
      bareline.components.vim_mode,
      bareline.providers.get_file_path_relative_to_cwd,
      "%m",
      "%h",
      "%r",
    },
    {
      bareline.components.diagnostics,
      vim.bo.fileformat,
      bareline.components.indent_style,
      bareline.components.end_of_line,
      bareline.components.git_branch,
      bareline.components.position,
    },
  },
  -- Inactive.
  {
    {
      {
        value = bareline.components.vim_mode.value,
        opts = {
          format = bareline.formatters.mask(
              bareline.components.vim_mode.opts.format, " ")
        },
      },
      bareline.providers.get_file_path_relative_to_cwd,
      "%m",
      "%h",
      "%r",
    },
    {
      bareline.components.diagnostics,
      vim.bo.fileformat,
      bareline.components.indent_style,
      bareline.components.end_of_line,
      bareline.components.position,
    },
  },
  -- Plugin.
  {
    { bareline.components.plugin_name },
    { bareline.components.position },
  },
}
```

To learn more, please read the help page [bareline.txt](./doc/bareline.txt). I put effort on writing that, hopefully it's understandable.

## Similar plugins

- [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim)
- [mini.statusline](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-statusline.md)
- [express_line.nvim](https://github.com/tjdevries/express_line.nvim)
- [vim-airline](https://github.com/vim-airline/vim-airline)
- [lightline.vim](https://github.com/itchyny/lightline.vim)
- [staline.nvim](https://github.com/tamton-aquib/staline.nvim)

## Why yet another statusline plugin?

> In the Steven Spielberg movie "E.T.," why is the alien brown? No reason. In "Love Story," why do the two characters fall madly in love with each other? No reason. In Oliver Stone's "JFK," why is the President suddenly assassinated by some stranger? No reason. In the excellent "Chain Saw Massacre" by Tobe Hooper, why don't we ever see the characters go to the bathroom or wash their hands like people do in real life? Absolutely no reason. Worse, in "The Pianist" by Polanski, how come this guy has to hide and live like a bum when he plays the piano so well? Once again the answer is, no reason. I could go on for hours with more examples. The list is endless. — Rubber (2010).

No reason.
