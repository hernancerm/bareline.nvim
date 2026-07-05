<a href="https://github.com/hernancerm/bareline.nvim/actions/workflows/ci.yml" target="_blank">
  <img src="https://github.com/hernancerm/bareline.nvim/actions/workflows/ci.yml/badge.svg" />
</a>

# Bareline

A statusline plugin for the pragmatic.

<table>
  <tr>
    <th>Window state</th>
    <th>Appearance</th>
  </tr>
  <tr>
    <td>Active</td>
    <td><img src="./media/demo_active.png" alt="Active statusline"></td>
  </tr>
  <tr>
    <td>Inactive</td>
    <td><img src="./media/demo_inactive.png" alt="Inactive statusline"></td>
  </tr>
  <tr>
    <td>Plugin</td>
    <td><img src="./media/demo_plugin.png" alt="Plugin statusline"></td>
  </tr>
</table>

<div align=center>
  <p>
    <a href="#default-config">Default config</a>. Color scheme (Neovim built-in): <a
    href="https://github.com/vim/colorschemes/blob/master/colors/lunaperche.vim">lunaperche</a>
  </p>
</div>

## Features

- Sensible defaults.
- Simple configuration.
- Support for global statusline (`laststatus=3`).
- Bundled statusline items for common use cases.
- Allows defining a variation of the statusline for inactive windows.
- Allows defining alternative statuslines for buffers matching a criteria.
- Async. No timer. Autocmds are used to update the statusline immediately as changes happen.

## Out of scope

- Fancy coloring: The colors of the statusline depend on your color scheme.
- Fancy section separators: Items are separated by whitespace.

## Requirements

- Neovim >= 0.11.0

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
local bareline = require("bareline")
bareline.setup()
```

Is equivalent to:

```lua
local bareline = require("bareline")
bareline.setup({
  statusline = {
    value = "%{BlIs(1)}"
      .. "%{BlInahide(get(b:,'bl_vim_mode',''))}"
      .. "%{BlIs(1)}"
      .. "%<"
      .. "%{BlPad(get(b:,'bl_filepath',''))}"
      .. "%{BlPad(get(b:,'bl_lsp_servers',''))}"
      .. "%{%BlPad(get(b:,'bl_mhr',''))%}"
      .. "%="
      .. "%{BlPad(get(b:,'bl_diagnostics',''))}"
      .. "%{BlPad(get(b:,'bl_end_of_line',''))}"
      .. "%{BlPad(get(b:,'bl_indent_style',''))}"
      .. "%{BlInarm(BlPad(BlWrap(get(b:,'gitsigns_head',''),'(',')')))}"
      .. "%{BlPad(get(b:,'bl_current_working_dir',''))}"
      .. "%{BlIs(1)}"
      .. "%02l:%02c/%02L"
      .. "%{BlIs(1)}",
    items = {
      bareline.items.vim_mode,
      bareline.items.filepath,
      bareline.items.lsp_servers,
      bareline.items.mhr,
      bareline.items.diagnostics,
      bareline.items.end_of_line,
      bareline.items.indent_style,
      bareline.items.current_working_dir,
    },
  },
  alt_statuslines = {
    bareline.alt_statuslines.plugin,
  },
  items = {
    mhr = {
      display_modified = true,
    },
  },
  logging = {
    enabled = false,
    level = vim.log.levels.INFO,
  },
})
```

## Documentation

Please refer to the help file: [bareline.txt](./doc/bareline.txt).

## Similar plugins

- [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim)
- [express_line.nvim](https://github.com/tjdevries/express_line.nvim)
- [mini.statusline](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-statusline.md)
- [staline.nvim](https://github.com/tamton-aquib/staline.nvim)

Why another statusline plugin?

> I know people like to meme about how vim enthusiasts are always trying to convince people to learn
> vim keybindings but I truly believe that learning it will not only make you faster but also
> rekindle your love for programming, it did for me. — Nexxel (2023).

The latter.

## Contributing

I welcome issues requesting any behavior change. However, please do not submit a PR unless it's for
a trivial fix.

## License

[MIT](./LICENSE)
