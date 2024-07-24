--- *bareline* Configure simple statuslines.
---
--- MIT License Copyright (c) 2024 Hernán Cervera.
---
--- ==============================================================================
---
--- Key design ideas ~
---
--- 1. Ease of configuration.
---
--- 2. Can be used as a library for common statusline data providers.
---
--- Concepts ~
---
--- Bareline conceptualizes a statusline in this way:
--- * A statusline is a list of sections.
--- * Each section is a list of components.
---
--- Visualized example:
---
--- Statusline: | NOR  lua/bareline.lua                        (main)  22,74/454 |
---               Section 1                                    Section 2
---               └── Components                               └── Components
---                   ├── Vim mode                                 ├── Git HEAD
---                   └── Relative file path                       └── Location
---
--- The bundled components get their data from a provider (|bareline.providers|).

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
--- then take a look at |bareline.providers|.
---
---@param config table|nil Module config table. |bareline.default_config| defines
--- the default configuration. If the `config` arg is nil, then the default config
--- is used. If a config table is provided, it's merged with the default config
--- and the keys in the user's config take precedence.
function bareline.setup(config)
  bareline.config = h.get_config_with_fallback(config, bareline.default_config)
  bareline.config.draw_method(bareline.config.statusline)
end

--- #delimiter
--- #tag bareline.default_config

--- Behavior ~
---
--- The default `config` used for |bareline.setup()| uses distinct statuslines for
--- active, inactive and plugin windows. The resulting style is inspired by
--- Helix's default statusline:
---
--- Active window:
--- * | NOR  lua/bareline.lua  [lua_ls]      H:2,W:4  spaces-2  (main)  42,21/50 |
--- Inactive window:
--- * |      lua/bareline.lua  [lua_ls]              H:2,W:4  spaces-2  42,21/50 |
--- Plugin window:
--- * | [nvimtree]  [-]                                                 28,09/33 |
---                      https://github.com/helix-editor/helix
---
--- Default config ~
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
--minidoc_replace_start
local function assign_default_config()
--minidoc_replace_end
  bareline.default_config = {

    -- Function which takes a single argument, the `statusline` table. Based
    -- on the draw method, `statusline` might need to contain more than one
    -- statusline definition. With the default, 3 statuslines are expected.
    draw_method = bareline.draw_methods.draw_active_inactive_plugin,

    -- Enable the timer in case you have a component which is tricky to watch,
    -- or just don't want to bother with identifying how to watch it. Accepts
    -- a boolean (false = disabled, true = 500ms), or a number indicating ms
    -- in between statusline re-draws.
    timer = false,

    statusline = {
      { -- Statusline 1: Active window.
        { -- Section 1: Left.
          bareline.components.vim_mode,
          bareline.components.get_file_path_relative_to_cwd,
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

      { -- Statusline 2: Inactive window.
        { -- Section 1: Left.
          bareline.components.vim_mode:mask(" "),
          bareline.components.get_file_path_relative_to_cwd,
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

      { -- Statusline 3: Plugin window.
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
--minidoc_replace_start
end
--minidoc_replace_end
--minidoc_afterlines_end

--- Overriding the defaults ~
---
--- To override the defaults, copy/paste the default config as a starting point to
--- use for the function |bareline.setup()|.
---
--- Custom components: These are the allowed types for `user supplied components`:
---
--- * String: Useful for very simple components, for example, statusline items
---   like `%r` ('statusline') or options like 'fileformat'.
--- * Function: Must return either a string or nil. The returned string is
---   what gets placed in the statusline. When nil is returned, the component
---   is skipped, leaving no gap.
--- * |bareline.BareComponent|: Object which allows component configuration. The
---   bundled components follow this structure (|bareline.components|).
---@alias UserSuppliedComponent string|function|BareComponent

--- If the changes you want to make are few, then your config can be concise by
--- doing a deep copy of the defaults and then inserting your components, e.g.:
--- >lua
---   local bareline = require("bareline")
---   -- Custom component.
---   local component_prose_mode = function ()
---     if string.find(vim.bo.formatoptions, "a") then return "PROSE" end
---     return nil
---   end
---   -- Overrides to default config.
---   local config = vim.deepcopy(bareline.default_config)
---   table.insert(config.statusline[1][1], 2, component_prose_mode)
---   table.insert(config.statusline[2][1], 2, component_prose_mode)
---   -- Draw statusline.
---   bareline.setup(config)
--- <

-- PROVIDERS

bareline.providers = {}

--- #delimiter
--- #tag bareline.providers

--- A provider is a function which takes no arguments and returns a single value
--- of any type or nil.
---
--- If you want to use the providers directly, most likely you do not want to use
--- the setup function (|bareline.setup()|). Providers give data in a convenient
--- format for parsing, which can be used so you build your own statusline
--- without using any other functionality provided in Bareline. Example:
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
function bareline.providers.get_lsp_server_names()
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
--- component types described in |bareline.default_config|.
---@class BareComponent
---@field value string|function Provides the value displayed in the statusline,
--- like the Vim mode. When a function, should return a single value of any type.
--- When a string, that itself is used.
---@field watcher BareComponentWatcher Watcher. Triggers a statusline redraw.
---@field opts BareComponentOpts Options.
bareline.BareComponent = {}
bareline.BareComponent["__index"] = bareline.BareComponent

---@class BareComponentWatcher
---@field autocmd table Expects a table with the keys `event` and `opts`. These
--- values are passed as is to |vim.api.nvim_create_autocmd()|.
---@field filepath function|string|table Filepath or list of filepaths to watch.
--- Alternatively, a function which expects zero args can be provided to compute
--- the filepath. Strings and functions can be mixed if the type is table.

---@class BareComponentOpts
---@field cache_on_vim_modes string[] Use cache in these Vim modes. Each Vim
--- mode is expected as the first char returned by |mode()|.

--- Constructor.
--- Parameters ~
--- {value} `function|string` As a function, it expects no args and returns a
--- single value of any type. As a string, is used as is.
--- {opts} BareComponentOpts Options.
--- Return ~
--- Bareline.BareComponent
function bareline.BareComponent:new(value, opts)
  local bare_component = {}
  setmetatable(bare_component, self)
  bare_component.value = value
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

--- Bundled components, meant to be used for the function |bareline.setup()|.
--- These are all structured as a |bareline.BareComponent|.
---
--- User supplied components can have a simpler structure. Read the section
--- 'Overriding the defaults' from |bareline.default_config|.
---

--- Vim mode.
--- The Vim mode in 3 characters.
--- Mockups: `NOR`, `VIS`
---@type BareComponent
bareline.components.vim_mode = bareline.BareComponent:new(
  function()
    local vim_mode = bareline.providers.get_vim_mode()
    local mode_labels = {
      n = "nor", i = "ins", v = "vis", s = "sel",
      t = "ter", c = "cmd", r = "rep", bv = "vis",
      bs = "sel", ["!"] = "ext",
    }
    return mode_labels[vim_mode]:upper()
  end,
  {
    watcher = {
      autocmd = {
        event = "ModeChanged"
      }
    }
  }
)

--- Plugin name.
--- When on a plugin window, the formatted name of the plugin window.
--- Mockup: `[nvimtree]`
---@type BareComponent
bareline.components.plugin_name = bareline.BareComponent:new(
  function()
    return string.format("[%s]", vim.bo.filetype:lower():gsub("%s", ""))
  end
)

--- Indent style.
--- The indent style. Relies on 'expandtab' and 'tabstop'. This component is
--- omitted when the buffer has 'modifiable' disabled.
--- Mockups: `spaces:2`, `tabs:4`
---@type BareComponent
bareline.components.indent_style = bareline.BareComponent:new(
  function()
    if not vim.bo.modifiable then return nil end
    local whitespace_type = (vim.bo.expandtab and "spaces") or "tabs"
    return whitespace_type .. ":" .. vim.bo.tabstop
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
--- Displays the Git HEAD, useful to show the Git branch.
--- Mockup: `(main)`
---@type BareComponent
bareline.components.git_head = bareline.BareComponent:new(
  function()
    local git_head = bareline.providers.get_git_head()
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
  end,
  {
    watcher = {
      filepath = function()
        local git_dir = vim.fn.finddir(".git", ".;")
        if git_dir ~= "" then return git_dir end
        return nil
      end
    }
  }
)

--- LSP servers.
--- The LSP servers attached to the current buffer.
--- Mockup: `[lua_ls]`
---@type BareComponent
bareline.components.lsp_servers = bareline.BareComponent:new(
  function()
    local lsp_servers = bareline.providers.get_lsp_server_names()
    if lsp_servers == nil or vim.tbl_isempty(lsp_servers) then return nil end
    return "[" .. vim.fn.join(lsp_servers, ",") .. "]"
  end,
  {
    watcher = {
      autocmd = {
        event = { "LspAttach", "LspDetach" }
      }
    }
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
  function()
    -- Diagnostics per severity.
    local diagnostics = bareline.providers.get_diagnostics()
    if diagnostics == nil then return nil end
    local formatted_diagnostics = ""
    local diagnostics_severity_label = { "E", "W", "I", "H" }
    local separator = ""
    for index, count in ipairs(diagnostics) do
      if count > 0 then
        formatted_diagnostics = formatted_diagnostics
        .. string.format(
        "%s%s:%s", separator, diagnostics_severity_label[index], count)
        separator = ","
      end
    end
    return formatted_diagnostics
  end,
  {
    watcher = {
      autocmd = {
        event = "DiagnosticChanged"
      }
    },
    cache_on_vim_modes = { "i" }
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

--- Draw methods are functions which take a single argument, a table holding one
--- or more statuslines, and implement how the statusline(s) is(are) drawn.
---
--- A statusline is a list of sections, and a section is a list of components, as
--- per the `user supplied components` documented in the section 'Overriding the
--- defaults' from |bareline.default_config|.
---

bareline.draw_methods = {}

--- Draw distinct statuslines for active, inactive and plugin windows.
--- Rely on |autocmd|s and a |timer| (not everything is watched). The provided
--- statuslines are handled in this order by table index: [1] drawn on the active
--- window, [2] drawn on the inactive window and [3] drawn on the plugin window
--- (having precedence over the active window statusline).
---@param statuslines BareStatusline[]
function bareline.draw_methods.draw_active_inactive_plugin(statuslines)
  ---@type BareStatusline
  local active_window_statusline = statuslines[1]
  ---@type BareStatusline
  local inactive_window_statusline = statuslines[2]
  ---@type BareStatusline
  local plugin_window_statusline = statuslines[3]

  -- Create base autocmds.
  vim.api.nvim_create_autocmd({
    "BufEnter", "BufWinEnter", "VimResume", "FocusGained" },
    {
      group = h.draw_methods_augroup,
      callback = function()
        h.draw_statusline_if_plugin_window(
          plugin_window_statusline,
          active_window_statusline
        )
      end,
    }
  )
  vim.api.nvim_create_autocmd("OptionSet", {
      group = h.draw_methods_augroup,
      callback = function(event)
        local options_blacklist = {
          "statusline", "laststatus", "eventignore",
          "winblend", "winhighlight"
        }
        if vim.tbl_contains(options_blacklist, event.match) then return end
        h.draw_statusline_if_plugin_window(
          plugin_window_statusline,
          active_window_statusline
        )
      end,
    }
  )

  -- Create component-specific autocmds.
  h.create_bare_component_autocmds(statuslines, 2, function()
    h.draw_statusline_if_plugin_window(
      plugin_window_statusline,
      active_window_statusline
    )
  end)

  -- Create file watchers.
  h.create_bare_component_file_watchers(statuslines, 2, function()
    h.draw_statusline_if_plugin_window(
      plugin_window_statusline,
      active_window_statusline
    )
  end)

  -- Draw a different statusline for inactive windows. For inactive plugin
  -- windows, use a special statusline, the same one as for active plugin windows.
  vim.api.nvim_create_autocmd("WinLeave", {
    group = h.draw_methods_augroup,
    callback = function()
      h.draw_statusline_if_plugin_window(
          plugin_window_statusline,
          inactive_window_statusline
        )
    end,
  })

  -- Optionally set a timer.
  if bareline.config.timer then
    local time = bareline.config.timer
    if type(bareline.config.timer) == "boolean" then
      time = h.timer_default_time
    end
    vim.fn.timer_start(
      time,
      function()
        h.draw_statusline_if_plugin_window(
          plugin_window_statusline,
          active_window_statusline
        )
      end,
      { ["repeat"] = -1 }
    )
  end
end

-- Set module default config.
assign_default_config()

-- -----
--- #end

-- BUILD

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
  return h.component_cache_by_win_id[win_id][tostring(bare_component.value)]
end

---@param bare_component BareComponent
---@param bare_component_value ComponentValue
function h.store_bare_component_cache(bare_component, bare_component_value)
  local win_id = vim.fn.win_getid()
  if h.component_cache_by_win_id[win_id] == nil then
    h.component_cache_by_win_id[win_id] = {}
  end
  h.component_cache_by_win_id[win_id][tostring(bare_component.value)] =
    { value = bare_component_value }
end

---@param bare_component BareComponent
---@return any
function h.compute_bare_component_value(bare_component)
  local value = bare_component.value
  if type(value) == "string" then return value end
  if type(value) == "function" then return value() end
  return nil
end

---@param component UserSuppliedComponent
---@return BareComponent
function h.standardize_component(component)
  vim.validate({
    component = { component, { "string", "function", "table" }, true }
  })
  if type(component) == "string" or type(component) == "function" then
    return { value = component, opts = {} }
  end
  if type(component) == "table" then
    component.opts = component.opts or {}
    return component
  end
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
    local short_current_vim_mode = vim.fn.mode():lower():sub(1, 1)
    if vim.tbl_contains(opts.cache_on_vim_modes, short_current_vim_mode) then
      return component_cache.value
    end
  end

  local computed_value = h.compute_bare_component_value(bare_component)
  h.store_bare_component_cache(bare_component, computed_value)

  return computed_value
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

h.timer_default_time = 500
h.draw_methods_augroup = vim.api.nvim_create_augroup("BarelineDrawMethods", {})

---@param bufnr integer The buffer number, as returned by |bufnr()|.
---@return boolean
function h.is_plugin_window(bufnr)
  local filetype = vim.bo[bufnr].filetype
  local special_non_plugin_filetypes = { nil, "", "help", "man", "qf" }
  local matched_filetype, _ = vim.filetype.match({ buf = bufnr })
  return matched_filetype == nil
    and not vim.tbl_contains(special_non_plugin_filetypes, filetype)
end

---@param statusline BareStatusline
function h.draw_window_statusline(statusline)
  vim.wo.statusline = h.build_statusline(statusline)
end

---@param statusline_1 BareStatusline Statusline for a plugin window.
---@param statusline_2 BareStatusline Statusline drawn otherwise.
function h.draw_statusline_if_plugin_window(statusline_1, statusline_2)
  if h.is_plugin_window(vim.fn.bufnr()) then
    h.draw_window_statusline(statusline_1)
  else
    h.draw_window_statusline(statusline_2)
  end
end

---@param nested_components_list BareComponent[] Statusline(s) definition(s).
---@param depth number Depth at which the components exist in the list.
---@param callback function Autocmd callback function.
function h.create_bare_component_autocmds(nested_components_list, depth, callback)
  vim.iter(nested_components_list)
    :flatten(depth)
    :map(function (bare_component)
      local bc = bare_component
      if type(bc) ~= "table" then return nil end
      local autocmd = bc.opts and bc.opts.watcher and bc.opts.watcher.autocmd
      if autocmd == nil then return end
      vim.validate({ ["autocmd.event"] = {
        autocmd.event, { "string", "table" } }
      })
      if autocmd.opts == nil then autocmd.opts = {} end
      return autocmd
    end)
    :each(function (autocmd)
      autocmd.opts.callback = callback
      autocmd.opts.group = h.draw_methods_augroup
      vim.api.nvim_create_autocmd(autocmd.event, autocmd.opts)
    end)
end

---@param nested_components_list BareComponent[] Statusline(s) definition(s).
---@param depth number Depth at which the components exist in the list.
---@param callback function Luv callback function.
function h.create_bare_component_file_watchers(
    nested_components_list, depth, callback)

  local uv_fs_event = vim.uv.new_fs_event()

  local function watch_file(absolute_filepath)
    ---@diagnostic disable-next-line: need-check-nil
    uv_fs_event:start(
      absolute_filepath, {},
      vim.schedule_wrap(function()
        callback()
      end))
  end

  local absolute_filepaths = vim.iter(nested_components_list)
    :flatten(depth)
    :map(function (bare_component)
      local bc = bare_component
      if type(bc) ~= "table" then return nil end
      local filepath = bc.opts and bc.opts.watcher and bc.opts.watcher.filepath
      if filepath == nil then return end
      vim.validate({ filepath = {
        filepath, { "function", "string", "table" } }
      })
      return filepath
    end)
    :flatten()
    -- Map to absolute file paths.
    :map(function (filepath)
      if filepath == nil then return nil end
      if type(filepath) == "function" then filepath = filepath() end
      return vim.fn.fnamemodify(filepath, ":p")
    end)
    -- Remove duplicate filepaths.
    :fold({}, function(acc, v)
      if not vim.tbl_contains(acc, v) then table.insert(acc, v) end
      return acc
    end)

    -- Start file watchers.
    for _, absolute_filepath in ipairs(absolute_filepaths) do
      watch_file(absolute_filepath)
    end
end

-- Cleanup components cache.
vim.api.nvim_create_autocmd({ "WinClosed" }, {
  group = h.draw_methods_augroup,
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
    "force", vim.deepcopy(default_config), config or {})
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
