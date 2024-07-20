--- *bareline* Configure simple statuslines.
--- *Bareline*
---
--- MIT License Copyright (c) 2024 Hernán Cervera.
---
--- ==============================================================================
---
--- Key design ideas ~
---
--- 1. Simplicity, for the user and in the code.
---
--- 2. Can be used as a library for common statusline data providers, in case the
---   user wants to set their statusline in a more custom way.
---
--- Concepts ~
---
--- Bareline conceptualizes a statusline in this way:
--- * A statusline is a list of sections.
--- * Each section is a list of components (|Bareline.components|).
---
--- Visualized example:
---
--- Statusline: | NOR  lua/bareline.lua                        (main)  22,74/454 |
---               Section 1                                    Section 2
---               └── Components                               └── Components
---                   ├── Vim mode                                 ├── Git HEAD
---                   └── Relative file path                       └── Location
---
--- Each component gets its data from a provider (|Bareline.providers|).

-- MODULE CONFIG

local Bareline = {}
local H = require("helpers")

--- #delimiter

--- Module setup.
---
--- To leverage the plugin to build and draw a statusline, you need to call the
--- setup function and optionally provide your configuration:
--- >lua
---   local Bareline = require("bareline")
---   Bareline.setup() -- Or provide a table as an argument for the config.
--- <
--- I recommend disabling 'showmode', so only Bareline shows the Vim mode.
---
--- If you want to use this plugin just for the data providers (e.g., Vim mode or
--- Git branch) to build yourself a statusine which fancies your pixelated heart,
--- then take a look at |Bareline.providers|.
---
---@param config table|nil Module config table. |Bareline.config| defines the
--- default configuration. If config is nil, then the default config is used. If a
--- config table is provided, it's merged with the default config and the keys in
--- the user's config take precedence.
function Bareline.setup(config)
  Bareline.config = H.get_config_with_fallback(config, Bareline.config)
  Bareline.config.draw_method(Bareline.config.statusline)
end

--- #delimiter
--- #tag Bareline.config

--- The default configuration uses distinct statuslines for active, inactive and
--- plugin windows. The resulting style is inspired by Helix's default statusline:
---
--- Active window:
--- * | NOR  lua/bareline.lua  [lua_ls]      H:2,W:4  spaces-2  (main)  42,21/50 |
--- Inactive window:
--- * |      lua/bareline.lua  [lua_ls]              H:2,W:4  spaces-2  42,21/50 |
--- Plugin window:
--- * | [Nvim Tree]                                                     28,09/33 |
---                      https://github.com/helix-editor/helix
---
---
--- Bareline's default configuration below. No need to copy/paste this in your
--- config, unless you want to use it as a starting point for your own tweaks.

---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
--minidoc_replace_start
local function apply_default_config()
--minidoc_replace_end
  Bareline.config = {
    draw_method = Bareline.draw_methods.draw_active_inactive_plugin,
    statusline = {
      -- Active.
      {
        {
          Bareline.components.vim_mode,
          Bareline.components.get_file_path_relative_to_cwd,
          Bareline.components.lsp_servers,
          "%m", "%h", "%r",
        },
        {
          Bareline.components.diagnostics,
          Bareline.components.indent_style,
          Bareline.components.end_of_line,
          Bareline.components.git_branch,
          Bareline.components.position,
        },
      },
      -- Inactive.
      {
        {
          Bareline.components.vim_mode:mask(" "),
          Bareline.components.get_file_path_relative_to_cwd,
          Bareline.components.lsp_servers,
          "%m", "%h", "%r",
        },
        {
          Bareline.components.diagnostics,
          Bareline.components.indent_style,
          Bareline.components.end_of_line,
          Bareline.components.position,
        },
      },
      -- Plugin.
      {
        { Bareline.components.plugin_name },
        { Bareline.components.position },
      },
    }
  }
--minidoc_replace_start
end
--minidoc_replace_end
--minidoc_afterlines_end

-- PROVIDERS

Bareline.providers = {}

--- #delimiter
--- #tag Bareline.providers

--- If you want to use the providers directly, most likely you do not want to use
--- the setup function (|Bareline.setup|). Providers give data in a parse-friendly
--- format, which can be used so you build your own statusline without using any
--- other functionality provided in Bareline. Example:
--- >lua
---   local providers = require("bareline").providers
---   providers.lsp_server_names()
---   -- Returns: `{ "lua_ls" }`
--- <

--- Vim mode.
--- Returns the first char of the current Vim mode (see |mode()|). For block
--- modes, two characters are returned, a "b" followed by the mode; currently,
--- only `bv` for "block visual mode" and `bs` for "block select mode". The
--- returned string has only lower case letters.
---@return string
function Bareline.providers.get_vim_mode()
  local function standardize_mode(character)
    if character == "" then return "bv" end
    if character == "" then return "bs" end
    return character:lower()
  end
  return standardize_mode(vim.fn.mode())
end

--- Git HEAD.
--- Returns the Git HEAD. The file `.git/HEAD` is read and its first line is
--- returned. If the current directory does not have a `.git` dir, an upwards
--- search is performed. If the dir isn't found, then nil is returned.
---@return string|nil
function Bareline.providers.get_git_head()
  local git_dir = vim.fn.finddir(".git", ".;")
  return (git_dir ~= "" and vim.fn.readfile(git_dir .. "/HEAD")[1]) or nil
end

--- LSP attached servers.
--- Returns the names of the LSP servers attached to the current buffer.
--- Example output: `{ "luals" }`
---@return table
function Bareline.providers.lsp_server_names()
  return vim.tbl_map(
    function (client)
      return client.name
    end,
    vim.lsp.get_clients({ bufnr = 0 })
  )
end

--- Diagnostics.
--- Returns the diagnostics count of the current buffer by severity, where a lower
--- index is a higher severity. Use numeric indices or the the keys in
--- |vim.diagnostic.severity| to get the diagnostic count per severity.
--- Example output: `{ 4, 1, 0, 1 }`
---@return table|nil
-- ---@usage [[
-- ---local bareline = require("bareline")
-- ---local errors = bareline.components.providers.get_diagnostics()[1]
-- ---print(errors) -- Output: 4
-- ---@usage ]]
function Bareline.providers.get_diagnostics()
  if vim.fn.empty(vim.diagnostic.get(0)) == 1 then return nil end
  local diagnostics_per_severity = { 0, 0, 0, 0 }
  for _, diagnostic in ipairs(vim.diagnostic.get(0)) do
    diagnostics_per_severity[diagnostic.severity] =
        diagnostics_per_severity[diagnostic.severity] + 1
  end
  return diagnostics_per_severity
end

--- Stable `%f`.
--- Returns the file path of the current buffer relative to the current working
--- directory (|:pwd|). If the file opened is not in this dir, then the absolute
--- path is returned. This is meant to be used instead of the field `%f` (see
--- 'statusline') for a more consistent experience.
---@return string
function Bareline.providers.get_file_path_relative_to_cwd()
  local buf_name = vim.api.nvim_buf_get_name(0)
  if buf_name == "" or vim.bo.filetype == "help" then return "%f" end
  local replacement, _ = string.gsub(
      vim.api.nvim_buf_get_name(0),
      H.escape_lua_pattern(vim.fn.getcwd()) .. "/",
      "")
  return replacement
end

-- COMPONENTS

--- #delimiter
--- #tag Bareline.components

Bareline.components = {}

--- Standard component. All |bareline.components| are structured like this.
---@class BareComponent
---@field provider function|string|nil As a function, return string|nil.
---@field mask function Mask the component value with a char.
---@field opts BareComponentOpts|nil
Bareline.BareComponent = {}
Bareline.BareComponent["__index"] = Bareline.BareComponent

function Bareline.BareComponent:new(provider, opts)
  local bare_component = {}
  setmetatable(bare_component, self)
  bare_component.provider = provider
  bare_component.opts = opts
  return bare_component
end

function Bareline.BareComponent:mask(char)
  local this = self
  return function()
    local component_value = H.build_user_supplied_component(this)
    if component_value == nil then return nil end
    return component_value:gsub(".", char)
  end
end

--- The Vim mode in 3 characters.
--- Mockups: `NOR`, `VIS`
---@type BareComponent
Bareline.components.vim_mode = Bareline.BareComponent:new(
  Bareline.providers.get_vim_mode,
  {
    format = function (vim_mode)
      local mode_labels = {
        n = "nor", i = "ins", v = "vis", s = "sel",
        t = "ter", c = "cmd", r = "rep", bv = "vis",
        bs = "sel", ["!"] = "ext",
      }
      return mode_labels[vim_mode]:upper()
    end
  }
)

--- When on a plugin window, the formatted name of the plugin window.
--- Mockup: `[Nvim Tree]`
---@type BareComponent
Bareline.components.plugin_name = Bareline.BareComponent:new(
  function() return vim.bo.filetype end,
  {
    format = function(file_type)
      local plugin_file_type = {
        nvimtree = "Nvim Tree",
      }
      if plugin_file_type[file_type:lower()] then
        return string.format("[%s]", plugin_file_type[file_type:lower()])
      end
      return nil
    end
  }
)

--- The indent style on insert mode. Relies on 'expandtab' and 'tabstop'.
--- Mockups: `spaces-2`, `tabs-4`
---@type BareComponent
Bareline.components.indent_style = Bareline.BareComponent:new(
  function()
    local whitespace_type = "tabs"
    if vim.bo.expandtab then whitespace_type = "spaces" end
    return whitespace_type .. "-" .. vim.bo.tabstop
  end
)

--- Indicate when the file does not have an end of line (EOL) on its last line.
--- Return `noeol` in this case, nil otherwise. This uses the option 'eol'.
---@type BareComponent
Bareline.components.end_of_line = Bareline.BareComponent:new(
  function()
    if vim.bo.eol then return nil end
    return "noeol"
  end
)

--- The Git HEAD.
--- Mockup: `(main)`
---@type BareComponent
Bareline.components.git_branch = Bareline.BareComponent:new(
  Bareline.providers.get_git_head,
  {
    format = function(git_head)
      if git_head == nil then return nil end
      local function format(head)
        local formatted_head
        if head:match "^ref: " then
          formatted_head = head:gsub("^ref: refs/%w+/", "")
        else
          formatted_head = head:sub(1, 7)
        end
        return formatted_head
      end
      return string.format("(%s)", format(git_head))
    end
  }
)

--- The LSP servers attached to the current buffer.
--- Mockup: `[lua_ls]`
---@type BareComponent
Bareline.components.lsp_servers = Bareline.BareComponent:new(
  Bareline.providers.lsp_server_names,
  {
    format = function(lsp_servers)
      if lsp_servers == nil or vim.tbl_isempty(lsp_servers) then return nil end
      return "[" .. vim.fn.join(lsp_servers, ",") .. "]"
    end
  }
)

--- The file path relative to the current working directory (|:pwd|).
--- Mockup: `lua/bareline.lua`
---@type BareComponent
Bareline.components.get_file_path_relative_to_cwd = Bareline.BareComponent:new(
  Bareline.providers.get_file_path_relative_to_cwd
)

--- The diagnostics of the current buffer.
--- Mockup: `E:2,W:1`
---@type BareComponent
Bareline.components.diagnostics = Bareline.BareComponent:new(
  Bareline.providers.get_diagnostics,
  {
    cache_on_vim_modes = { "i" },
    format = function(diagnostics_per_severity)
      if diagnostics_per_severity == nil then return nil end
      local formatted_diagnostics = ""
      local diagnostics_severity_label = { "E", "W", "I", "H" }
      local separator = ""
      for index, count in ipairs(diagnostics_per_severity) do
        if count > 0 then
          formatted_diagnostics = formatted_diagnostics
            .. string.format(
                "%s%s:%s", separator, diagnostics_severity_label[index], count)
          separator = ","
        end
      end
      return formatted_diagnostics
    end
  }
)

--- The current cursor position in the format: line,column/total-lines.
--- Mockup: `181,43/329`
---@type BareComponent
Bareline.components.position = Bareline.BareComponent:new("%02l,%02c/%02L")

-- DRAW METHODS

--- #delimiter
--- #tag Bareline.draw_methods

Bareline.draw_methods = {}

--- Use distinct statuslines for active, inactive and plugin windows. The provided
--- statuslines are handled in this order by table index: (1) drawn on the active
--- window, (2) drawn on the inactive window and (3) drawn on the plugin window,
--- having precedence over the active window statusline.
---@param statuslines BareStatusline[]
function Bareline.draw_methods.draw_active_inactive_plugin(statuslines)
  ---@type BareStatusline
  local active_window_statusline = statuslines[1]
  ---@type BareStatusline
  local inactive_window_statusline = statuslines[2]
  ---@type BareStatusline
  local plugin_window_statusline = statuslines[3]

  ---@param statusline_1 BareStatusline Statusline for a plugin window.
  ---@param statusline_2 BareStatusline Statusline drawn otherwise.
  local function draw_statusline_if_plugin_window(statusline_1, statusline_2)
    if H.is_plugin_window(vim.fn.bufnr()) then
      H.draw_window_statusline(statusline_1)
    else
      H.draw_window_statusline(statusline_2)
    end
  end

  -- Redraw statusline immediately to update specific components, e.g. the Vim
  -- mode. For plugin windows (e.g. nvim-tree), use a special statusline.
  vim.api.nvim_create_autocmd(
    { "ModeChanged", "DiagnosticChanged", "BufEnter" },
    {
      group = H.draw_methods_augroup,
      callback = function()
        draw_statusline_if_plugin_window(
          plugin_window_statusline,
          active_window_statusline
        )
      end,
    }
  )

  vim.api.nvim_create_autocmd("OptionSet", {
      group = H.draw_methods_augroup,
      pattern = "expandtab,tabstop,endofline,fileformat,formatoptions",
      callback = function()
        draw_statusline_if_plugin_window(
          plugin_window_statusline,
          active_window_statusline
        )
      end,
    }
  )

  -- Redraw statusline of active window to update components hard to watch, for
  -- example the attached LSP servers.
  vim.fn.timer_start(
    500,
    function()
      draw_statusline_if_plugin_window(
        plugin_window_statusline,
        active_window_statusline
      )
    end,
    { ["repeat"] = -1 }
  )

  -- Draw a different statusline for inactive windows. For inactive plugin windows
  -- (e.g. nvim-tree), use a special statusline, the same one as for active plugin
  -- windows.
  vim.api.nvim_create_autocmd("WinLeave", {
    group = H.draw_methods_augroup,
    callback = function()
      draw_statusline_if_plugin_window(
          plugin_window_statusline,
          inactive_window_statusline
        )
    end,
  })

  H.draw_window_statusline(active_window_statusline)
end

-- Set module default config.
apply_default_config()

return Bareline
