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
- Allows picking a different statusline for some windows, with a plain `if`.
- Async. No timer. Autocmds are used to update the statusline immediately as changes happen.

## Out of scope

- Fancy coloring: The colors of the statusline depend on your color scheme.
- Fancy section separators: Items are separated by whitespace.

## Requirements

- Neovim >= 0.12.0

## Installation

Install with your favorite package manager. For example, using Neovim's builtin package manager,
[vim.pack](https://neovim.io/doc/user/pack/#vim.pack):

```lua
vim.pack.add({
  "https://github.com/hernancerm/bareline.nvim",
})
```

Some things to notice:

- `require("bareline").setup()` does **not** need to be called. You may call it to configure the plugin.

## Default config

```lua
local bareline = require("bareline")
bareline.setup({
  statusline = function(ctx)
    if bareline.is_plugin_win() then
      return bareline.statuslines.plugin(ctx)
    end
    local item, text, s, each = bareline.item, bareline.text, bareline.space, bareline.each
    return {
      s(1),
      item("vim_mode", { inactive = "hide" }),
      s(1),
      "%<",
      each({ pad = true }, {
        item("filepath"),
        item("lsp_servers"),
        item("mhr"),
      }),
      "%=",
      each({ pad = true }, {
        item("diagnostics"),
        item("end_of_line"),
        item("indent_style"),
        text(vim.b.gitsigns_head, { wrap = { "(", ")" }, inactive = "remove" }),
        item("cwd"),
      }),
      s(1),
      "%02l:%02c/%02L",
      s(1),
    }
  end,
  items = {
    mhr = {
      display_modified = true,
    },
  },
})
```

## Documentation

Please refer to the help file: [bareline.txt](./doc/bareline.txt) (`:help bareline.txt`).

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
