<div align=center>
  <a href="https://github.com/hernancerm/bareline.nvim/actions/workflows/ci.yml" target="_blank">
    <img src="https://github.com/hernancerm/bareline.nvim/actions/workflows/ci.yml/badge.svg" />
  </a>
  <h1>Bareline</h1>
  <p>A statusline plugin for the pragmatic.</p>
  <p>
    Do you want a statusline that looks like the default one but can show more info, is async and
    easy to configure? <br> Then this plugins is for you.
  </p>
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
  <p>
    <a href="#default-config">Default config</a>. Color scheme (Neovim built-in):
    <a href="https://github.com/vim/colorschemes/blob/master/colors/lunaperche.vim">lunaperche</a>
  </p>
</div>

## Features

- No timer. Autocmds and file watchers are used to update the statusline immediately as changes
  happen.
- Sensible defaults.
- Simple configuration.
- Built-in statusline components.
- Support for global statusline (`laststatus=3`).

## Out of scope

- Fancy coloring: Currently the colors of the statusline depend on your color scheme.
- Fancy section separators: Currently components are separated by whitespace.

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
  statuslines = {
    -- Active window.
    active = {
      { -- Section 1: Left.
        bareline.components.vim_mode,
        bareline.components.filepath_relative_to_cwd,
        bareline.components.lsp_servers,
        bareline.components.mhr,
      },
      { -- Section 2: Right.
        bareline.components.diagnostics,
        bareline.components.end_of_line,
        bareline.components.indent_style,
        bareline.components.git_head,
        bareline.components.cwd,
        bareline.components.position,
      },
    },
    -- Inactive windows.
    inactive = {
      { -- Section 1: Left.
        bareline.components.vim_mode:config({ mask = " " }),
        bareline.components.filepath_relative_to_cwd,
        bareline.components.lsp_servers,
        bareline.components.mhr,
      },
      { -- Section 2: Right.
        bareline.components.diagnostics,
        bareline.components.end_of_line,
        bareline.components.indent_style,
        bareline.components.cwd,
        bareline.components.position,
      },
    },
    -- Plugin windows.
    plugin = {
      { -- Section 1: Left.
        bareline.components.plugin_name,
        bareline.components.mhr,
      },
      { -- Section 2: Right.
        bareline.components.position,
      },
    },
  },
  components = {
    git_head = {
      worktrees = {},
    },
    mhr = {
      display_modified = true,
    },
  },
  logging = {
    enabled = false,
    level = vim.log.levels.DEBUG,
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

Feel free to open an issue requesting any behavior change (e.g., bug fix, new feature), I'm happy to
discuss proposals. If I think the functionality fits well in the plugin, I might implement it.
Please do not submit a pull-request unless it's for a trivial bug fix.

## License

[MIT](./LICENSE)
