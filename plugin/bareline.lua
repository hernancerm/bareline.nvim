-- Set up with the default config, unless the user calls setup() themselves. Deferred since
-- lazy.nvim sources this file right before calling the user's setup(), so running it now would do
-- the upfront work of setup() twice.
vim.schedule(function()
  local bareline = require("bareline")
  if bareline.config == nil then
    bareline.setup()
  end
end)
