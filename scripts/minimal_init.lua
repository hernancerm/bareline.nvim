-- See: <https://github.com/echasnovski/mini.nvim/blob/main/TESTING.md>.

-- Add current directory to 'runtimepath' to be able to use 'lua' files.
vim.cmd([[let &rtp.=",".getcwd()]])

-- Set up `mini.test` only when calling headless Neovim (like with `make test`).
if #vim.api.nvim_list_uis() == 0 then
  -- Add `deps` dir to 'runtimepath' to be able to use `test.lua`.
  vim.cmd([[let &rtp.=",".getcwd()."/deps"]])
  -- Set up `mini.test`.
  require("test").setup()
end
