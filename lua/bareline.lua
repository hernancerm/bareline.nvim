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
--- 2. Update immediately as changes happen. No timer required.
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

-- MODULE SETUP

local bareline = {}
local h = {}

--- #delimiter

--- Module setup.
---
--- To enable the plugin you need to call the `setup()` function. Usage:
--- >lua
---   local bareline = require("bareline")
---   bareline.setup() -- You may provide a table for your configuration.
--- <
--- I recommend disabling 'showmode', so only Bareline shows the Vim mode.
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
--- * | NOR  lua/bareline.lua  [lua_ls]      e:2,w:1  spaces-2  (main)  42,21/50 |
--- Inactive window:
--- * |      lua/bareline.lua  [lua_ls]              e:2,w:1  spaces-2  42,21/50 |
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
---   like `%r` (see 'statusline') or options like 'fileformat'.
--- * Function: Must return either a string or nil. The returned string is
---   what gets placed in the statusline. When nil is returned, the component
---   is skipped, leaving no gap.
--- * |bareline.BareComponent|: Object which allows component configuration. The
---   bundled components follow this structure (|bareline.components|). You might
---   need to use this component type to provide a watching config, to avoid the
---   need for a timer. In some cases, watching can work even with no watching
---   configuration, see |bareline.BareComponentWatcher|, in those cases you can
---   simply use a string or function component.
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
---@field opts BareComponentOpts Options.
bareline.BareComponent = {}
bareline.BareComponent["__index"] = bareline.BareComponent

--- #tag bareline.BareComponentOpts
---@class BareComponentOpts
---@field watcher BareComponentWatcher Watcher. Triggers a statusline redraw.
---@field cache_on_vim_modes function|string[] Use cache in these Vim modes. Each
--- Vim mode is expected as the first char returned by |mode()|. When a function,
--- it expects no args and should return a list with the Vim modes.

--- #tag bareline.BareComponentWatcher
--- Defines the structure of watcher configuration for a component.
--- With Bareline, you don't need a timer to have the statusline update when you
--- expect it to. Since there is no fixed redraw, the plugin needs a way to know
--- when to do a redraw. That knowledge is provided to Bareline in a per component
--- basis through the watcher configuration.
--- When adding new components, you don't have to worry about watchers if the base
--- autocmds are enough. Here are the base autocmds per draw method:
--- * |bareline.draw_methods.draw_active_inactive_plugin|:
---   * |BufNew|, |BufEnter|, |BufWinEnter|, |VimResume|,
---     |FocusGained|, |OptionSet|, |DirChanged|.
---   * In other words, pretty much only option changes are watched as a base.
---@class BareComponentWatcher
---@field autocmd table Expects a table with the keys `event` and `opts`. These
--- values are passed as is to |vim.api.nvim_create_autocmd()|.
---@field filepath string|function Filepath to watch. Alternatively, a function
---which expects zero args can be provided to compute the filepath.

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
    local vim_mode = h.provide_vim_mode()
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
        event = { "ModeChanged", "InsertLeave" }
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
    local git_head = h.provide_git_head()
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
    local lsp_servers = h.provide_lsp_server_names()
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
  function () return h.provide_file_path_relative_to_cwd() end
)

--- Diagnostics.
--- The diagnostics of the current buffer. Respects the value of:
--- `update_in_insert` from |vim.diagnostic.config()|.
--- Mockup: `e:2,w:1`
---@type BareComponent
bareline.components.diagnostics = bareline.BareComponent:new(
  function()
    local output = ""
    local severity_labels = { "e", "w", "i", "h" }
    local diagnostic_count = vim.diagnostic.count()
    for i = 1, 4 do
      local count = diagnostic_count[i]
      if count ~= nil then
        output = output .. severity_labels[i] .. ":" .. count .. ","
      end
    end
    return string.sub(output, 1, #output - 1)
  end,
  {
    watcher = {
      autocmd = {
        event = "DiagnosticChanged"
      }
    },
    cache_on_vim_modes = function()
      if vim.diagnostic.config().update_in_insert then return {} end
      return { "i" }
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
  -- DOCS: Keep in sync with "bareline.BareComponentWatcher".
  vim.api.nvim_create_autocmd(
    {
      "BufNew", "BufEnter", "BufWinEnter",
      "VimResume", "FocusGained", "DirChanged"
    },
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
  vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
    group = h.draw_methods_augroup,
    callback = function ()
      h.start_uv_fs_events(statuslines, 2, function()
        h.draw_statusline_if_plugin_window(
          plugin_window_statusline,
          active_window_statusline
        )
      end
      )
    end
  })

  -- Close file watchers (cleanup on dir change).
  vim.api.nvim_create_autocmd({ "VimLeave", "DirChangedPre" }, {
    group = h.draw_methods_augroup,
    callback = function () h.close_uv_fs_events() end
  })

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

-- PROVIDERS

-- A provider is a function which provides the base data to implement a component.

--- Vim mode.
--- Returns the first char of the current Vim mode (see |mode()|). For block
--- modes, two characters are returned, a "b" followed by the mode; currently,
--- only `bv` for "block visual mode" and `bs` for "block select mode". The
--- returned string has only lower case letters.
---@return string
function h.provide_vim_mode()
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
function h.provide_git_head()
  local git_dir = vim.fn.finddir(".git", ".;")
  return (git_dir ~= "" and vim.fn.readfile(git_dir .. "/HEAD")[1]) or nil
end

--- LSP attached servers.
--- Returns the names of the LSP servers attached to the current buffer.
--- Example output: `{ "lua_ls" }`
---@return table
function h.provide_lsp_server_names()
  return vim.tbl_map(
    function (client)
      return client.name
    end,
    vim.lsp.get_clients({ bufnr = 0 })
  )
end

--- Stable `%f`.
--- Returns the file path of the current buffer relative to the current working
--- directory (|:pwd|). If the file opened is not in this dir, then the absolute
--- path is returned. This is meant to be used instead of the field `%f` (see
--- 'statusline') for a more consistent experience.
---@return string
function h.provide_file_path_relative_to_cwd()
  local buf_name = vim.api.nvim_buf_get_name(0)
  if buf_name == "" or vim.bo.filetype == "help" then return "%f" end
  local replacement, _ = string.gsub(
      vim.api.nvim_buf_get_name(0),
      h.escape_lua_pattern(vim.fn.getcwd()) .. "/",
      "")
  return replacement
end

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
function h.get_bare_component_value(bare_component)
  local value = bare_component.value
  if type(value) == "string" then return value end
  if type(value) == "function" then return value() end
  return nil
end

---@param cache_on_vim_modes function|string[]
---@return string[]
function h.get_vim_modes_for_cache(cache_on_vim_modes)
  if type(cache_on_vim_modes) == "function" then return cache_on_vim_modes() end
  if type(cache_on_vim_modes) == "table" then return cache_on_vim_modes end
  return {}
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
    local vim_modes_for_cache = h.get_vim_modes_for_cache(opts.cache_on_vim_modes)
    if vim.tbl_contains(vim_modes_for_cache, short_current_vim_mode) then
      return component_cache.value
    end
  end

  local computed_value = h.get_bare_component_value(bare_component)
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
  return matched_filetype == nil and not vim.bo.buflisted
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
  local autocmds = vim.iter(nested_components_list)
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
      autocmd.opts.group = h.draw_methods_augroup
      autocmd.opts.callback = callback
      return autocmd
    end)
    -- Remove duplicate autocmds.
    :fold({}, function (acc, v)
      local is_duplicate_autocmd = vim.tbl_contains(
        acc, function(accv)
          return vim.deep_equal(accv, v)
        end, { predicate = true })
      if not is_duplicate_autocmd then table.insert(acc, v) end
      return acc
    end)
    -- Create autocmds.
    for _, autocmd in ipairs(autocmds) do
      vim.api.nvim_create_autocmd(autocmd.event, autocmd.opts)
    end
end

h.uv_fs_event_handles = {}

---@param nested_components_list BareComponent[] Statusline(s) definition(s).
---@param depth number Depth at which the components exist in the list.
---@param callback function Callback for |uv.fs_event_start()|.
function h.start_uv_fs_events(
    nested_components_list, depth, callback)

  local function watch_file(absolute_filepath)
    local uv_fs_event, error = vim.uv.new_fs_event()
    assert(uv_fs_event, error)
    local success, err_name = uv_fs_event:start(
      absolute_filepath, {},
      vim.schedule_wrap(function()
        callback()
      end))
    assert(success, err_name)
    table.insert(h.uv_fs_event_handles, uv_fs_event)
  end

  local absolute_filepaths = vim.iter(nested_components_list)
    :flatten(depth)
    :map(function (bare_component)
      local bc = bare_component
      if type(bc) ~= "table" then return nil end
      local filepath = bc.opts and bc.opts.watcher and bc.opts.watcher.filepath
      if filepath == nil then return end
      vim.validate({ filepath = {
        filepath, { "string", "function" } }
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

-- Close all fs_event handles.
function h.close_uv_fs_events()
  for _, handle in ipairs(h.uv_fs_event_handles) do handle:close() end
  h.uv_fs_event_handles = {}
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
