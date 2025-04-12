--- *bareline* A statusline plugin for the pragmatic.
---
--- MIT License Copyright (c) 2024 Hernán Cervera.
---
--- Contents:
---
--- 1. Introduction                                          |bareline-introduction|
--- 2. Configuration                                        |bareline-configuration|
--- 3. Item structure                                      |bareline-item-structure|
--- 4. Custom items                                          |bareline-custom-items|
--- 5. Built-in items                                      |bareline-built-in-items|
--- 6. Built-in alt statuslines                  |bareline-built-in-alt-statuslines|
--- 7. Vimscript functions                            |bareline-vimscript-functions|
--- 8. Functions                                                |bareline-functions|
---
--- ==============================================================================
--- #tag bareline-introduction
--- Introduction ~
---
--- Goals
---
--- 1. Simple configuration.
--- 2. Batteries included experience.
--- 3. No timer. The statusline is updated immediately as changes happen.
---
--- Design
---
--- Bareline takes this approach to statusline configuration:
---
--- 1. The statusline DSL ('statusline') is not abstracted away from the user.
---    See: |bareline.config.statusline.value|.
--- 2. Helper functions are provided to improve the experience of using the DSL.
---    See: |bareline-vimscript-functions|.
--- 3. The plugin exposes "statusline items", which group of a buf-local var, a
---    callback which sets the var, and autocmds firing the callback.
---    See: |bareline.item-structure|.
--- 4. When using any buf-local var in the statusline, reference it either
---    directly (`%{b:foo}`) or with a `get` call, `%{get(b:,'foo','')}`. This is
---    so the stl is updated by Nvim immediately when the vars are updated.
---
--- With this design, all Bareline items are asynchronous.

-- MODULE SETUP

local bareline = {}
local h = {}

--- Quickstart
---
--- To enable the plugin you need to call the |bareline.setup()| function. To use
--- the defaults, call it without arguments:
--- >lua
---   require("bareline").setup()
---   vim.o.showmode = false -- Optional.
--- <

--- Module setup.
---@param config table? Merged with the default config (|bareline.default_config|)
--- and the former takes precedence on duplicate keys.
function bareline.setup(config)
  -- Cleanup.
  if #vim.api.nvim_get_autocmds({ group = h.statusline_augroup }) > 0 then
    vim.api.nvim_clear_autocmds({ group = h.statusline_augroup })
  end
  h.existent_item_autocmds = {}
  if #vim.api.nvim_get_autocmds({ group = h.item_augroup }) > 0 then
    vim.api.nvim_clear_autocmds({ group = h.item_augroup })
  end

  -- Merge user and default configs.
  bareline.config = h.get_config_with_fallback(config, bareline.default_config)

  -- Logger setup.
  if bareline.config.logging.enabled then
    vim.fn.mkdir(vim.fn.fnamemodify(h.state.log_filepath, ":h"), "p")
  end

  -- Assign the statusline for the active window.
  vim.api.nvim_create_autocmd({
    "BufNew",
    "BufEnter",
    "BufWinEnter",
    "FocusGained",
    "DirChanged",
    "VimResume",
    "TermLeave",
    "WinEnter",
  }, {
    group = h.statusline_augroup,
    callback = function()
      vim.b._bareline_is_buf_active = true
      bareline.refresh_statusline()
    end,
  })

  -- The window where `bareline.setup()` is run is considered active.
  vim.b._bareline_is_buf_active = true

  -- Assign the initial values for the BareItem buf-local vars.
  vim.api.nvim_create_autocmd("BufEnter", {
    callback = function()
      for _, item in ipairs(bareline.config.statusline.items) do
        item.callback(item.var, item.opts)
      end
      for _, statusline in ipairs(bareline.config.alt_statuslines) do
        if type(statusline.items) == "table" then
          for _, item in ipairs(statusline.items) do
            item.callback(item.var, item.opts)
          end
        end
      end
    end,
  })

  -- Create `BareItem` autocmds.
  -- Currently buf-local autocmds cannot have a pattern, so at the moment the user
  -- "pays" on EACH buf for ALL their items across the base + alt statuslines.
  for _, item in ipairs(bareline.config.statusline.items) do
    h.create_item_autocmds(item)
  end
  for _, statusline in ipairs(bareline.config.alt_statuslines) do
    if type(statusline.items) == "table" then
      for _, item in ipairs(statusline.items) do
        h.create_item_autocmds(item)
      end
    end
  end

  -- Assign a different statusline for inactive windows.
  vim.api.nvim_create_autocmd("BufLeave", {
    group = h.statusline_augroup,
    callback = function()
      if vim.o.laststatus == 3 then
        return
      end
      vim.b._bareline_is_buf_active = false
      bareline.refresh_statusline()
    end,
  })

  -- Initial statusline assingment.
  if vim.v.vim_did_enter == 1 then
    bareline.refresh_statusline()
  end

  -- Gitsigns integration.
  if pcall(require, "gitsigns") then
    vim.api.nvim_create_autocmd("User", {
      group = h.statusline_augroup,
      pattern = "GitSignsUpdate",
      callback = function()
        bareline.refresh_statusline()
      end,
    })
  end
end

--- #delimiter
--- #tag bareline.config
--- #tag bareline.default_config
--- #tag bareline-configuration
--- Configuration ~

--- The merged config (defaults with user overrides) is in `bareline.config`. The
--- default config is available in `bareline.default_config`.
---
--- Below is the default config, where `bareline` equals `require("bareline")`.
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
--minidoc_replace_start
local function assign_default_config()
  --minidoc_replace_end
  --minidoc_replace_start {
  bareline.default_config = {
    --minidoc_replace_end
    statusline = {
      value = "%{BlIs(1)}"
        .. "%{BlInahide(get(b:,'bl_vim_mode',''))}"
        .. "%{BlIs(1)}"
        .. "%<"
        .. "%{BlPad(get(b:,'bl_filepath',''))}"
        .. "%{BlPad(get(b:,'bl_lsp_servers',''))}"
        .. "%{%BlPad(get(b:,'bl_mhr',''))%}"
        .. "%="
        .. "%{BlPad(get(b:,'bl_diagnostics',''))}"
        .. "%{BlPad(get(b:,'bl_end_of_line',''))}"
        .. "%{BlPad(get(b:,'bl_indent_style',''))}"
        .. "%{BlInarm(BlPad(BlWrap(get(b:,'gitsigns_head',''),'(',')')))}"
        .. "%{BlPad(get(b:,'bl_current_working_dir',''))}"
        .. "%{BlIs(1)}"
        .. "%02l:%02c/%02L"
        .. "%{BlIs(1)}",
      items = {
        bareline.items.vim_mode,
        bareline.items.filepath,
        bareline.items.lsp_servers,
        bareline.items.mhr,
        bareline.items.diagnostics,
        bareline.items.end_of_line,
        bareline.items.indent_style,
        bareline.items.current_working_dir,
      },
    },
    alt_statuslines = {
      bareline.alt_statuslines.plugin,
    },
    items = {
      mhr = {
        display_modified = true,
      },
    },
    logging = {
      enabled = false,
      level = vim.log.levels.INFO,
    },
  }
  --minidoc_afterlines_end
end

--- #tag bareline.config.statusline
--- The main statusline. Use |bareline-built-in-items| here.
---
--- #tag bareline.config.statusline.value
---     {value} `(string)`
---       String directly assigned to window local 'statusline'.
---
--- #tag bareline.config.statusline.items
---     {items} `(BareItem[])`
---       What you are "paying" for in `value`. List here the |bareline.BareItem|s
---       in use. This is used by Bareline to keep the statusline always showing
---       up to date values. Failing to do this can lead to seeing values not
---       being updated.
---
--- #tag bareline.config.alt_statuslines
--- Alternate statuslines to |bareline.config.statusline|. These can be used to
--- assign a different statusline on windows that meet some criteria. For example,
--- Bareline internally uses this feature to assign a different statusline for
--- plugin windows (e.g., nvim-tree). This list is traversed in order and the
--- first statusline which `predicate` returns true is used.
--- See: |bareline-built-in-alt-statuslines|.

--- #tag bareline.config.items
--- The item options set in |bareline.BareItem:new()| are merged with these opts.
--- The options here have precedence.
---
--- #tag bareline.config.items.mhr
---     {mhr} `(boolean|fun():boolean)`
---       See |bareline.items.mhr|.

--- #tag bareline.config.logging
--- Log file location: |$XDG_DATA_HOME|`/bareline.nvim/bareline.log`.
---
--- #tag bareline.config.logging.enabled
---     {enabled} `(boolean)`
---       Whether to write to the log file. Default: false.
---
--- #tag bareline.config.logging.level
---     {level} `(integer)`
---       Log statements on this level and up are written to the log file, the
---       others are discarded. Default: `vim.log.levels.INFO`.

--- #delimiter
--- #tag bareline-item-structure
--- Item structure ~
---
--- All custom and built-in items are a |bareline.BareItem|. See:
--- * |bareline-custom-items|.
--- * |bareline-built-in-items|.

--- Statusline item.
---@class BareItem
---@field var string Name of buf-local var holding the value of the item. The
--- value is set directly by `callback`.
---@field callback fun(var:string, opts:BareItemCommonOpts) Sets `var`. The option
--- `autocmds` (|bareline.BareItemCommonOpts|) decides when the
--- callback is called. To improve performance on intensive workloads, consider
--- distributing the processing among several event loop cycles. Common ways to
--- do this are using the async form of |vim.system| and |vim.defer_fn()|.
---@field opts BareItemCommonOpts
bareline.BareItem = {}
bareline.BareItem["__index"] = bareline.BareItem

--- #tag bareline-BareItemCommonOpts
--- Options applicable to any |bareline.BareItem|.
---@class BareItemCommonOpts
---@field autocmds table[]? Expects tables each with the keys
--- `event` and `opts`, which are used for: |vim.api.nvim_create_autocmd()|.

--- Constructor.
---@param var string
---@param callback fun(buf_var_name:string, opts:BareItemCommonOpts)
---@param opts BareItemCommonOpts
---@return BareItem
function bareline.BareItem:new(var, callback, opts)
  local item = {}
  setmetatable(item, self)
  item.var = var
  item.callback = callback
  item.opts = opts
  return item
end

--- Update item opts.
---@param opts table The field `opts` from |bareline.BareItem| is merged with
--- these opts. For built-in items, the option keys here have priority over what
--- is set in both the constructor and at the plugin setup. Built-in items have
--- their custom options documented, which can be set or overriden using this
--- method. For an example, see |bareline.items.mhr|.
---@return BareItem
function bareline.BareItem:config(opts)
  local item_copy = vim.deepcopy(self)
  item_copy.opts =
    vim.tbl_deep_extend("force", vim.deepcopy(item_copy.opts), opts or {})
  return item_copy
end

--- #delimiter
--- #tag bareline-custom-items
--- Custom items ~
---
--- All custom items are a |bareline.BareItem|. Example item indicating soft wrap:
--- >lua
---   local item_soft_wrap = bareline.BareItem:new(
---     "bl_soft_wrap",
---     function(var)
---       local label = nil
---       if vim.wo.wrap then
---         label = "s-wrap"
---       end
---       vim.b[var] = label
---     end, {
---     -- The autocmds need to account for all the cases where the value of the
---     -- buf-local var indicatd by `var` would change, so the statusline does
---     -- not show a stale value.
---     autocmds = {
---       {
---         event = "OptionSet",
---         opts = { pattern = "wrap" }
---       }
---     }
---   })
--- <
--- Use it:
--- >lua
---   require("bareline").setup({
---     statuslines = {
---       active = {
---         statusline = "%{get(b:,'bl_soft_wrap','')}",
---         items = {
---           -- IMPORTANT: Do not forget to add the item in the `items` list,
---           -- otherwise the value won't be updated as expected.
---           item_soft_wrap,
---         },
---       },
---     },
---   })
--- >

-- ITEMS

bareline.items = {}

--- #delimiter
--- #tag bareline-built-in-items
--- Built-in items ~

--- All built-in items are a |bareline.BareItem|.

--- Vim mode.
--- The Vim mode in 3 characters.
--- Mockups: `NOR`, `VIS`
---@type BareItem
bareline.items.vim_mode = bareline.BareItem:new("bl_vim_mode", function(var)
  local vim_mode = h.providers.vim_mode.get_mode()
  local mode_labels = {
    n = "nor",
    i = "ins",
    v = "v:c",
    vl = "v:l",
    vb = "v:b",
    s = "s:c",
    sb = "s:b",
    t = "ter",
    c = "cmd",
    r = "rep",
    ["!"] = "ext",
  }
  vim.b[var] = mode_labels[vim_mode]:upper()
end, {
  autocmds = {
    {
      event = { "ModeChanged", "TermLeave" },
    },
  },
})

--- Plugin name.
--- When on a plugin window, the formatted name of the plugin window.
--- Mockup: `[nvimtree]`
---@type BareItem
bareline.items.plugin_name = bareline.BareItem:new("bl_plugin_name", function(var)
  if vim.bo.filetype == "qf" then
    vim.b[var] = "%t%{exists('w:quickfix_title') ? ' '.w:quickfix_title : ''}"
  else
    vim.b[var] = string.format("[%s]", vim.bo.filetype:lower():gsub("%s", ""))
  end
end, {
  autocmds = {
    {
      event = "BufEnter",
    },
  },
})

--- Indent style.
--- Relies on 'expandtab' and 'tabstop'. Omitted when the buf is 'nomodifiable'.
--- Mockups: `spaces:2`, `tabs:4`
---@type BareItem
bareline.items.indent_style = bareline.BareItem:new(
  "bl_indent_style",
  function(var)
    if not vim.bo.modifiable then
      vim.b[var] = nil
    end
    local whitespace_type = (vim.bo.expandtab and "spaces") or "tabs"
    vim.b[var] = whitespace_type .. ":" .. vim.bo.tabstop
  end,
  {
    autocmds = {
      {
        event = "OptionSet",
        opts = {
          pattern = "modifiable,expandtab,tabstop",
        },
      },
    },
  }
)

--- End of line (EOL).
--- Indicates when the buffer does not have an EOL on its last line. Return `noeol`
--- in this case, nil otherwise. This uses the option 'eol'.
---@type BareItem
bareline.items.end_of_line = bareline.BareItem:new("bl_end_of_line", function(var)
  if vim.bo.endofline then
    vim.b[var] = nil
  else
    vim.b[var] = "noeol"
  end
end, {
  autocmds = {
    {
      event = "OptionSet",
      opts = {
        pattern = "endofline",
      },
    },
  },
})

--- LSP servers.
--- The LSP servers attached to the current buffer.
--- Mockup: `[lua_ls]`
---@type BareItem
bareline.items.lsp_servers = bareline.BareItem:new("bl_lsp_servers", function(var)
  h.providers.lsp_servers.get_names(function(lsp_servers)
    if lsp_servers == nil or vim.tbl_isempty(lsp_servers) then
      vim.b[var] = nil
    else
      vim.b[var] = "[" .. vim.fn.join(lsp_servers, ",") .. "]"
    end
  end)
end, {
  autocmds = {
    {
      event = { "LspAttach", "LspDetach" },
    },
  },
})

--- Stable `%f`.
--- If the file is in the cwd (|:pwd|) at any depth level, the filepath relative
--- to the cwd is displayed. Otherwise, the full filepath is displayed.
--- Mockup: `lua/bareline.lua`
---@type BareItem
bareline.items.filepath = bareline.BareItem:new("bl_filepath", function(var)
  local buf_name = vim.api.nvim_buf_get_name(0)
  if buf_name == "" or vim.bo.filetype == "help" then
    vim.b[var] = vim.api.nvim_eval_statusline("%f", {}).str
    return
  end
  local cwd = vim.uv.cwd() .. ""
  if cwd ~= h.state.system_root_dir then
    cwd = cwd .. h.state.fs_sep
  end
  vim.b[var] = h.replace_prefix(
    h.replace_prefix(buf_name, cwd, ""),
    vim.uv.os_homedir() or "",
    "~"
  )
end, {
  autocmds = {
    {
      event = {
        "BufAdd",
        "BufEnter",
        "VimResume",
        "BufWinEnter",
        "CmdlineLeave",
        "FocusGained",
        "TermLeave",
      },
    },
  },
})

--- Diagnostics.
--- The diagnostics of the current buffer. Respects the value of:
--- `update_in_insert` from |vim.diagnostic.config()|.
--- Mockup: `e:2,w:1`
---@type BareItem
bareline.items.diagnostics = bareline.BareItem:new("bl_diagnostics", function(var)
  local output = ""
  local severity_labels = { "e", "w", "i", "h" }
  local diagnostic_count = vim.diagnostic.count(0)
  for i = 1, 4 do
    local count = diagnostic_count[i]
    if count ~= nil then
      output = output .. severity_labels[i] .. ":" .. count .. ","
    end
  end
  if output == "" then
    vim.b[var] = nil
  end
  vim.b[var] = string.sub(output, 1, #output - 1)
end, {
  autocmds = {
    {
      event = "DiagnosticChanged",
    },
  },
})

--- Current working directory (cwd).
--- The tail of the current working directory.
--- Mockup: `bareline.nvim`
---@type BareItem
bareline.items.current_working_dir = bareline.BareItem:new(
  "bl_current_working_dir",
  function(var)
    local cwd_tail = nil
    local cwd = vim.uv.cwd() or ""
    if cwd == vim.uv.os_homedir() then
      cwd_tail = "~"
    elseif cwd == h.state.system_root_dir then
      cwd_tail = h.state.system_root_dir
    else
      cwd_tail = vim.fn.fnamemodify(cwd, ":t")
    end
    vim.b[var] = cwd_tail
  end,
  {
    autocmds = {
      {
        event = {
          "DirChanged",
        },
      },
    },
  }
)

--- %m%h%r
--- Display the modified, help and read-only markers using the built-in statusline
--- fields, see 'statusline' for a list of fields where these are included.
---
--- Custom options:
---     {display_modified} `(boolean|fun():boolean)`
--- Control when the modified field (`%m`) is included. When `true`, the field is
--- always displayed except when the buf has set 'nomodifiable'. Default: true.
---
--- Mockups: `[+]`, `[Help][RO]`
---@type BareItem
bareline.items.mhr = bareline.BareItem:new("bl_mhr", function(var, opts)
  local display_modified = h.providers.mhr.get_opt_display_modified(opts)
  if type(display_modified) == "function" then
    display_modified = display_modified()
  end
  local value = "%h%r"
  if display_modified and vim.bo.modifiable then
    value = "%m" .. value
  end
  vim.b[var] = value
end, {
  autocmds = {
    {
      event = {
        "OptionSet",
      },
      opts = {
        pattern = "modifiable,filetype,readonly",
      },
    },
  },
})

-- ALT STATUSLINES

bareline.alt_statuslines = {}

--- #delimiter
--- #tag bareline-built-in-alt-statuslines
--- Built-in alt statuslines ~
---
--- All custom ad built-in alt stls are structured as a `BarelineAltStatusline`.

---@class BarelineAltStatusline
---@field value string Value for 'statusline'.
---@field items BareItem[] List of bare items.
---@field predicate (fun():boolean)? When it returns true, this stl is used.
--- Caveat: Statuslines as defined like this are meant to be used in the config
--- key |bareline.config.alt_statuslines|, which accepts a list. The list gets
--- walked in order to find a match. The first one returning true is taken.

--- Statusline for plugin windows, including the plugin name.
---@type BarelineAltStatusline
bareline.alt_statuslines.plugin = {
  value = "%{BlIs(1)}"
    .. "%{%get(b:,'bl_plugin_name','')%}"
    .. "%="
    .. "%02l:%02c/%02L"
    .. "%{BlIs(1)}",
  items = {
    bareline.items.plugin_name,
  },
  predicate = function()
    return h.is_plugin_window(0)
  end,
}

--- #delimiter
--- #tag bareline-vimscript-functions
--- Vimscript functions ~
---
--- The functions in this section have the goal of facilitating writing the value
--- for |bareline.config.statusline.value| (i.e., 'statusline'). So the functions
--- are intended to be used in the statusline string.

--- #tag BlIs()
--- BlIs(length)
--- Invisible space. Returns a {length} amount of Unicode Thin Space (U+2009)
--- chars. This is useful to control empty space in the statusline, since ASCII
--- whitespace is sometimes trimmed by Neovim, while this Unicode char is not.
--- Params:
--- * {length} `(string)` Amount of consecutive U+2009 chars to return.
vim.cmd([[
function! BlIs(length)
  let u2009_chars = ''
  for i in range(1, a:length)
    " Unicode Thin Space (U+2009)
    let u2009_chars .= ' '
  endfor
  return u2009_chars
endfunction
]])

--- #tag BlIna()
--- BlIna(value,mapper)
--- Inactive. Maps {value} via the funcref {mapper}. Used to transform how a
--- value appears in statuslines in inactive windows.
--- Params:
--- * {value} `(string)` Any.
--- * {mapper} `(Funcref)` Takes `{value}` as its single arg.
vim.cmd([[
function! BlIna(value,mapper)
  if get(b:, '_bareline_is_buf_active', v:false)
    return a:value
  else
    return a:mapper(a:value)
  endif
endfunction
]])

--- #tag BlInarm()
--- BlInarm(value)
--- Inactive remove. Remove the value on inactive windows.
--- Params:
--- * {value} `(string)` Any.
vim.cmd([[
function! BlInarm(value)
  return BlIna(a:value, { -> '' })
endfunction
]])

--- #tag BlInahide()
--- BlInahide(value)
--- Inactive hide. Mask with whitespace the value on inactive windows.
--- Params:
--- * {value} `(string)` Any.
vim.cmd([[
function! BlInahide(value)
  return BlIna(a:value, { v -> BlIs(strlen(v)) })
endfunction
]])

--- #tag BlPadl()
--- BlPadl(value)
--- Pad {value} left with `BlIs(1)`.
--- Params:
--- * {value} `(string)` Any.
vim.cmd([[
function! BlPadl(value)
  if a:value !=# ''
    return BlIs(1) . a:value
  endif
  return ''
endfunction
]])

--- #tag BlPadr()
--- BlPadr(value)
--- Pad {value} right with `BlIs(1)`.
--- Params:
--- * {value} `(string)` Any.
vim.cmd([[
function! BlPadr(value)
  if a:value !=# ''
    return a:value . BlIs(1)
  endif
  return ''
endfunction
]])

--- #tag BlPad()
--- BlPad(value)
--- Pad {value} on both left and right with `BlIs(1)`.
--- Params:
--- * {value} `(string)` Any.
vim.cmd([[
function! BlPad(value)
  return BlPadr(BlPadl(a:value))
endfunction
]])

--- #tag BlWrap()
--- BlWrap(value,prefix,suffix)
--- Wrap {value} around {prefix} and {suffix}. Example function usage to wrap with
--- parentheses the Git HEAD returned by the plugin gitsigns:
--- `BlWrap(get(b:,'gitsigns_head',''),'(',')')`
--- Params:
--- * {value} `(string)` Any.
--- * {prefix} `(string)` Any.
--- * {suffix} `(string)` Any.
vim.cmd([[
function! BlWrap(value,prefix,suffix)
  if a:value !=# ''
    return a:prefix . a:value . a:suffix
  endif
  return ''
endfunction
]])

--- #delimiter
--- #tag bareline-functions
--- Functions ~

--- Reassign the proper value to the window local 'statusline'. Use this to
--- integrate with plugins which provide statusline integration through buf-local
--- vars and user autocmds.
---
--- For example, consider the integration with the plugin gitsigns. By default,
--- Bareline provides this out of the box. If it were not provided, this is how a
--- user could define it themselves:
--- >lua
---   vim.api.nvim_create_autocmd("User", {
---     group = h.statusline_augroup,
---     pattern = "GitSignsUpdate",
---     callback = function()
---       bareline.refresh_statusline()
---     end,
---   })
--- <
function bareline.refresh_statusline()
  local statusline_to_assign = bareline.config.statusline
  for _, statusline in ipairs(bareline.config.alt_statuslines) do
    if statusline.predicate() then
      statusline_to_assign = statusline
    end
  end
  h.draw_window_statusline(statusline_to_assign.value)
end

-- Set module default config.
assign_default_config()

-- -----
--- #end

-- PROVIDERS

h.providers = {}

h.providers.vim_mode = {}

--- Vim mode.
---@return string
function h.providers.vim_mode.get_mode()
  local function standardize_mode(character)
    if character == "V" then
      return "vl"
    end
    if character == "" then
      return "vb"
    end
    if character == "" then
      return "sb"
    end
    return character:lower()
  end
  return standardize_mode(vim.fn.mode())
end

h.providers.lsp_servers = {}

---@param callback fun(lsp_servers:string[]) Example `lsp_servers`: `{"lua_ls"}`.
function h.providers.lsp_servers.get_names(callback)
  vim.defer_fn(function()
    local lsp_servers = vim.tbl_map(function(client)
      return client.name
    end, vim.lsp.get_clients({ bufnr = 0 }))
    callback(lsp_servers)
  end, 0)
end

h.providers.mhr = {}

--- Retrieve all, pick with highest precedence, validate, return.
---@param opts table `opts` field of the item.
---@return boolean Valid option value.
function h.providers.mhr.get_opt_display_modified(opts)
  local display_modified = opts.display_modified
  if display_modified == nil then
    display_modified = bareline.config.items.mhr.display_modified
  end
  vim.validate(
    "opts.display_modified",
    display_modified,
    { "boolean", "function" }
  )
  return display_modified
end

-- OTHER

h.statusline_augroup = vim.api.nvim_create_augroup("BarelineSetStatusline", {})
h.item_augroup = vim.api.nvim_create_augroup("BarelineCallItemCallback", {})

---@param bufnr integer The buffer number, as returned by |bufnr()|.
---@return boolean
function h.is_plugin_window(bufnr)
  local filetype = vim.bo[bufnr].filetype
  local special_non_plugin_filetypes = { nil, "", "help", "man" }
  local matched_filetype, _ = vim.filetype.match({ buf = bufnr })
  -- Although the quickfix and location lists are not plugin windows, using the
  -- plugin window format in these windows looks more sensible.
  if vim.bo.filetype == "qf" then
    return true
  end
  return matched_filetype == nil
    and not vim.bo.buflisted
    and not vim.tbl_contains(special_non_plugin_filetypes, filetype)
end

---@param win_id integer
---@return boolean
function h.is_win_floating(win_id)
  -- See |api-floatwin| to learn how to check whether a win is floating.
  return vim.api.nvim_win_get_config(win_id).relative ~= ""
end

---@param statusline string
function h.draw_window_statusline(statusline)
  if h.is_win_floating(0) then
    return
  end
  vim.wo.statusline = statusline
  h.log(statusline, vim.log.levels.DEBUG)
  h.log("Stl win-local opt set")
end

h.existent_item_autocmds = {}

--- Create the autocmds to call the `callback` of a `BareItem`.
---@param item BareItem
function h.create_item_autocmds(item)
  vim.validate("item", item, "table")
  vim.validate("item.var", item.var, "string")
  if h.existent_item_autocmds[vim.fn.bufnr()] == nil then
    h.existent_item_autocmds[vim.fn.bufnr()] = {}
  end
  -- Do not create duplicate autocmds.
  if vim.tbl_contains(h.existent_item_autocmds[vim.fn.bufnr()], item.var) then
    return
  end
  vim.validate("item.opts", item.opts, "table")
  if type(item.opts.autocmds) == "table" then
    for _, autocmd in ipairs(item.opts.autocmds) do
      vim.validate("autocmd.event", autocmd.event, { "string", "table" })
      autocmd.opts = autocmd.opts or {}
      autocmd.opts.group = h.item_augroup
      local ac_event = autocmd.event
      if type(autocmd.event) == "table" then
        ac_event = vim.fn.join(autocmd.event, ",")
      end
      autocmd.opts.callback = function()
        item.callback(item.var, item.opts)
        h.log("Ran autocmd with event {" .. ac_event .. "} for: " .. item.var)
      end
      vim.api.nvim_create_autocmd(autocmd.event, autocmd.opts)
      table.insert(h.existent_item_autocmds[vim.fn.bufnr()], item.var)
      h.log("Created autocmd with event {" .. ac_event .. "} for: " .. item.var)
    end
  end
end

--- Merge user-supplied config with the plugin's default config. For every key
--- which is not supplied by the user, the value in the default config will be
--- used. The user's config has precedence; the default config is the fallback.
---@param config? table User supplied config.
---@param default_config table Bareline's default config.
---@return table
function h.get_config_with_fallback(config, default_config)
  vim.validate("config", config, "table", true)
  config =
    vim.tbl_deep_extend("force", vim.deepcopy(default_config), config or {})
  vim.validate("config.statusline", config.statusline, "table")
  vim.validate("config.statusline.value", config.statusline.value, "string")
  vim.validate("config.statuslines.items", config.statusline.items, "table")
  vim.validate("config.alt_statuslines", config.alt_statuslines, "table", true)
  return config
end

--- If `prefix` matches the beginning of `value`, then return `value` with the
--- matched portion substituted by `replacement`; otherwise, return `value` as-is.
---@param value string
---@param prefix string
---@param replacement string
---@return string
function h.replace_prefix(value, prefix, replacement)
  local result = value
  local index_of_last_matching_char = 0
  for i = 1, #prefix do
    if string.sub(value, i, i) == string.sub(prefix, i, i) then
      index_of_last_matching_char = i
    else
      break
    end
  end
  if index_of_last_matching_char == #prefix then
    result = replacement .. string.sub(result, #prefix + 1, -1)
  end
  return result
end

---@return string
function h.get_fs_sep()
  local fs_sep = "/"
  if string.sub(vim.uv.os_uname().sysname, 1, 7) == "Windows" then
    fs_sep = "\\"
  end
  return fs_sep
end

---@return string
function h.get_system_root_dir()
  local system_root_dir = "/"
  if string.sub(vim.uv.os_uname().sysname, 1, 7) == "Windows" then
    system_root_dir = "C:\\"
  end
  return system_root_dir
end

---@param level integer As per |vim.log.levels|.
function h.should_log(level)
  return bareline.config.logging.enabled
    and level >= bareline.config.logging.level
end

---@param message string
---@param level integer? As per |vim.log.levels|.
function h.log(message, level)
  level = level or vim.log.levels.INFO
  if h.should_log(level) then
    vim.defer_fn(function()
      vim.fn.writefile({
        string.format(
          "%s %s - %s\n",
          vim.fn.get({ "D", "I", "W", "E" }, level - 1),
          vim.fn.strftime("%H:%M:%S"),
          message
        ),
      }, h.state.log_filepath, "a")
    end, 0)
  end
end

h.state = {
  fs_sep = h.get_fs_sep(),
  system_root_dir = h.get_system_root_dir(),
  log_filepath = vim.fn.stdpath("data") .. "/bareline.nvim/bareline.log",
}

return bareline
