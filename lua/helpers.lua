-- BUILD

local H = {}

--- - Function: Must return either a string or nil. The returned string is
---   what gets placed in the statusline. When nil is returned, the component
---   is skipped, leaving no gap.
--- - String: The string is considered as if a function component had already
---   been executed and its output is the provided string. Handy for placing
---   statusline fields, for example `%f`.
--- - |StdComponent|: Table which allows component configuration.
---@alias UserSuppliedComponent function|string|BareComponent

--- Options to configure the building of a standard component. The option
---{ cache_on_vim_modes} expects a list of Vim modes as per the first
--- letter returned by |mode()|.
---@class BareComponentOpts
---@field format function|nil As a function, return string|nil.
---@field cache_on_vim_modes table|nil Use cache in these Vim modes.

--- The standard component built into a string or nil.
---@alias ComponentValue string|nil

---@class ComponentValueCache Cache of a built component.
---@field value string|nil Component cache value.

H.component_cache_by_win_id = {}

---@param bare_component table
---@return ComponentValueCache|nil
function H.get_component_cache(bare_component)
  local win_id = vim.fn.win_getid()
  if H.component_cache_by_win_id[win_id] == nil then return nil end
  return H.component_cache_by_win_id[win_id][tostring(bare_component.provider)]
end

---@param bare_component BareComponent
---@param bare_component_built ComponentValue
function H.store_bare_component_cache(bare_component, bare_component_built)
  local win_id = vim.fn.win_getid()
  if H.component_cache_by_win_id[win_id] == nil then
    H.component_cache_by_win_id[win_id] = {}
  end
  H.component_cache_by_win_id[win_id][tostring(bare_component.provider)] =
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
    {
      "Provided statusline component is not a string, function or table.",
      "Error"
    },
  }, true, {})
  return {}
end

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
  H.store_bare_component_cache(bare_component, built_component)

  return built_component
end

H.component_separator = "  "

---@alias BareSection UserSuppliedComponent[]
---@alias BareStatusline BareSection[]

--- At least one component is expected to be built into a non-nil value.
---@param section table Statusline section, as may be provided by a user.
---@return string
function H.build_section(section)
  local built_components = {}
  for _, component in ipairs(section) do
    table.insert(built_components, H.build_user_supplied_component(component))
  end
  return table.concat(
    vim.tbl_filter(function(built_component)
      return built_component ~= nil
    end,
    built_components),
    H.component_separator
  )
end

--- Use this function when implementing a custom draw method.
--- See |bareline.draw_methods|.
---@param sections table
---@return string _ String assignable to 'statusline'.
function H.build_statusline(sections)
  local built_sections = {}
  for _, section in ipairs(sections) do
    table.insert(built_sections, H.build_section(section))
  end
  return string.format(" %s ", table.concat(built_sections, "%="))
end

-- DRAW

H.draw_methods_augroup = vim.api.nvim_create_augroup("BarelineDrawMethods", {})

---@param buffer integer The window number, as returned by |bufnr()|.
---@return boolean
function H.is_plugin_window(buffer)
  local plugin_file_types = {
    "nvimtree"
  }
  return vim.tbl_contains(plugin_file_types, vim.bo[buffer].filetype:lower())
end

---@param statusline BareStatusline
function H.draw_window_statusline(statusline)
  vim.wo.statusline = H.build_statusline(statusline)
end

H.draw_helpers_augroup = vim.api.nvim_create_augroup("BarelineDrawHelpers", {})

-- Cleanup components cache.
vim.api.nvim_create_autocmd({ "WinClosed" }, {
  group = H.draw_helpers_augroup,
  callback = function(event)
    local window = event.match
    H.component_cache_by_win_id[window] = nil
  end,
})

-- OTHER

--- Merge user-supplied config with the plugin's default config. For every key
--- which is not supplied by the user, the value in the default config will be
--- used. The user's config has precedence; the default config is the fallback.
---@param config table User supplied config.
---@param default_config table Bareline's default config.
---@return table
function H.get_config_with_fallback(config, default_config)
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
function H.escape_lua_pattern(string)
  string, _ = string:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0")
  return string
end

return H
