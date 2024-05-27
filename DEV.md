# Development of bareline.nvim

## Writing the Vim help file

[bareline.txt](./doc/bareline.txt) is generated from EmmyLua comments in the Lua plugin file using
the CLI tool [lemmy-help](https://github.com/numToStr/lemmy-help). When writing the docs, consider
that Vim help files have a `'textwidth'` of 78. To have the text fit well, try to use these values
when doing hard wrapping with `gw` or `gq`: `@brief`: 81; function comment: 77; `@param`: <77.
