-- Intended use cases of this file:
-- - `make docs`: For headless Neovim instance to generate Vim help file(s).

-- Set up for headless Neovim. Intended for `make docs`.
-- Why `nvim_list_uis` condition: Headless Neovim instances (like the one spawned with `make`) use
-- the plugins from the `deps` dir, while non-headless Neovim instances (like when user uses Neovim
-- as usual) do not have access to the plugins in the `deps` dir.
if #vim.api.nvim_list_uis() == 0 then
  vim.cmd([[let &rtp.=",".getcwd()."/deps/mini.doc"]])
  local mini_doc = require("mini.doc")
  mini_doc.setup()
  -- Generate help file(s).
  -- This generation depends on `./scripts/minidoc.lua`.
  mini_doc.generate()
  vim.cmd("qall!")
end
