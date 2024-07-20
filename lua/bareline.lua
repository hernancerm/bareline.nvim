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

-- MODULE SETUP

local bareline = {}
local h = {}

--- #delimiter

--- Module setup.
---
--- To leverage the plugin to build and draw a statusline, you need to call the
--- setup function and optionally provide your configuration:
--- >lua
---   local bareline = require("bareline")
---   bareline.setup({}) -- Or provide a table as an argument for the config.
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
function bareline.setup(config)
  bareline.config = h.get_config_with_fallback(config, bareline.config)
  bareline.config.draw_method(bareline.config.statusline)
end

--- #delimiter
--- #tag bareline.config

--- The default `config` used for |Bareline.setup()| uses distinct statuslines for
--- active, inactive and plugin windows. The resulting style is inspired by
--- Helix's default statusline:
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
  bareline.config = {
    draw_method = bareline.draw_methods.draw_active_inactive_plugin,
    statusline = {
      -- Active.
      {
        {
          bareline.components.vim_mode,
          bareline.components.get_file_path_relative_to_cwd,
          bareline.components.lsp_servers,
          "%m", "%h", "%r",
        },
        {
          bareline.components.diagnostics,
          bareline.components.indent_style,
          bareline.components.end_of_line,
          bareline.components.git_branch,
          bareline.components.position,
        },
      },
      -- Inactive.
      {
        {
          bareline.components.vim_mode:mask(" "),
          bareline.components.get_file_path_relative_to_cwd,
          bareline.components.lsp_servers,
          "%m", "%h", "%r",
        },
        {
          bareline.components.diagnostics,
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
  }
--minidoc_replace_start
end
--minidoc_replace_end
--minidoc_afterlines_end

-- PROVIDERS

bareline.providers = {}

--- #delimiter
--- #tag bareline.providers

--- A provider is a function which takes no arguments and returns a single value
--- of any type or nil.
---
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
function bareline.providers.get_vim_mode()
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
function bareline.providers.get_git_head()
  local git_dir = vim.fn.finddir(".git", ".;")
  return (git_dir ~= "" and vim.fn.readfile(git_dir .. "/HEAD")[1]) or nil
end

--- LSP attached servers.
--- Returns the names of the LSP servers attached to the current buffer.
--- Example output: `{ "lua_ls" }`
---@return table
function bareline.providers.lsp_server_names()
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
function bareline.providers.get_diagnostics()
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
function bareline.providers.get_file_path_relative_to_cwd()
  local buf_name = vim.api.nvim_buf_get_name(0)
  if buf_name == "" or vim.bo.filetype == "help" then return "%f" end
  local replacement, _ = string.gsub(
      vim.api.nvim_buf_get_name(0),
      h.escape_lua_pattern(vim.fn.getcwd()) .. "/",
      "")
  return replacement
end

-- COMPONENTS

bareline.components = {}

--- #delimiter

--- Standardized component.
--- All bundled components are structured like this. To create your own
--- components, you can use this class or, more simply, follow the alternate
--- approaches described in |Bareline.components|.
---@class BareComponent
---@field provider function|string Provides the value displayed in the statusline,
--- like the Vim mode. When a function, should return a single value of any type.
--- When a string, that itself is used.
---@field opts BareComponentOpts Options.
bareline.BareComponent = {}
bareline.BareComponent["__index"] = bareline.BareComponent

---@class BareComponentOpts
---@field format function Takes a single argument, whatever the `provider` value
--- is, and maps it to a string or nil. If nil, then the component is disregarded
--- from the statusline.
---@field cache_on_vim_modes string[] Use cache in these Vim modes. Each Vim
--- mode is expected as the first char returned by |mode()|.

--- Constructor.
--- Parameters ~
--- {provider} `function` See |Bareline.providers|.
--- {opts} BareComponentOpts Options.
--- Return ~
--- Bareline.BareComponent
function bareline.BareComponent:new(provider, opts)
  local bare_component = {}
  setmetatable(bare_component, self)
  bare_component.provider = provider
  bare_component.opts = opts
  return bare_component
end

--- Mask with char.
--- Replace each character of the component with the provided character.
--- Parameters ~
--- {char} `(string)` Single character.
--- Return ~
--- `(function)` When called returns the masked value.
function bareline.BareComponent:mask(char)
  local this = self
  local character = string.sub(char, 1, 1)
  return function()
    local component_value = h.build_user_supplied_component(this)
    if component_value == nil then return nil end
    return component_value:gsub(".", character)
  end
end

--- #delimiter
--- #tag bareline.components

--- Bundled components, meant to be used for the function |Bareline.setup()|.
--- These are all structured as a |Bareline.BareComponent|.

--- Vim mode.
--- The Vim mode in 3 characters.
--- Mockups: `NOR`, `VIS`
---@type BareComponent
bareline.components.vim_mode = bareline.BareComponent:new(
  bareline.providers.get_vim_mode,
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

--- Plugin name.
--- When on a plugin window, the formatted name of the plugin window.
--- Mockup: `[Nvim Tree]`
---@type BareComponent
bareline.components.plugin_name = bareline.BareComponent:new(
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

--- Indent style.
--- The indent style on insert mode. Relies on 'expandtab' and 'tabstop'.
--- Mockups: `spaces-2`, `tabs-4`
---@type BareComponent
bareline.components.indent_style = bareline.BareComponent:new(
  function()
    local whitespace_type = "tabs"
    if vim.bo.expandtab then whitespace_type = "spaces" end
    return whitespace_type .. "-" .. vim.bo.tabstop
  end
)

--- End of line (EOL).
--- Indicates when the buffer does not have an EOL on its last line. Return `noeol`
--- in this case, nil otherwise. This uses the option 'eol'.
---@type BareComponent
bareline.components.end_of_line = bareline.BareComponent:new(
  function()
    if vim.bo.eol then return nil end
    return "noeol"
  end
)

--- Git HEAD.
--- Properly displays the Git branch and commit hashes.
--- Mockup: `(main)`
---@type BareComponent
bareline.components.git_branch = bareline.BareComponent:new(
  bareline.providers.get_git_head,
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

--- LSP servers.
--- The LSP servers attached to the current buffer.
--- Mockup: `[lua_ls]`
---@type BareComponent
bareline.components.lsp_servers = bareline.BareComponent:new(
  bareline.providers.lsp_server_names,
  {
    format = function(lsp_servers)
      if lsp_servers == nil or vim.tbl_isempty(lsp_servers) then return nil end
      return "[" .. vim.fn.join(lsp_servers, ",") .. "]"
    end
  }
)

--- Stable `%f`.
--- The file path relative to the current working directory (|:pwd|).
--- Mockup: `lua/bareline.lua`
---@type BareComponent
bareline.components.get_file_path_relative_to_cwd = bareline.BareComponent:new(
  bareline.providers.get_file_path_relative_to_cwd
)

--- Diagnostics.
--- The diagnostics of the current buffer.
--- Mockup: `E:2,W:1`
---@type BareComponent
bareline.components.diagnostics = bareline.BareComponent:new(
  bareline.providers.get_diagnostics,
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

--- Cursor position.
--- The current cursor position in the format: line,column/total-lines.
--- Mockup: `181,43/329`
---@type BareComponent
bareline.components.position = bareline.BareComponent:new("%02l,%02c/%02L")

-- DRAW METHODS

--- #delimiter
--- #tag bareline.draw_methods

--- Draw methods rely on |autocmd|s and a |timer| to properly draw the provided
--- statusline on all windows. Use |bareline.draw_methods.stop_all| to stop the
--- drawing.

bareline.draw_methods = {}

--- Use distinct statuslines for active, inactive and plugin windows. The provided
--- statuslines are handled in this order by table index: (1) drawn on the active
--- window, (2) drawn on the inactive window and (3) drawn on the plugin window,
--- having precedence over the active window statusline.
---@param statuslines BareStatusline[]
function bareline.draw_methods.draw_active_inactive_plugin(statuslines)
  ---@type BareStatusline
  local active_window_statusline = statuslines[1]
  ---@type BareStatusline
  local inactive_window_statusline = statuslines[2]
  ---@type BareStatusline
  local plugin_window_statusline = statuslines[3]

  ---@param statusline_1 BareStatusline Statusline for a plugin window.
  ---@param statusline_2 BareStatusline Statusline drawn otherwise.
  local function draw_statusline_if_plugin_window(statusline_1, statusline_2)
    if h.is_plugin_window(vim.fn.bufnr()) then
      h.draw_window_statusline(statusline_1)
    else
      h.draw_window_statusline(statusline_2)
    end
  end

  -- Redraw statusline immediately to update specific components, e.g. the Vim
  -- mode. For plugin windows (e.g. nvim-tree), use a special statusline.
  vim.api.nvim_create_autocmd(
    { "ModeChanged", "DiagnosticChanged", "BufEnter" },
    {
      group = h.draw_methods_augroup,
      callback = function()
        draw_statusline_if_plugin_window(
          plugin_window_statusline,
          active_window_statusline
        )
      end,
    }
  )

  vim.api.nvim_create_autocmd("OptionSet", {
      group = h.draw_methods_augroup,
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
    group = h.draw_methods_augroup,
    callback = function()
      draw_statusline_if_plugin_window(
          plugin_window_statusline,
          inactive_window_statusline
        )
    end,
  })

  h.draw_window_statusline(active_window_statusline)
end

-- Set module default config.
apply_default_config()

-- -----
--- #end

-- BUILD

--- - Function: Must return either a string or nil. The returned string is
---   what gets placed in the statusline. When nil is returned, the component
---   is skipped, leaving no gap.
--- - String: The string is considered as if a function component had already
---   been executed and its output is the provided string. Handy for placing
---   statusline fields, for example `%f`.
--- - |StdComponent|: Table which allows component configuration.
---@alias UserSuppliedComponent function|string|BareComponent

--- The standard component built into a string or nil.
---@alias ComponentValue string|nil

---@class ComponentValueCache Cache of a built component.
---@field value string|nil Component cache value.

h.component_cache_by_win_id = {}

---@param bare_component table
---@return ComponentValueCache|nil
function h.get_component_cache(bare_component)
  local win_id = vim.fn.win_getid()
  if h.component_cache_by_win_id[win_id] == nil then return nil end
  return h.component_cache_by_win_id[win_id][tostring(bare_component.provider)]
end

---@param bare_component BareComponent
---@param bare_component_built ComponentValue
function h.store_bare_component_cache(bare_component, bare_component_built)
  local win_id = vim.fn.win_getid()
  if h.component_cache_by_win_id[win_id] == nil then
    h.component_cache_by_win_id[win_id] = {}
  end
  h.component_cache_by_win_id[win_id][tostring(bare_component.provider)] =
    { provider = bare_component_built }
end

---@param bare_component BareComponent
---@return any
function h.get_bare_component_provider_value(bare_component)
  local provider = bare_component.provider
  if type(provider) == "string" then return provider end
  if type(provider) == "function" then return provider() end
  return nil
end

---@param component UserSuppliedComponent
---@return BareComponent
function h.standardize_component(component)
  if type(component) == "function" or type(component) == "string" then
    return { provider = component, opts = {} }
  end
  if type(component) == "table" then
    component.opts = component.opts or {}
    return component
  end
  vim.api.nvim_echo({
    {
      "Provided statusline component is not a string, function or table.",
      "Error"
    },
  }, true, {})
  return {}
end

---@param component UserSuppliedComponent
---@return ComponentValue
function h.build_user_supplied_component(component)
  ---@type BareComponent
  local bare_component = h.standardize_component(component)
  ---@type ComponentValueCache|nil
  local component_cache = h.get_component_cache(bare_component)
  ---@type BareComponentOpts
  local opts = bare_component.opts

  if opts.cache_on_vim_modes and component_cache then
    local is_cache_vim_mode = vim.fn.mode():lower():match(
      string.format("[%s]", table.concat(opts.cache_on_vim_modes, ""))
    )
    if is_cache_vim_mode then return component_cache.value end
  end

  local provider_value = h.get_bare_component_provider_value(bare_component)
  if opts.format then provider_value = opts.format(provider_value) end
  h.store_bare_component_cache(bare_component, provider_value)

  return provider_value
end

h.component_separator = "  "

---@alias BareSection UserSuppliedComponent[]
---@alias BareStatusline BareSection[]

--- At least one component is expected to be built into a non-nil value.
---@param section table Statusline section, as may be provided by a user.
---@return string
function h.build_section(section)
  local built_components = {}
  for _, component in ipairs(section) do
    table.insert(built_components, h.build_user_supplied_component(component))
  end
  return table.concat(
    vim.tbl_filter(function(built_component)
      return built_component ~= nil
    end,
    built_components),
    h.component_separator
  )
end

--- Use this function when implementing a custom draw method.
--- See |bareline.draw_methods|.
---@param sections table
---@return string _ String assignable to 'statusline'.
function h.build_statusline(sections)
  local built_sections = {}
  for _, section in ipairs(sections) do
    table.insert(built_sections, h.build_section(section))
  end
  return string.format(" %s ", table.concat(built_sections, "%="))
end

-- DRAW

h.draw_methods_augroup = vim.api.nvim_create_augroup("BarelineDrawMethods", {})

---@param buffer integer The window number, as returned by |bufnr()|.
---@return boolean
function h.is_plugin_window(buffer)
  local plugin_file_types = {
    "nvimtree"
  }
  return vim.tbl_contains(plugin_file_types, vim.bo[buffer].filetype:lower())
end

---@param statusline BareStatusline
function h.draw_window_statusline(statusline)
  vim.wo.statusline = h.build_statusline(statusline)
end

h.draw_helpers_augroup = vim.api.nvim_create_augroup("BarelineDrawHelpers", {})

-- Cleanup components cache.
vim.api.nvim_create_autocmd({ "WinClosed" }, {
  group = h.draw_helpers_augroup,
  callback = function(event)
    local window = event.match
    h.component_cache_by_win_id[window] = nil
  end,
})

-- OTHER

--- Merge user-supplied config with the plugin's default config. For every key
--- which is not supplied by the user, the value in the default config will be
--- used. The user's config has precedence; the default config is the fallback.
---@param config? table User supplied config.
---@param default_config table Bareline's default config.
---@return table
function h.get_config_with_fallback(config, default_config)
  vim.validate { config = { config, "table", true } }
  config = vim.tbl_deep_extend(
    "force", vim.deepcopy(default_config), config)
  vim.validate {
    draw_method = { config.draw_method, "function" },
    statusline = { config.statusline, "table" }
  }
  return config
end

--- Given a string, escape the Lua magic pattern characters so that the string can
--- be used for an exact match, e.g. as the pattern supplied to 'string.gsub'.
--- See: https://www.lua.org/manual/5.1/manual.html#5.4.1
---@param string string
---@return string
function h.escape_lua_pattern(string)
  string, _ = string:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0")
  return string
end

return bareline
