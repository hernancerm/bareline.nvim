--- *bareline* Configure simple statuslines.
---
--- MIT License Copyright (c) 2024 Hernán Cervera.
---
---                                              Press gO for a table of contents.
--- ==============================================================================
--- #tag bareline-intro
--- Introduction ~
---
--- Key design ideas
---
--- 1. Ease of configuration.
--- 2. Batteries included experience.
--- 3. No timer required. Update immediately as changes happen.
---
--- Concepts
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
--- #tag bareline-quickstart
--- Quickstart ~

--- To enable the plugin you need to call the `setup()` function. Usage:
--- >lua
---   vim.o.showmode = false
---   local bareline = require("bareline")
---   bareline.setup() -- You may provide a table for your configuration.
--- <

--- Module setup.
---@param config table|nil If a table is provided, it's merged with the default
--- config (|bareline.default_config|) and the keys in the user's config take
--- precedence. If `config` is nil, then the default config is used.
function bareline.setup(config)
  -- Cleanup.
  if #vim.api.nvim_get_autocmds({ group = h.draw_methods_augroup }) > 0 then
    vim.api.nvim_clear_autocmds({ group = h.draw_methods_augroup })
  end
  h.close_uv_fs_events()
  -- Setup.
  bareline.config = h.get_config_with_fallback(config, bareline.default_config)
  h.draw_methods.draw_active_inactive_plugin(
    bareline.config.statuslines.active,
    bareline.config.statuslines.inactive,
    bareline.config.statuslines.plugin
  )
end

--- #delimiter
--- #tag bareline.default_config
--- Default configuration ~

--- The default config used for |bareline.setup()| uses distinct statuslines for
--- active, inactive and plugin windows. Here is a sample of how the statuslines
--- can look:
---
--- Active window:
--- * | NOR  lua/bareline.lua  [lua_ls]      e:2,w:1  spaces-2  (main)  42,21/50 |
--- Inactive window:
--- * |      lua/bareline.lua  [lua_ls]              e:2,w:1  spaces-2  42,21/50 |
--- Plugin window:
--- * | [nvimtree]  [-]                                                 28,09/33 |
---
--- Default configuration
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
--minidoc_replace_start
local function assign_default_config()
--minidoc_replace_end
bareline.default_config = {
  statuslines = {
    -- Active window.
    active = {
      { -- Section 1: Left.
        bareline.components.vim_mode,
        bareline.components.file_path_relative_to_cwd,
        bareline.components.lsp_servers,
        "%m", "%h", "%r",
      },
      { -- Section 2: Right.
        bareline.components.diagnostics,
        bareline.components.indent_style,
        bareline.components.end_of_line,
        bareline.components.git_head,
        bareline.components.cwd,
        bareline.components.position,
      },
    },
    -- Inactive windows.
    inactive = {
      { -- Section 1: Left.
        bareline.components.vim_mode:mask(" "),
        bareline.components.file_path_relative_to_cwd,
        bareline.components.lsp_servers,
        "%m", "%h", "%r",
      },
      { -- Section 2: Right.
        bareline.components.diagnostics,
        bareline.components.indent_style,
        bareline.components.end_of_line,
        bareline.components.cwd,
        bareline.components.position,
      },
    },
    -- Plugin windows.
    plugin = {
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

--- #delimiter
--- #tag bareline-custom-config
--- Custom configuration ~

--- To override the defaults (|bareline.default_config|), change only the values
--- of the keys that you need. You do not have to copy paste the entire defaults.
--- For example, if you want to make the inactive statusline be the same as the
--- default active one, you can call |bareline.setup()| like this:
--- >lua
---   local bareline = require("bareline")
---   bareline.setup({
---     statuslines = {
---       inactive = bareline.default_config.statuslines.active
---     }
---   })
--- <
--- Custom components: Each statusline sections is a list-like table of
--- components. These components can be Bareline's built-in components
--- (|bareline.components|) or a type as below:
---
--- 1. String: Gets evaluated as a statusline string (see 'statusline'). Examples:
---    * Arbitrary string: `"PROSE"`. In the statusline you'll see `PROSE`.
---    * Options: `vim.bo.fileformat`. In the statusline you might see `unix`.
---    * Statusline item: `"%r"`. In the statusline you might see `[RO]`.
---
--- 2. Function: Returns a string or nil. When a string, it's placed in the
---    statusline; when nil, the component is skipped. Example:
--- >lua
---    -- Current working directory.
---    local component_cwd = function ()
---      local cwd = vim.uv.cwd() or ""
---      if cwd == vim.uv.os_getenv("HOME", 60) then return "~" end
---      return vim.fn.fnamemodify(cwd, ":t")
---    end
---    -- Possible output: "bareline.nvim".
--- <
--- 3. |bareline.BareComponent|: Create one of this type if you need to specify a
---    watching config on when to redraw the statusline to keep the component
---    up-to-date. This is for when you need to watch a file or directory or
---    register autocommands. Use: |bareline.BareComponentWatcher|
---
---    For several use cases, you don't need to specify a watching config, so you
---    can get away with a string or function component. The autocmds configured
---    by default might be enough to monitor what you are displaying in your
---    statusline:
---
---      |BufEnter|, |BufWinEnter|, |WinEnter|, |VimResume|,
---      |FocusGained|, |OptionSet|, |DirChanged|.

---@alias UserSuppliedComponent string|function|BareComponent

-- COMPONENTS

bareline.components = {}

--- #delimiter
--- #tag bareline-bare-component
--- BareComponent ~

--- All built-in components (|bareline.components|) are a |bareline.BareComponent|.
--- To create your own components, you can use this class or, more simply, follow
--- the alternate component types described in |bareline-custom-config|.
---
--- For examples on how to create a |bareline.BareComponent|, see the source code
--- of this plugin on the built-in components.

--- Standardized component.
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
--- Defines watcher configuration for a component.
--- With Bareline, you don't need a timer to have the statusline update when you
--- expect it to. Since there is no fixed redraw, the plugin needs a way to know
--- when to do a redraw. That knowledge is provided to Bareline in a per component
--- basis through this watcher configuration.
---@class BareComponentWatcher
---@field autocmd table Expects a table with the keys `event` and `opts`. These
--- values are passed as-is to |vim.api.nvim_create_autocmd()|.
---@field filepath string|function Filepath to watch. Alternatively, a function
--- which expects zero args can be provided to compute the filepath.

--- Constructor.
--- Parameters ~
--- {value} `function|string` As a function, it expects no args and returns a
--- single value of any type. As a string, is used as-is.
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

--- Retrieve the value of the component.
--- Return ~
--- `(string|nil)` Component value.
function bareline.BareComponent:get_value()
  local value = self.value
  if type(value) == "string" then return value end
  if type(value) == "function" then return value() end
  return nil
end

--- #delimiter
--- #tag bareline.components
--- Built-in components ~

--- Built-in components for use for |bareline.setup()|. These are all structured
--- as a |bareline.BareComponent|. User created components may have a simpler
--- structure. See |bareline-custom-config|.

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
    if vim.bo.filetype == "qf" then
      return "%t%{exists('w:quickfix_title')? ' '.w:quickfix_title : ''}"
    end
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
--- Displays the Git HEAD based on the cwd (|pwd|). Useful to show the Git branch.
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
        local git_dir = vim.fn.finddir(".git", (vim.uv.cwd() or "") .. ";")
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
bareline.components.file_path_relative_to_cwd = bareline.BareComponent:new(
  function ()
    local buf_name = vim.api.nvim_buf_get_name(0)
    -- Expression file paths.
    if buf_name == "" or vim.bo.filetype == "help" then return "%f" end
    -- Sanitized file paths.
    local path_relative_to_cwd, _ = string.gsub(
      buf_name, h.escape_lua_pattern(vim.fn.getcwd()) .. "/", "")
    local path_relative_to_cwd_sanitized =
      string.gsub(path_relative_to_cwd, "%%", "%%%0")
    -- Truncate at start if path is too long.
    return "%<" .. path_relative_to_cwd_sanitized
  end
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
    local diagnostic_count = vim.diagnostic.count(0)
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
--- Mockup: `181:43/329`
---@type BareComponent
bareline.components.position = bareline.BareComponent:new("%02l:%02c/%02L")

--- Current working directory.
--- When the current working directory (cwd) is the home dir, then `~` is shown.
--- Otherwise, the name of the directory is shown, excluding the path.
--- Mockup: `bareline.nvim`
---@type BareComponent
bareline.components.cwd = bareline.BareComponent:new(function()
  local cwd = vim.uv.cwd() or ""
  if cwd == os.getenv("HOME") then return "~" end
  return vim.fn.fnamemodify(cwd, ":t")
end)

-- Set module default config.
assign_default_config()

-- -----
--- #end

-- DRAW METHODS

h.draw_methods = {}

--- Draw distinct statuslines for active, inactive and plugin windows.
--- Relies on base |autocmd|s and user-supplied autocmds and file paths which are
--- watched using |uv_fs_event_t|s. The provided statuslines are handled in this
--- order by table index: [1] draw on the active window, [2] inactive window and
--- [3] plugin window (having precedence over the active window statusline).
---@param stl_window_active BareStatusline
---@param stl_window_inactive BareStatusline
---@param stl_window_plugin BareStatusline
function h.draw_methods.draw_active_inactive_plugin(
    stl_window_active, stl_window_inactive, stl_window_plugin)

  -- Create base autocmds.
  -- DOCS: Keep in sync with bareline-custom-config.
  vim.api.nvim_create_autocmd(
    {
      "BufNew", "BufEnter", "BufWinEnter", "WinEnter",
      "VimResume", "FocusGained", "DirChanged"
    },
    {
      group = h.draw_methods_augroup,
      callback = function()
        h.draw_statusline_if_plugin_window(
          stl_window_plugin,
          stl_window_active
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
          stl_window_plugin,
          stl_window_active
        )
      end,
    }
  )

  local statuslines = {
    stl_window_active, stl_window_inactive, stl_window_plugin }

  -- Create component-specific autocmds.
  h.create_bare_component_autocmds(statuslines, 2, function()
    h.draw_statusline_if_plugin_window(
      stl_window_plugin,
      stl_window_active
    )
  end)

  -- Create file watchers.
  vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
    group = h.draw_methods_augroup,
    callback = function ()
      h.start_uv_fs_events(statuslines, 2, function()
        h.draw_statusline_if_plugin_window(
          stl_window_plugin,
          stl_window_active
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
      if vim.o.laststatus == 3 then return end
      h.draw_statusline_if_plugin_window(
          stl_window_plugin,
          stl_window_inactive
        )
    end,
  })

  -- Initial draw. Useful when re-running `setup()` after Neovim's startup.
  h.draw_statusline_if_plugin_window(
    stl_window_plugin,
    stl_window_active
  )
end

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
    return bareline.BareComponent:new(component, {})
  end
  if type(component) == "table" then
    return bareline.BareComponent:new(component.value, (component.opts or {}))
  end
  return bareline.BareComponent:new(nil, {})
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

  local computed_value = bare_component:get_value()
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

h.draw_methods_augroup = vim.api.nvim_create_augroup("BarelineDrawMethods", {})

---@param bufnr integer The buffer number, as returned by |bufnr()|.
---@return boolean
function h.is_plugin_window(bufnr)
  local filetype = vim.bo[bufnr].filetype
  local special_non_plugin_filetypes = { nil, "", "help", "man" }
  local matched_filetype, _ = vim.filetype.match({ buf = bufnr })
  -- Although the quickfix and location lists are not plugin windows, using the
  -- plugin window format in these windows looks more sensible.
  if vim.bo.filetype == "qf" then return true end
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
      if type(filepath) == "function" then
        local filepath_found = filepath()
        if filepath_found == nil then return nil end
        return vim.fn.fnamemodify(filepath_found, ":p")
      end
    end)
    -- Remove duplicate filepaths and nil.
    :fold({}, function(acc, v)
      if v ~= nil and not vim.tbl_contains(acc, v) then table.insert(acc, v) end
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
    statuslines = { config.statuslines, "table" }
  }
  vim.validate {
    ["statuslines.active"] = { config.statuslines.active, "table" },
    ["statuslines.inactive"] = { config.statuslines.inactive, "table" },
    ["statuslines.plugin"] = { config.statuslines.plugin, "table" }
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
