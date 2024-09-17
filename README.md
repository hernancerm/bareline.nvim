[![CI](https://github.com/hernancerm/bareline.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/hernancerm/bareline.nvim/actions/workflows/ci.yml)

# Bareline

Yet another statusline plugin.

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

<div align=center>
  <p>
    Demo of <a href="#default-config">default config</a>. Color scheme (built-in):
    <a href="https://github.com/vim/colorschemes/blob/master/colors/lunaperche.vim">
      lunaperche
    </a>
  </p>
</div>

## Features

- Simple configuration.
- Batteries included experience.
- No timer. Update immediately as changes happen.

## Limitations

- No fancy colors. The colors of the entire statusline itself depend on your color scheme.
- No fancy separators. Components are separated by whitespace.

## Requirements

- Works on Neovim 0.10.1. Not tested on other versions.

## Installation

Use your favorite package manager. For example, [Lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "hernancerm/bareline.nvim",
  opts = {}
},
```

The function `require("barelilne").setup()` needs to be called for Bareline to draw the statusline.
Lazy.nvim does this automatically using the snippet above.

## Default config

```lua
{
  statuslines = {
    -- Active window.
    active = {
      { -- Section 1: Left.
        bareline.components.vim_mode,
        bareline.components.file_path_relative_to_cwd,
        bareline.components.lsp_servers,
        "%m", "%h", "%r",
      },
      { -- Section 2: Right.
        bareline.components.diagnostics,
        bareline.components.indent_style,
        bareline.components.end_of_line,
        bareline.components.git_head,
        bareline.components.position,
      },
    },
    -- Inactive windows.
    inactive = {
      { -- Section 1: Left.
        bareline.components.vim_mode:mask(" "),
        bareline.components.file_path_relative_to_cwd,
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
    -- Plugin windows.
    plugin = {
      { -- Section 1: Left.
        bareline.components.plugin_name,
        "%m"
      },
      { -- Section 2: Right.
        bareline.components.position
      },
    },
  }
}
```

## Documentation

Please refer to the help file: [bareline.txt](./doc/bareline.txt).

## Similar plugins

- [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim)
- [express_line.nvim](https://github.com/tjdevries/express_line.nvim)
- [mini.statusline](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-statusline.md)
- [staline.nvim](https://github.com/tamton-aquib/staline.nvim)

## Why another plugin?

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
