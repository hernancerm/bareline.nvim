--: MODULE DEFINITION

local Bareline = {
  providers = {},
  components = {},
  formatters = {},
  draw_methods = {}
}
local H = {}

-- Module setup.
function Bareline.setup(config)
  Bareline.config = H.get_config_with_fallback(config)
  Bareline.config.draw_method(Bareline.config.statusline)
end

---Use distinct statuslines for active, inactive and plugin windows. Uses
---|bareline.draw_methods.draw_active_inactive_plugin|. This preset is inspired
---by Helix's default statusline. See: https://github.com/helix-editor/helix
---Mockups:
---
---Active window:    | NOR  lua/bareline.lua  [lua_ls]  [+]    H:2,W:4  spaces-2  (main)  42,21/50 |
---Inactive window:  |      lua/bareline.lua  [lua_ls]  [+]            H:2,W:4  spaces-2  42,21/50 |
---Plugin window:    | [Nvim Tree]                                                        28,09/33 |
-- TODO: Properly use this @usage.
-- ---@usage `require("bareline").presets.bare()`
local function apply_default_config()
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
end

--: PROVIDERS

---Returns the first char of the current Vim mode (see |mode()|). For
---block modes, two characters are returned, a "b" followed by the mode;
---currently, only `bv` for "block visual mode" and `bs` for "block select
---mode". The returned string has only lower case letters.
---@return string
function Bareline.providers.get_vim_mode()
  local function standardize_mode(character)
    if character == "" then return "bv" end
    if character == "" then return "bs" end
    return character:lower()
  end

  return standardize_mode(vim.fn.mode())
end

---Returns the Git HEAD. The file `.git/HEAD` is read and its first line
---is returned. If the current directory does not have a `.git` dir, an
---upwards search is performed. If the dir isn't found, then nil is
---returned.
---@return string|nil
function Bareline.providers.get_git_head()
  local git_dir = vim.fn.finddir(".git", ".;")
  return (git_dir ~= "" and vim.fn.readfile(git_dir .. "/HEAD")[1]) or nil
end

---Returns the names of the LSP servers attached to the current buffer.
---Example output: `{ "luals" }`
---@return table
function Bareline.providers.lsp_server_names()
  return vim.tbl_map(
    function (client)
      return client.name
    end,
    vim.lsp.get_clients({ bufnr = 0 })
  )
end

---Returns the diagnostics count of the current buffer by severity, where
---a lower index is a higher severity. Use numeric indices or the the
---keys in |vim.diagnostic.severity| to get the diagnostic count per
---severity.
---Example output: `{ 4, 1, 0, 1 }`
---@return table|nil
---@usage [[
---local bareline = require("bareline")
---local errors = bareline.components.providers.get_diagnostics()[1]
---print(errors) -- Output: 4
---@usage ]]
function Bareline.providers.get_diagnostics()
  if vim.fn.empty(vim.diagnostic.get(0)) == 1 then return nil end

  local diagnostics_per_severity = { 0, 0, 0, 0 }
  for _, diagnostic in ipairs(vim.diagnostic.get(0)) do
    diagnostics_per_severity[diagnostic.severity] =
        diagnostics_per_severity[diagnostic.severity] + 1
  end

  return diagnostics_per_severity
end

---Returns the file path of the current buffer relative to the current
---working directory (|:pwd|). If the file opened is not in this dir, then
---the absolute path is returned. This is meant to be used instead of the
---field `%f` (see 'statusline') for a more consistent experience.
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

--: FORMATTERS

---@param vim_mode string
---@return string _ The Vim mode in 3 characters, e.g. `NOR`, `INS`.
local function format_vim_mode(vim_mode)
  local mode_labels = {
    n = "nor",
    i = "ins",
    v = "vis",
    s = "sel",
    t = "ter",
    c = "cmd",
    r = "rep",
    bv = "vis",
    bs = "sel",
    ["!"] = "ext",
  }
  return mode_labels[vim_mode]:upper()
end

---@param git_head string|nil
---@return string|nil _ The Git HEAD surrounded by parentheses, e.g. `(main)`.
local function format_git_head(git_head)
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

---Return the formatted lsp server names, e.g. "[luals]".
---@param lsp_servers table
---@return string|nil
local function format_lsp_servers(lsp_servers)
  if lsp_servers == nil or vim.tbl_isempty(lsp_servers) then return nil end
  return "[" .. vim.fn.join(lsp_servers, ",") .. "]"
end

---Return the formatted diagnostics sorted by severity, e.g. "W:2,I:8".
---@return string|nil
---@param diagnostics_per_severity table|nil
local function format_diagnostics(diagnostics_per_severity)
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

-- TODO: This does not need to be public!
---Mask with a character. Useful for making a component invisible.
---@param format function
---@param mask string
---@return function
-- TODO: Properly use this @usage.
-- ---@usage [[
-- ---local invisible_vim_mode_component = {
-- ---  value = M.components.vim_mode.value,
-- ---  opts = {
-- ---    format = M.formatters.mask(
-- ---        M.components.vim_mode.opts.format, " ")
-- ---  }
-- ---}
-- ---@usage ]]
function Bareline.formatters.mask(format, mask)
  return function (built_std_component)
    if built_std_component == nil then return "" end
    return format(built_std_component):gsub(".", mask)
  end
end

--: COMPONENTS

---Standard component. All |bareline.components| are structured like this.
---@class BareComponent
---@field provider function|string|nil As a function, return string|nil.
---@field mask function Mask the component value with a char.
---@field opts BareComponentOpts|nil
Bareline.BareComponent = {}
Bareline.BareComponent["__index"] = Bareline.BareComponent

function Bareline.BareComponent:new(provider, opts)
  local std_component = {}
  setmetatable(std_component, self)
  std_component.provider = provider
  std_component.opts = opts
  return std_component
end

function Bareline.BareComponent:mask(char)
  local this = self
  return function()
    local component_value = H.build_user_supplied_component(this)
    if component_value == nil then return nil end
    return component_value:gsub(".", char)
  end
end

---The Vim mode in 3 characters.
---Mockups: `NOR`, `VIS`
---@type BareComponent
Bareline.components.vim_mode = Bareline.BareComponent:new(
  Bareline.providers.get_vim_mode,
  { format = format_vim_mode }
)

---When on a plugin window, the formatted name of the plugin window.
---Mockup: `[Nvim Tree]`
---@type StdComponent
Bareline.components.plugin_name = {
  provider = function()
    local plugin_file_type = {
      nvimtree = "Nvim Tree",
    }
    if plugin_file_type[vim.bo.filetype:lower()] then
      return string.format("[%s]", plugin_file_type[vim.bo.filetype:lower()])
    else
      return nil
    end
  end,
}

---The indent style on insert mode. Relies on 'expandtab' and 'tabstop'.
---Mockups: `spaces-2`, `tabs-4`
---@type StdComponent
Bareline.components.indent_style = {
  provider = function()
    local whitespace_type = "tabs"
    if vim.bo.expandtab then whitespace_type = "spaces" end
    return whitespace_type .. "-" .. vim.bo.tabstop
  end,
}

---Indicate when the file does not have an end of line (EOL) on its last
---line. Return `noeol` in this case, nil otherwise. This uses the option 'eol'.
---@type StdComponent
Bareline.components.end_of_line = {
  provider = function()
    if vim.bo.eol then return nil end
    return "noeol"
  end,
}

---The Git HEAD.
---Mockup: `(main)`
---@type StdComponent
Bareline.components.git_branch = {
  provider = Bareline.providers.get_git_head,
  opts = {
    format = format_git_head,
  },
}

---The LSP servers attached to the current buffer.
---Mockup: `[lua_ls]`
---@type StdComponent
Bareline.components.lsp_servers = {
  provider = Bareline.providers.lsp_server_names,
  opts = {
    format = format_lsp_servers,
  },
}

---The file path relative to the current working directory (|:pwd|).
---Mockup: `lua/bareline.lua`
---@type StdComponent
Bareline.components.get_file_path_relative_to_cwd = {
  provider = Bareline.providers.get_file_path_relative_to_cwd,
}
---The diagnostics of the current buffer.
---Mockup: `E:2,W:1`
---@type StdComponent
Bareline.components.diagnostics = {
  provider = Bareline.providers.get_diagnostics,
  opts = {
    cache_on_vim_modes = { "i" },
    format = format_diagnostics,
  },
}

---The current cursor position in the format: line,column/total-lines.
---Mockup: `181,43/329`
---@type StdComponent
Bareline.components.position = {
  provider = "%02l,%02c/%02L",
}

apply_default_config()

--: DRAW STATUSLINE

Bareline.draw_helpers = {}

---@param buffer integer The window number, as returned by |bufnr()|.
---@return boolean
function Bareline.draw_helpers.is_plugin_window(buffer)
  local plugin_file_types = {
    "nvimtree"
  }
  return vim.tbl_contains(plugin_file_types, vim.bo[buffer].filetype:lower())
end

---Assign the built statusline with |bareline.build_statusline| to the
---current window's 'statusline'.
---@param statusline BareStatusline
function Bareline.draw_helpers.draw_window_statusline(statusline)
  vim.wo.statusline = Bareline.build_statusline(statusline)
end

local draw_helpers_augroup = vim.api.nvim_create_augroup("BarelineDrawHelpers", {})

-- Cleanup components cache.
vim.api.nvim_create_autocmd({ "WinClosed" }, {
  group = draw_helpers_augroup,
  callback = function(event)
    local window = event.match
    H.component_cache_by_window_id[window] = nil
  end,
})

Bareline.draw_methods.augroup = vim.api.nvim_create_augroup("BarelineDrawMethods", {})
Bareline.draw_methods.timers = {}

---Stop the drawing of statuslines done by the draw methods provided by this
---plugin. Then, conditionally draw the default statusline on all windows on
---all tab pages.
---@param opts table|nil Optional parameters.
---• {default_statusline} (boolean) Draw the default
---  statusline on all windows.
function Bareline.draw_methods.stop_all(opts)
  if opts == nil or vim.tbl_isempty(opts) then
    opts = { default_statusline = true }
  end
  -- Clear all autocommands.
  vim.api.nvim_clear_autocmds({ group = Bareline.draw_methods.augroup })
  -- Stop all timers.
  for _, timer_id in ipairs(Bareline.draw_methods.timers) do
    vim.fn.timer_stop(timer_id)
  end
  -- Draw default statusline on all windows.
  if not opts.default_statusline then return end
  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    for _, window in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
      -- The statusline string is documented in the help page for 'statusline'. See
      -- the 'Examples' section, refer to the first example: "Emulate standard status
      -- line with 'ruler' set". TODO: Use 'nvim_eval_statusline' if/when it can
      -- return the default statusline, see:
      -- https://github.com/neovim/neovim/issues/28444
      vim.wo[window].statusline = "%<%f %h%m%r%=%-14.(%l,%c%V%) %P"
    end
  end
end

---Use distinct statuslines for active, inactive and plugin windows. The
---provided statuslines are handled in this order by table index: (1) drawn
---on the active window, (2) drawn on the inactive window and (3) drawn on
---the plugin window, having precedence over the active window statusline.
---@param statuslines BareStatusline[]
function Bareline.draw_methods.draw_active_inactive_plugin(statuslines)
  Bareline.draw_methods.stop_all({ draw_default_statusline = false })
  ---@type BareStatusline
  local active_window_statusline = statuslines[1]
  ---@type BareStatusline
  local inactive_window_statusline = statuslines[2]
  ---@type BareStatusline
  local plugin_window_statusline = statuslines[3]

  ---@param statusline_1 BareStatusline Statusline drawn when the current
  ---window is used by a plugin.
  ---@param statusline_2 BareStatusline Statusline drawn otherwise.
  local function draw_statusline_if_plugin_window(statusline_1, statusline_2)
    if Bareline.draw_helpers.is_plugin_window(vim.fn.bufnr()) then
      Bareline.draw_helpers.draw_window_statusline(statusline_1)
    else
      Bareline.draw_helpers.draw_window_statusline(statusline_2)
    end
  end

  -- Redraw statusline immediately to update specific components, e.g. the Vim
  -- mode. For plugin windows (e.g. nvim-tree), use a special statusline.
  vim.api.nvim_create_autocmd(
    { "ModeChanged", "DiagnosticChanged", "BufEnter" },
    {
      group = Bareline.draw_methods.augroup,
      callback = function()
        draw_statusline_if_plugin_window(
          plugin_window_statusline,
          active_window_statusline
        )
      end,
    }
  )

  vim.api.nvim_create_autocmd("OptionSet", {
      group = Bareline.draw_methods.augroup,
      pattern = "expandtab,tabstop,endofline,fileformat,formatoptions",
      callback = function()
        draw_statusline_if_plugin_window(
          plugin_window_statusline,
          active_window_statusline
        )
      end,
    }
  )

  -- Redraw statusline of active window to update components hard to watch,
  -- for example the Git branch.
  table.insert(Bareline.draw_methods.timers, vim.fn.timer_start(
      500,
      function()
        draw_statusline_if_plugin_window(
          plugin_window_statusline,
          active_window_statusline
        )
      end,
      { ["repeat"] = -1 }
    )
  )

  -- Draw a different statusline for inactive windows. For inactive plugin
  -- windows (e.g. nvim-tree), use a special statusline, the same one as for
  -- active plugin windows.
  vim.api.nvim_create_autocmd("WinLeave", {
    group = Bareline.draw_methods.augroup,
    callback = function()
      draw_statusline_if_plugin_window(
          plugin_window_statusline,
          inactive_window_statusline
        )
    end,
  })

  Bareline.draw_helpers.draw_window_statusline(active_window_statusline)
end

--: HELPERS > BUILD COMPONENTS

---• Function: Must return either a string or nil. The returned string is
---  what gets placed in the statusline. When nil is returned, the component
---  is skipped, leaving no gap.
---• String: The string is considered as if a function component had already
---  been executed and its output is the provided string. Handy for placing
---  statusline fields, for example `%f`.
---• |StdComponent|: Table which allows component configuration.
---@alias UserSuppliedComponent function|string|BareComponent

---Options to configure the building of a standard component. The option
---{cache_on_vim_modes} expects a list of Vim modes as per the first
---letter returned by |mode()|.
---@class BareComponentOpts
---@field format function|nil As a function, return string|nil.
---@field cache_on_vim_modes table|nil Use cache in these Vim modes.

---The standard component built into a string or nil.
---@alias ComponentValue string|nil

---@private
---@class ComponentValueCache Cache of a built component.
---@field value string|nil Component cache value.

H.component_cache_by_window_id = {}

---@param std_component table
---@return ComponentValueCache|nil
function H.get_component_cache(std_component)
  local win_id = vim.fn.win_getid()
  if H.component_cache_by_window_id[win_id] == nil then return nil end
  return H.component_cache_by_window_id[win_id][tostring(std_component.value)]
end

---@param bare_component BareComponent
---@param bare_component_built ComponentValue
function H.store_std_component_cache(bare_component, bare_component_built)
  local win_id = vim.fn.win_getid()
  if H.component_cache_by_window_id[win_id] == nil then
    H.component_cache_by_window_id[win_id] = {}
  end
  H.component_cache_by_window_id[win_id][tostring(bare_component.provider)] =
    { provider = bare_component_built }
end

---@param bare_component BareComponent
---@return any
function H.build_bare_component(bare_component)
  local provider = bare_component.provider
  if type(provider) == "string" then return provider end
  if type(provider) == "function" then return provider() end
  return nil
end

---@param component UserSuppliedComponent
---@return BareComponent
function H.standardize_component(component)
  if type(component) == "function" or type(component) == "string" then
    return { provider = component, opts = {} }
  end
  if type(component) == "table" then
    component.opts = component.opts or {}
    return component
  end
  vim.api.nvim_echo({
    { "Provided statusline component is not a string, function or table.", "Error" },
  }, true, {})
  return {}
end

---Use this function to get the built value of components from |bareline.components|.
---@param component UserSuppliedComponent
---@return ComponentValue
function H.build_user_supplied_component(component)
  ---@type BareComponent
  local bare_component = H.standardize_component(component)
  ---@type ComponentValueCache|nil
  local component_cache = H.get_component_cache(bare_component)
  ---@type BareComponentOpts
  local opts = bare_component.opts

  if opts.cache_on_vim_modes and component_cache then
    local is_cache_vim_mode = vim.fn.mode():lower():match(
      string.format("[%s]", table.concat(opts.cache_on_vim_modes, ""))
    )
    if is_cache_vim_mode then return component_cache.value end
  end

  local built_component = H.build_bare_component(bare_component)
  if opts.format then built_component = opts.format(built_component) end
  H.store_std_component_cache(bare_component, built_component)

  return built_component
end

--: HELPERS > BUILD SECTIONS

local component_separator = "  "

---@alias BareSection UserSuppliedComponent[]
---@alias BareStatusline BareSection[]

---@param section table Statusline section, as may be provided by a user.
---@return string At least one component is expected to be built into a non-nil value.
local function build_section(section)
  local built_components = {}
  for _, component in ipairs(section) do
    table.insert(built_components, H.build_user_supplied_component(component))
  end
  return table.concat(
    vim.tbl_filter(function(built_component) return built_component ~= nil end, built_components),
    component_separator
  )
end

--: HELPERS > BUILD STATUSLINE

---Use this function when implementing a custom draw method.
---See |bareline.draw_methods|.
---@param sections table
---@return string _ String assignable to 'statusline'.
function Bareline.build_statusline(sections)
  local built_sections = {}
  for _, section in ipairs(sections) do
    table.insert(built_sections, build_section(section))
  end
  return string.format(" %s ", table.concat(built_sections, "%="))
end

--: HELPERS

function H.get_default_config()
  return vim.deepcopy(Bareline.config)
end

---Merge user-supplied config with the plugin's default config. For every key which is not supplied
---by the user, the value in the default config will be used. The user's config has precedence.
---@return table
function H.get_config_with_fallback(config)
  vim.validate { config = { config, "table", true } }
  config = vim.tbl_deep_extend("force", H.get_default_config(), config)
  vim.validate {
    draw_method = { config.draw_method, "function" },
    statusline = { config.statusline, "table" }
  }
  return config
end

---Given a string, escape the Lua magic pattern characters so that the string
---can be used as a Lua pattern for an exact match, e.g. as the pattern supplied
---to 'string.gsub'. Reference: https://www.lua.org/manual/5.1/manual.html#5.4.1
---@param string string
---@return string
function H.escape_lua_pattern(string)
  local special_chars = {
    "%", "(", ")", ".", "+", "-", "*", "?", "[", "]", "^", "$" }
  for _, special_char in ipairs(special_chars) do
    string, _ = string.gsub(string, "%" .. special_char, "%%" .. special_char)
  end
  return string
end

-- Export module.
return Bareline
