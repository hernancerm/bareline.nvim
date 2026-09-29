--- *bareline.txt* A statusline plugin for the pragmatic.
---
--- MIT License Copyright (c) 2024 Hernán Cervera.
---
--- Contents:
---
--- 1. Introduction                                          |bareline-introduction|
--- 2. Configuration                                        |bareline-configuration|
--- 3. Item structure                                      |bareline-item-structure|
--- 4. Custom items                                          |bareline-custom-items|
--- 5. Builtin items                                        |bareline-builtin-items|
--- 6. Statusline parts                                  |bareline-statusline-parts|
--- 7. Builtin statuslines                            |bareline-builtin-statuslines|
--- 8. Functions                                                |bareline-functions|
---
--- ==============================================================================
--- #tag bareline
--- #tag bareline-introduction
--- Introduction ~
---
--- Goals
---
--- 1. Simple configuration.
--- 2. Batteries included experience.
--- 3. Async. No timer. The statusline is updated immediately as changes happen.
---
--- Design
---
--- Bareline takes this approach to statusline configuration:
---
--- 1. The statusline is a Lua function returning a list of parts. Plain strings
---    in the list are the statusline DSL ('statusline'), so it is not abstracted
---    away from the user. See: |bareline.config.statusline|.
--- 2. Functions build the other parts, e.g. padded and escaped text.
---    See: |bareline-statusline-parts|.
--- 3. The plugin exposes "statusline items", which group a buf-local var, a
---    callback which sets the var, and autocmds firing the callback.
---    See: |bareline-item-structure|.
--- 4. Items are drawn with |bareline.item()|, e.g. `item("filepath")`. The first
---    draw of an item in a buf creates its autocmds and sets its var, so the
---    config does not list the items in use. Later draws only read the var.
---
--- With this design, all Bareline items are asynchronous. Drawing the statusline
--- only reads vars.

-- MODULE SETUP

local bareline = {}
local h = {}

--- Quickstart
---
--- Install the plugin and the statusline is drawn with the default config.
--- Optionally, hide the mode shown in the cmdline, since Bareline shows it:
--- >lua
---   vim.o.showmode = false
--- <
--- Some things to notice:
---
--- * No need to call |bareline.setup()|, but you may do so to configure the plugin.

--- Module setup.
---@param config table? Merged with the default config (|bareline.default_config|)
--- and the former takes precedence on duplicate keys.
function bareline.setup(config)
  config = config or {}
  -- Cleanup.
  if #vim.api.nvim_get_autocmds({ group = h.statusline_augroup }) > 0 then
    vim.api.nvim_clear_autocmds({ group = h.statusline_augroup })
  end
  h.state.active_items = {}
  h.state.set_item_vars = {}
  if #vim.api.nvim_get_autocmds({ group = h.item_augroup }) > 0 then
    vim.api.nvim_clear_autocmds({ group = h.item_augroup })
  end
  h.state.draw_error_notified = false

  -- Merge user and default configs.
  bareline.config = h.get_config_with_fallback(config, bareline.default_config)

  -- Global, so every window draws through `_draw()`. See 'statusline' on `%!`.
  vim.o.statusline = "%!v:lua.require'bareline'._draw()"

  -- Refresh the vars of the items drawn so far. BufWinEnter covers the buf a
  -- plugin shows in a window it does not enter, e.g. a build output split. During
  -- both events the win and buf of the event are current, so the items read and
  -- write the right ones.
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    group = h.item_augroup,
    callback = function()
      for _, item in pairs(h.state.active_items) do
        h.set_item_var(item)
      end
    end,
  })

  -- `:bdelete` also deletes the b: vars, so the next draw has to set them again.
  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = h.item_augroup,
    callback = function(args)
      h.state.set_item_vars[args.buf] = nil
    end,
  })

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
    statusline = function(ctx)
      if bareline.is_plugin_win() then
        return bareline.statuslines.plugin(ctx)
      end
      local item, text = bareline.item, bareline.text
      local space, each = bareline.space, bareline.each
      return {
        space(1),
        item("vim_mode", {
          inactive = "hide"
        }),
        space(1),
        "%<",
        each({ pad = true }, {
          item("filepath"),
          item("lsp_servers"),
          item("mhr"),
        }),
        "%=",
        each({ pad = true }, {
          item("diagnostics"),
          item("end_of_line"),
          item("indent_style"),
          text(vim.b.gitsigns_head, {
            wrap = { "(", ")" },
            inactive = "remove",
          }),
          item("cwd"),
        }),
        space(1),
        "%02l:%02c/%02L",
        space(1),
      }
    end,
    items = {
      mhr = {
        display_modified = true,
      },
    },
  }
  --minidoc_afterlines_end
end

--- #tag bareline.config.statusline
---     {statusline} `(fun(ctx:BarelineCtx):table|string)`
---       Called on every draw of every statusline. Returns a list of parts:
---       * `string`: Statusline DSL, used as-is, e.g. `"%<"`, `"%02l"`.
---       * The return of |bareline.item()| and |bareline.text()|: Text, where
---         `%` is escaped.
---       * A nested list, e.g. the return of |bareline.each()|.
---       * `nil` or `false`: Skipped, so `ctx.active and "foo"` works.
---       The function runs in the window being drawn, so |vim.b|, |vim.wo| and
---       |vim.fn| read that window and its buf. If the function errors, the
---       error is shown once and a basic statusline is drawn instead.
---       To pick a different statusline for some windows, use an `if`. The
---       default config does so for plugin windows.
---
--- Context of the draw, passed to |bareline.config.statusline|.
---@class BarelineCtx
---@field active boolean Whether the window being drawn is the current window.
--- It cannot be read from within the function, since the window being drawn is
--- current while it runs.

--- #tag bareline.config.items
--- Provide item-specific configuration.
---
--- #tag bareline.config.items.mhr
---     {mhr} `(boolean|fun():boolean)`
---       See |bareline.items.mhr|.

--- #delimiter
--- #tag bareline-item-structure
--- Item structure ~
---
--- All custom and builtin items are a |bareline.BareItem|. See:
--- * |bareline-custom-items|.
--- * |bareline-builtin-items|.

--- Statusline item.
---@class BareItem
---@field var string Name of buf-local var holding the value of the item. The
--- value is set directly by `callback`.
---@field callback fun(var:string) Sets `var` (`vim.b[var] = "foo"`). The option
--- `autocmds` (|bareline.BareItemCommonOpts|) decides when to call the callback.
--- To improve performance on intensive workloads, distribute the processing among
--- several event loop cycles. Common ways to do this are using the async form of
--- the function |vim.system()| and using |vim.defer_fn()|.
---@field opts BareItemCommonOpts
bareline.BareItem = {}
bareline.BareItem["__index"] = bareline.BareItem

--- #tag bareline-BareItemCommonOpts
--- Options applicable to any |bareline.BareItem|.
---@class BareItemCommonOpts
---@field autocmds table[]? Expects tables each with the keys `event` and `opts`,
--- which are passed to: |vim.api.nvim_create_autocmd()|.
---@field stl_code boolean? Whether the value is statusline DSL, e.g. `"%m%r"`.
--- When `true`, |bareline.item()| does not escape `%` in the value.

--- Constructor.
---@param var string
---@param callback fun(var:string)
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

--- #delimiter
--- #tag bareline-custom-items
--- Custom items ~
---
--- All custom items are a |bareline.BareItem|. To draw an item with
--- |bareline.item()|, add it to `bareline.items`. Example item indicating soft
--- wrap:
--- >lua
---   local bareline = require("bareline")
---   bareline.items.soft_wrap = bareline.BareItem:new(
---     "bl_x_soft_wrap",
---     function(var)
---       local label = nil
---       if vim.wo.wrap then
---         label = "s-wrap"
---       end
---       vim.b[var] = label
---     end, {
---     autocmds = {
---       -- IMPORTANT: The autocmds need to account for all the cases where the
---       -- value of the buf-local var indicated by `var` would change.
---       {
---         event = "OptionSet",
---         opts = { pattern = "wrap" }
---       }
---     }
---   })
--- <
--- Use it:
--- >lua
---   bareline.setup({
---     statusline = function()
---       return { bareline.item("soft_wrap") }
---     end,
---   })
--- <

-- ITEMS

bareline.items = {}

--- #delimiter
--- #tag bareline-builtin-items
--- Builtin items ~

--- All builtin items are a |bareline.BareItem|.

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
  if vim.bo.buftype == "quickfix" then
    vim.b[var] = "%t%{exists('w:quickfix_title')?' '.w:quickfix_title:''}"
  else
    vim.b[var] = string.format("[%s]", vim.bo.filetype:lower():gsub("%s", ""))
  end
end, {
  stl_code = true,
  autocmds = {
    {
      event = "BufWinEnter",
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
--- to the cwd is displayed. Else, the full filepath is displayed. For a `jdt://`
--- buf (a Java class file opened by jdtls), the URI query string is dropped.
--- Mockup: `lua/bareline.lua`
---@type BareItem
bareline.items.filepath = bareline.BareItem:new("bl_filepath", function(var)
  local buf_name = vim.api.nvim_buf_get_name(0)
  if buf_name == "" or vim.bo.filetype == "help" then
    vim.b[var] = vim.api.nvim_eval_statusline("%f", {}).str
    return
  end
  -- A `jdt://` URI carries the whole classpath in its query string, hundreds of
  -- columns wide. The part before `?` names the class, keep just that.
  local jdt_uri_head = buf_name:match("^(jdt://.-)%?")
  if jdt_uri_head then
    vim.b[var] = jdt_uri_head
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
        "TermOpen",
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
bareline.items.cwd = bareline.BareItem:new(
  "bl_cwd",
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
--- Display the modified, help and read-only markers using the builtin statusline
--- fields, see 'statusline' for a list of fields where these are included.
--- Options (set in |bareline.config.items|):
---  * {display_modified} `(boolean|fun():boolean)` Control when the modified
---    field (`%m`) is included. When `true`, the field is always displayed except
---    when the buf has set 'nomodifiable'. Default: `true`.
---
--- Mockups: `[+]`, `[Help][RO]`
---@type BareItem
bareline.items.mhr = bareline.BareItem:new("bl_mhr", function(var)
  local display_modified = bareline.config.items.mhr.display_modified
  if type(display_modified) == "function" then
    display_modified = display_modified()
  end
  local value = "%h%r"
  if display_modified and vim.bo.modifiable then
    value = "%m" .. value
  end
  vim.b[var] = value
end, {
  stl_code = true,
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

-- STATUSLINE PARTS

--- #delimiter
--- #tag bareline-statusline-parts
--- Statusline parts ~
---
--- The functions in this section build the parts returned by
--- |bareline.config.statusline|. They are meant to be called while it runs.
---
--- #tag bareline.PartOpts
--- Options of |bareline.item()| and |bareline.text()|. Nothing is added when the
--- value is empty. Applied in this order: `wrap`, `pad`, `inactive`.
---@class BarelinePartOpts
---@field pad boolean? Add |bareline.space()| on both sides.
---@field wrap string[]? Add a prefix and a suffix, e.g. `{ "(", ")" }`. These
--- are statusline DSL, so `%` is not escaped.
---@field inactive ("hide"|"remove"|false)? In inactive windows, either replace
--- the part with spaces of the same width (`"hide"`), or drop it (`"remove"`).

--- Value of the item `bareline.items[{name}]` in the current buf. The first
--- call in a buf creates the autocmds of the item and sets its var. The value is
--- escaped, unless the item sets `stl_code`. See: |bareline-item-structure|.
---@param name string Key of the item in `bareline.items`.
---@param opts BarelinePartOpts?
---@return table
function bareline.item(name, opts)
  local item = bareline.items[name]
  if item == nil then
    error("Bareline: no item in bareline.items named: " .. name)
  end
  if h.state.active_items[item.var] == nil then
    h.state.active_items[item.var] = item
    h.create_item_autocmds(item)
  end
  local set_vars = h.state.set_item_vars[vim.api.nvim_get_current_buf()]
  if set_vars == nil or not set_vars[item.var] then
    h.set_item_var(item)
  end
  return h.new_part(vim.b[item.var], item.opts.stl_code == true, opts)
end

--- Any value as text, so `%` is escaped. `nil` is an empty string. Example
--- usage to wrap with parens the Git HEAD set by
--- `https://github.com/lewis6991/gitsigns.nvim`:
--- `text(vim.b.gitsigns_head, { wrap = { "(", ")" } })`
---@param value any
---@param opts BarelinePartOpts?
---@return table
function bareline.text(value, opts)
  return h.new_part(value, false, opts)
end

--- Apply {opts} to each |bareline.item()| and |bareline.text()| in {parts},
--- including nested lists. The opts of a part take precedence, e.g. a part with
--- `{ pad = false }` is not padded by `each({ pad = true }, ...)`.
---@param opts BarelinePartOpts
---@param parts table
---@return table
function bareline.each(opts, parts)
  vim.validate("opts", opts, "table")
  vim.validate("parts", parts, "table")
  local result = {}
  for i = 1, table.maxn(parts) do
    local part = parts[i]
    if getmetatable(part) == h.part_mt then
      result[i] = h.new_part(
        part.value,
        part.stl_code,
        vim.tbl_extend("force", opts, part.opts)
      )
    elseif type(part) == "table" then
      result[i] = bareline.each(opts, part)
    else
      result[i] = part
    end
  end
  return result
end

--- Invisible space. Return {length} Unicode Thin Space (U+2009) chars. ASCII
--- whitespace is sometimes trimmed by Neovim, while this char is not.
---@param length integer
---@return string
function bareline.space(length)
  -- The UTF-8 bytes of U+2009.
  return string.rep("\226\128\137", length)
end

-- BUILTIN STATUSLINES

bareline.statuslines = {}

--- #delimiter
--- #tag bareline-builtin-statuslines
--- Builtin statuslines ~
---
--- Each is a function like |bareline.config.statusline|, so it can be returned
--- from it, e.g. `return bareline.statuslines.plugin(ctx)`.

--- Statusline for plugin windows, including the plugin name.
--- See: |bareline.is_plugin_win()|.
---@param ctx BarelineCtx
---@return table
---@diagnostic disable-next-line: unused-local
function bareline.statuslines.plugin(ctx)
  return {
    bareline.space(1),
    bareline.item("plugin_name"),
    "%=",
    "%02l:%02c/%02L",
    bareline.space(1),
  }
end

--- #delimiter
--- #tag bareline-functions
--- Functions ~

--- Whether the current window is a plugin window, e.g. nvim-tree. Also `true`
--- for the quickfix and location lists.
---@return boolean
function bareline.is_plugin_win()
  return h.is_plugin_buf(0)
end

--- Redraw all statuslines. Use this to integrate with plugins which provide
--- statusline integration through buf-local vars and user autocmds. Calls in the
--- same event loop cycle are merged into one redraw.
---
--- For example, consider the integration with `lewis6991/gitsigns.nvim`. Out of
--- the box, Bareline provides this. If it did not provide it, this is how a user
--- could define it themselves:
--- >lua
---   vim.api.nvim_create_autocmd("User", {
---     pattern = "GitSignsUpdate",
---     callback = function()
---       bareline.refresh_statusline()
---     end,
---   })
--- <
function bareline.refresh_statusline()
  if h.state.redraw_pending then
    return
  end
  h.state.redraw_pending = true
  vim.schedule(function()
    h.state.redraw_pending = false
    vim.cmd("redrawstatus!")
  end)
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

-- OTHER

h.statusline_augroup = vim.api.nvim_create_augroup("BarelineSetStatusline", {})
h.item_augroup = vim.api.nvim_create_augroup("BarelineCallItemCallback", {})

local shipped_filetype_cache = {}

--- Whether Neovim ships support for `filetype`, as opposed to it being the
--- private name a plugin gives its own window, e.g. "NvimTree". Tells a buf a
--- job filled with markdown, which is a document, from a file tree, which is not.
--- Cached: this runs on every statusline refresh and walks 'runtimepath'.
---@param filetype string
---@return boolean
function h.is_shipped_filetype(filetype)
  if filetype == "" then
    return false
  end
  if shipped_filetype_cache[filetype] == nil then
    shipped_filetype_cache[filetype] = #vim.api.nvim_get_runtime_file(
      "syntax/" .. filetype .. ".vim",
      false
    ) > 0 or #vim.api.nvim_get_runtime_file(
      "ftplugin/" .. filetype .. ".*",
      false
    ) > 0
  end
  return shipped_filetype_cache[filetype]
end

---@param bufnr integer The buffer number, as returned by |bufnr()|.
---@return boolean
function h.is_plugin_buf(bufnr)
  -- Although the quickfix and location lists are not plugin windows, using the
  -- plugin window format in these windows looks more sensible.
  if vim.bo[bufnr].buftype == "quickfix" then
    return true
  end
  local filetype = vim.bo[bufnr].filetype
  if vim.tbl_contains({ "", "help", "man" }, filetype) then
    return false
  end
  if vim.bo[bufnr].buflisted then
    return false
  end
  -- By name, never by content. A buf a job writes into is empty when its window
  -- opens, so content answers one way then and another once the output lands,
  -- leaving whichever statusline was picked first until something else refreshes.
  if
    vim.filetype.match({ filename = vim.api.nvim_buf_get_name(bufnr) }) ~= nil
  then
    return false
  end
  return not h.is_shipped_filetype(filetype)
end

--- Create the autocmds to call the `callback` of a `BareItem`.
---@param item BareItem
function h.create_item_autocmds(item)
  vim.validate("item", item, "table")
  vim.validate("item.var", item.var, "string")
  vim.validate("item.opts", item.opts, "table")
  if type(item.opts.autocmds) == "table" then
    for i = 1, #item.opts.autocmds do
      vim.validate(
        "item.opts.autocmds[" .. i .. "].event",
        item.opts.autocmds[i].event,
        { "string", "table" }
      )
      vim.validate(
        "item.opts.autocmds[" .. i .. "].opts",
        item.opts.autocmds[i].opts,
        "table",
        true
      )
      h.create_item_autocmd(item, item.opts.autocmds[i])
    end
  end
end

---@param item BareItem
---@param autocmd table
function h.create_item_autocmd(item, autocmd)
  autocmd.opts = autocmd.opts or {}
  autocmd.opts.group = h.item_augroup
  autocmd.opts.callback = function()
    h.set_item_var(item)
    -- A b: var change alone does not redraw the statusline.
    bareline.refresh_statusline()
  end
  vim.api.nvim_create_autocmd(autocmd.event, autocmd.opts)
end

--- Call the callback of `item` in the current buf, and record that the buf has
--- the var set, so |bareline.item()| does not call it again.
---@param item BareItem
function h.set_item_var(item)
  local buf = vim.api.nvim_get_current_buf()
  h.state.set_item_vars[buf] = h.state.set_item_vars[buf] or {}
  h.state.set_item_vars[buf][item.var] = true
  item.callback(item.var)
end

-- Marks the tables returned by `item()` and `text()`, to tell them apart from a
-- nested list of parts.
h.part_mt = {}

---@param value any
---@param stl_code boolean
---@param opts BarelinePartOpts?
---@return table
function h.new_part(value, stl_code, opts)
  vim.validate("opts", opts, "table", true)
  local part = {
    value = value == nil and "" or tostring(value),
    stl_code = stl_code,
    opts = opts or {},
  }
  return setmetatable(part, h.part_mt)
end

-- Drawn when nothing better can be, e.g. the user's statusline errors.
h.fallback_statusline = "%<%f %h%w%m%r%=%l,%c %P"

-- Backs 'statusline' (see `setup()`). `%!` runs in the current window, while
-- `g:statusline_winid` is the one being drawn, so the user's function runs in
-- the latter. That way `vim.b` reads the drawn buf, like `%{}` would.
---@return string
function bareline._draw()
  local current_win = vim.api.nvim_get_current_win()
  local win = vim.g.statusline_winid or current_win
  if bareline.config == nil then
    return h.fallback_statusline
  end
  local ctx = { active = win == current_win }
  local ok, result = pcall(vim.api.nvim_win_call, win, function()
    local parts = bareline.config.statusline(ctx)
    local out = {}
    h.render_parts({ parts }, ctx.active, out)
    return table.concat(out)
  end)
  if ok then
    return result
  end
  if not h.state.draw_error_notified then
    h.state.draw_error_notified = true
    -- Deferred: notifying while the statusline is drawn is not reliable.
    vim.schedule(function()
      vim.notify("Bareline: " .. result, vim.log.levels.ERROR)
    end)
  end
  return h.fallback_statusline
end

--- Render the statusline parts in `parts`, appending to `out`.
---@param parts table
---@param active boolean
---@param out string[]
function h.render_parts(parts, active, out)
  -- `table.maxn` over `ipairs`, since `nil` parts leave holes in the list.
  for i = 1, table.maxn(parts) do
    local part = parts[i]
    if getmetatable(part) == h.part_mt then
      table.insert(out, h.render_part(part, active))
    elseif type(part) == "table" then
      h.render_parts(part, active, out)
    elseif type(part) == "string" or type(part) == "number" then
      table.insert(out, tostring(part))
    elseif part ~= nil and part ~= false then
      error("statusline part must be a string or table, got " .. type(part))
    end
  end
end

---@param part table Built by `h.new_part()`.
---@param active boolean
---@return string
function h.render_part(part, active)
  local opts = part.opts
  if part.value == "" or (not active and opts.inactive == "remove") then
    return ""
  end
  local value = part.value
  if not part.stl_code then
    value = value:gsub("%%", "%%%%")
  end
  local prefix, suffix = "", ""
  if opts.wrap then
    prefix, suffix = opts.wrap[1] or "", opts.wrap[2] or ""
  end
  local pad = opts.pad and bareline.space(1) or ""
  if not active and opts.inactive == "hide" then
    -- Measured on the unescaped value, as it is displayed.
    local width = vim.api.nvim_strwidth(part.value)
      + vim.api.nvim_strwidth(prefix .. suffix)
    if opts.pad then
      width = width + 2
    end
    return bareline.space(width)
  end
  return pad .. prefix .. value .. suffix .. pad
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
  vim.validate("config.statusline", config.statusline, "function")
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

h.state = {
  fs_sep = h.get_fs_sep(),
  -- Items drawn at least once, keyed by var.
  active_items = {},
  -- Per buf, the vars of the items set in it, e.g. `{ [1] = { bl_filepath = true } }`.
  set_item_vars = {},
  -- Whether an error of the user's statusline was shown, to show it only once.
  draw_error_notified = false,
  -- Whether a redraw is scheduled by `refresh_statusline()`.
  redraw_pending = false,
  system_root_dir = h.get_system_root_dir(),
}

return bareline
