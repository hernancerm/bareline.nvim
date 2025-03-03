--- *bareline* A statusline plugin for the pragmatic.
---
--- MIT License Copyright (c) 2024 Hernán Cervera.
---
--- Contents:
---
--- 1. Introduction                                   |bareline-introduction|
--- 2. Quickstart                                     |bareline-quickstart|
--- 3. Configuration                                  |bareline-configuration|
--- 4. Custom components                              |bareline-custom-components|
--- 5. Control statusline redraws                     |bareline-control-stl-redraws|
--- 6. Built-in components                            |bareline-built-in-components|
---
---                   Press `gO` to load the table of contents in the location list.
--- ==============================================================================
--- #tag bareline-introduction
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
--- Visualized example
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

--- To enable the plugin you need to call the |bareline.setup()| function. To use
--- the defaults, call it without arguments:
--- >lua
---   require("bareline").setup()
---   vim.o.showmode = false -- Optional, recommended.
--- <

--- Module setup.
---@param config table? Merged with the default config (|bareline.default_config|)
--- and the former takes precedence on duplicate keys.
function bareline.setup(config)
  -- Cleanup.
  if #vim.api.nvim_get_autocmds({ group = h.draw_methods_augroup }) > 0 then
    vim.api.nvim_clear_autocmds({ group = h.draw_methods_augroup })
  end
  h.close_all_uv_fs_event_handles()

  bareline.config = h.get_config_with_fallback(config, bareline.default_config)

  -- Logger setup.
  if bareline.config.logging.enabled and h.state.log_file == nil then
    local data_stdpath = vim.fn.stdpath("data")
    if type(data_stdpath) == "table" then
      data_stdpath = data_stdpath[1]
    end
    vim.fn.mkdir(data_stdpath .. "/bareline.nvim", "p")
    h.state.log_file =
      io.open(data_stdpath .. "/bareline.nvim/bareline.log", "a+")
    vim.api.nvim_create_autocmd("VimLeave", {
      group = h.draw_methods_augroup,
      callback = function()
        h.state.log_file:close()
      end,
    })
  end

  -- Create base autocmds.
  -- DOCS: Keep in sync with |bareline-custom-components|.
  vim.api.nvim_create_autocmd({
    "BufNew",
    "BufEnter",
    "BufWinEnter",
    "WinEnter",
    "VimResume",
    "FocusGained",
    "DirChanged",
    "TermLeave",
  }, {
    group = h.draw_methods_augroup,
    callback = function()
      if vim.v.vim_did_enter == 1 then
        h.draw_statusline_if_plugin_window(
          bareline.config.statuslines.plugin,
          bareline.config.statuslines.active
        )
      end
    end,
  })
  vim.api.nvim_create_autocmd("OptionSet", {
    group = h.draw_methods_augroup,
    callback = function(event)
      local options_blacklist = {
        "statusline",
        "laststatus",
        "eventignore",
        "winblend",
        "winhighlight",
      }
      if vim.tbl_contains(options_blacklist, event.match) then
        return
      end
      h.draw_statusline_if_plugin_window(
        bareline.config.statuslines.plugin,
        bareline.config.statuslines.active
      )
    end,
  })

  local statuslines = {
    bareline.config.statuslines.active,
    bareline.config.statuslines.inactive,
    bareline.config.statuslines.plugin,
  }

  -- Create component-specific autocmds.
  h.create_bare_component_autocmds(statuslines, 2, function()
    h.draw_statusline_if_plugin_window(
      bareline.config.statuslines.plugin,
      bareline.config.statuslines.active
    )
  end)

  -- Close all luv fs event handles.
  vim.api.nvim_create_autocmd("VimLeave", {
    group = h.draw_methods_augroup,
    callback = function()
      h.close_all_uv_fs_event_handles()
    end,
  })

  -- Draw a different statusline for inactive windows. For inactive plugin
  -- windows, use a special statusline, the same one as for active plugin windows.
  vim.api.nvim_create_autocmd("WinLeave", {
    group = h.draw_methods_augroup,
    callback = function()
      if vim.o.laststatus == 3 then
        return
      end
      h.draw_statusline_if_plugin_window(
        bareline.config.statuslines.plugin,
        bareline.config.statuslines.inactive
      )
    end,
  })

  -- Useful when re-running `setup()` after Neovim's startup.
  if vim.v.vim_did_enter == 1 then
    h.draw_statusline_if_plugin_window(
      bareline.config.statuslines.plugin,
      bareline.config.statuslines.active
    )
  end
end

--- #delimiter
--- #tag bareline.config
--- #tag bareline.default_config
--- #tag bareline-configuration
--- Configuration ~

--- The merged config (defaults with user overrides) is in `bareline.config`. The
--- default config is in `bareline.default_config`. The default uses distinct
--- statuslines for active, inactive and plugin windows.
---
--- Below is the default config; `bareline` is the value of `require("bareline")`.
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
--minidoc_replace_start
local function assign_default_config()
  --minidoc_replace_end
  --minidoc_replace_start {
  bareline.default_config = {
    --minidoc_replace_end
    statuslines = {
      -- Active window.
      active = {
        { -- Section 1: Left.
          bareline.components.vim_mode,
          bareline.components.file_path_relative_to_cwd,
          bareline.components.lsp_servers,
          bareline.components.mhr,
        },
        { -- Section 2: Right.
          bareline.components.diagnostics,
          bareline.components.end_of_line,
          bareline.components.indent_style,
          bareline.components.git_head,
          bareline.components.cwd,
          bareline.components.position,
        },
      },
      -- Inactive windows.
      inactive = {
        { -- Section 1: Left.
          bareline.components.vim_mode:config({ mask = " " }),
          bareline.components.file_path_relative_to_cwd,
          bareline.components.lsp_servers,
          bareline.components.mhr,
        },
        { -- Section 2: Right.
          bareline.components.diagnostics,
          bareline.components.end_of_line,
          bareline.components.indent_style,
          bareline.components.cwd,
          bareline.components.position,
        },
      },
      -- Plugin windows.
      plugin = {
        { -- Section 1: Left.
          bareline.components.plugin_name,
          bareline.components.mhr,
        },
        { -- Section 2: Right.
          bareline.components.position,
        },
      },
    },
    components = {
      git_head = {
        worktrees = {},
      },
      mhr = {
        display_modified = true,
      },
    },
    logging = {
      enabled = false,
    },
  }
  --minidoc_afterlines_end
end

-- DOCS: Keep in sync with the type BareStatusline.
--- #tag bareline.config.statuslines
--- Configures the statusline. Each field holds a statusline table definition per
--- window state. All the fields are of the same type: a list of lists of objects.
--- The lists are the sections (i.e. left, right) and the objects are the
--- components (strings, functions or |BareComponent|s).
---
--- Fields:
---
--- #tag bareline.config.statuslines.active
---     {active} `(table)`
--- Definition for the statusline of the win focused by the cursor.
---
--- #tag bareline.config.statuslines.inactive
---     {inactive} `(table)`
--- Definition for the statuslines of the wins which are:
--- 1. NOT focused by the cursor and
--- 2. NOT displaying a plugin's UI.
---
--- #tag bareline.config.statuslines.plugin
---     {plugin} `(table)`
--- Definition for the statusline of the wins displaying a plugin's UI.

--- #tag bareline.config.components
--- The component options set in |bareline.BareComponent:new()| are merged with
--- these options. The options here have precedence on duplicate keys.
---
--- Fields:
---
--- #tag bareline.config.components.git_head
---     {git_head} `(table)`
--- See |bareline.components.git_head|.
---
--- #tag bareline.config.components.mhr
---     {mhr} `(boolean|fun():boolean)`
--- See |bareline.components.mhr|.

--- #tag bareline.config.logging
--- Monitor statusline redraws. The log file is located at the data directory
--- (`stdpath("data")`) in `bareline.nvim/bareline.log`.
---
--- Fields:
---
--- #tag bareline.config.logging.enabled
---     {enabled} `(boolean)`
--- Whether to write to the log file. Default: false.

--- #delimiter
--- #tag bareline-custom-components
--- Custom components ~
---
--- Bareline comes with some components: |bareline-built-in-components|. If none
--- provide what you want, you can create your own. A component can be a string,
--- function or |bareline.BareComponent|:
---
--- 1. String: Gets evaluated as a statusline string (see 'statusline'). Examples:
---    * Arbitrary string: `"S-WRAP"`. In the statusline you'll see `S-WRAP`.
---    * Options: `vim.bo.fileformat`. In the statusline you might see `unix`.
---    * Statusline item: `"%r"`. In the statusline you might see `[RO]`.
---
--- 2. Function: Returns a string or nil. When a string, it's placed in the
---    statusline; when nil, the component is skipped. Example:
--- >lua
---    -- Get the tail of the current working directory.
---    local component_cwd = function ()
---      local cwd = vim.uv.cwd() or ""
---      if cwd == (vim.uv.os_homedir() or "") then
---        return "~"
---      end
---      return vim.fn.fnamemodify(cwd, ":t")
---    end
--- <
--- 3. |bareline.BareComponent|: This allows the most granular customization.
---
--- For several use cases you don't need to use a |bareline.BareComponent| since
--- out of the box the statusline gets redrawn on several autocmds.
--- See: |bareline-control-stl-redraws|.

---@alias UserSuppliedComponent any|fun():any|BareComponent

--- #delimiter
--- #tag bareline-control-stl-redraws
---
--- Control statusline redraws ~
---
--- Bareline does not use a timer to redraw the statusline, instead it uses:
--- 1. |autocmd|s. See `redraw_on_autocmd` in |bareline-BareComponentCommonOpts|.
--- 2. |uv| file watchers. See |bareline.redraw_on_fs_event()|.
---
--- These are the base autocmds used to redraw the stl:
--- * |BufEnter|
--- * |BufWinEnter|
--- * |WinEnter|
--- * |VimResume|
--- * |FocusGained|
--- * |OptionSet|
--- * |DirChanged|
--- * |TermLeave|
---
--- With the default config, these are the fs paths watched to redraw the stl:
--- * Git repository directories to fulfill |bareline.components.git_head|.

--- Conditionally create a |uv_fs_event_t| to monitor `fs_path` for changes. When
--- a change is detected, redraw the statusline of the current window. If a luv fs
--- event handle already exists for the `fs_path`, then do nothing.
---@param fs_path string Relative or absolute path to a dir or file.
function bareline.redraw_on_fs_event(fs_path)
  local fs_path_absolute = vim.uv.fs_realpath(fs_path)
  if
    h.fs_path_to_uv_fs_event_handle[fs_path_absolute] == nil
    and fs_path_absolute ~= nil
  then
    local uv_fs_event_handle = h.create_uv_fs_event(fs_path_absolute, function()
      h.draw_statusline_if_plugin_window(
        bareline.config.statuslines.plugin,
        bareline.config.statuslines.active
      )
    end)
    h.fs_path_to_uv_fs_event_handle[fs_path_absolute] = uv_fs_event_handle
    h.log(
      "Added to fs_path_to_uv_fs_event_handle. Resulting table: "
        .. vim.inspect(h.fs_path_to_uv_fs_event_handle),
      vim.log.levels.DEBUG
    )
  end
end

-- COMPONENTS

bareline.components = {}

--- #delimiter

--- Standardized statusline component.
--- All |bareline-built-in-components| are a |bareline.BareComponent|. To create
--- your own components, you can use this class or use simpler types as described
--- in |bareline-custom-components|.
---@class BareComponent
---@field value string|fun(opts:table):any Provides the value displayed in the
--- statusline, like the diagnostics. When the value is a function, it gets the
--- argument `opts` from the field `opts` of the |bareline.BareComponent| object.
--- This is powerful, as it allows configuring components after creation and
--- setting options not present in |bareline-BareComponentCommonOpts|.
--- See: |bareline.BareComponent:config()|
---@field opts BareComponentCommonOpts
bareline.BareComponent = {}
bareline.BareComponent["__index"] = bareline.BareComponent

--- #tag bareline-BareComponentCommonOpts
--- Options applicable to any |bareline.BareComponent|.
---@class BareComponentCommonOpts
---@field async boolean? When true, the `value` of the component must be a
--- function returning a statusline expression as follows: `%{bareline_async_<>}`,
--- where `<>` is the name of the component, e.g. `%{bareline_async_git_head}`.
--- To show the actual value, the component is responsible of setting the var.
---@field skip_async boolean? Whether to skip the async logic in async components.
--- The component author is responsible for respecting this option.
---@field redraw_on_autocmd table? Expects a table with the keys `event` and
--- `opts`. These values are passed as-is to |vim.api.nvim_create_autocmd()|.
---@field cache_on_vim_modes (string[]|fun():string[])|nil Use cache in these Vim
--- modes. Each Vim mode is expected as the first char returned by |mode()|.
---@field mask string? Single character used to mask the value.

--- Constructor.
---@param value (string|fun(opts:table):any)|nil Initial value of field `value`.
---@param common_opts BareComponentCommonOpts Initial value of field `opts`.
---@return BareComponent
function bareline.BareComponent:new(value, common_opts)
  local bare_component = {}
  setmetatable(bare_component, self)
  bare_component.value = value
  bare_component.opts = common_opts
  return bare_component
end

--- Update component opts.
---@param opts table The field `opts` from |bareline.BareComponent| is merged with
--- these opts. For built-in components, the option keys here have priority over
--- what is set in both |bareline.BareComponent:new()| and at the plugin setup,
--- i.e. |bareline.config.components|. Built-in components have their custom
--- options documented, which can be set using this method.
--- For an example, see |bareline.components.git_head|.
---@return BareComponent
function bareline.BareComponent:config(opts)
  local component_copy = vim.deepcopy(self)
  component_copy.opts =
    vim.tbl_deep_extend("force", vim.deepcopy(component_copy.opts), opts or {})
  return component_copy
end

--- Retrieve the value of the component.
---@param skip_async? boolean
---@return string?
function bareline.BareComponent:get(skip_async)
  local value = nil
  if type(self.value) == "function" then
    if skip_async then
      self.opts.skip_async = skip_async
    end
    value = self.value(self.opts)
    -- Reset the default value of this option.
    self.opts.skip_async = false
    if value ~= nil and self.opts.async then
      local success, result = pcall(vim.api.nvim_eval_statusline, value, {})
      if (not success) or result.str == "{{NIL}}" then
        value = nil
      end
    end
  elseif type(self.value) == "string" then
    value = self.value
  end
  if value ~= nil and self.opts ~= nil and self.opts.mask then
    vim.validate({
      mask = { self.opts.mask, { "string" } },
    })
    value = string.gsub(value, ".", string.sub(self.opts.mask, 1, 1))
  end
  return value
end

--- #delimiter
--- #tag bareline-built-in-components
--- Built-in components ~

--- Built-in components for use in |bareline.config.statusline|. These are all
--- structured as a |bareline.BareComponent|. If you want to create your own
--- component see |bareline-custom-components|.

--- Vim mode.
--- The Vim mode in 3 characters.
--- Mockups: `NOR`, `VIS`
---@type BareComponent
bareline.components.vim_mode = bareline.BareComponent:new(function()
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
  return mode_labels[vim_mode]:upper()
end, {
  redraw_on_autocmd = {
    event = { "ModeChanged", "InsertLeave" },
  },
})

--- Plugin name.
--- When on a plugin window, the formatted name of the plugin window.
--- Mockup: `[nvimtree]`
---@type BareComponent
bareline.components.plugin_name = bareline.BareComponent:new(function()
  if vim.bo.filetype == "qf" then
    return "%t%{exists('w:quickfix_title')? ' '.w:quickfix_title : ''}"
  end
  return string.format("[%s]", vim.bo.filetype:lower():gsub("%s", ""))
end, {})

--- Indent style.
--- Relies on 'expandtab' and 'tabstop'. Omitted when the buf is 'nomodifiable'.
--- Mockups: `spaces:2`, `tabs:4`
---@type BareComponent
bareline.components.indent_style = bareline.BareComponent:new(function()
  if not vim.bo.modifiable then
    return nil
  end
  local whitespace_type = (vim.bo.expandtab and "spaces") or "tabs"
  return whitespace_type .. ":" .. vim.bo.tabstop
end, {})

--- End of line (EOL).
--- Indicates when the buffer does not have an EOL on its last line. Return `noeol`
--- in this case, nil otherwise. This uses the option 'eol'.
---@type BareComponent
bareline.components.end_of_line = bareline.BareComponent:new(function()
  if vim.bo.eol then
    return nil
  end
  return "noeol"
end, {})

--- Git HEAD.
---
--- Attributes:
--- * async
---
--- Git needs to be installed for this component to work. The search for the HEAD
--- is done in relationship to the name of the current buffer, Neovim's cwd is
--- irrelevant. To learn the HEAD, first a repo needs to be found.
---
--- Steps to find a Git repo:
--- 1. If the buf name is empty, do nothing.
--- 2. Else, search with: `git -C {parent dir} rev-parse --absolute-git-dir`.
--- 3. Else, search through `worktrees` in the order they are provided.
---
--- When the found repo has the option `status.showUntrackedFiles` disabled, the
--- HEAD is not shown on untracked files. When a file is added to the staging area
--- (even if not committed yet) it stops being considered as untracked.
---
--- Custom options:
---     {worktrees} `(table)`
--- List with the same structure as what the gitsigns.nvim plugin expects:
--- <https://github.com/lewis6991/gitsigns.nvim>. This provides support for
--- detached working trees; useful for bare repositories. Example:
--- >lua
---   bareline.components.git_head:config({
---     worktrees = {
---       {
---         toplevel = vim.env.HOME,
---         gitdir = vim.env.HOME .. "/dotfiles.git"
---       }
---     }
---   })
--- <
--- Mockup: `(main)`
---@type BareComponent
bareline.components.git_head = bareline.BareComponent:new(function(opts)
  local filepath = vim.api.nvim_buf_get_name(0)
  if filepath == "" then
    return nil
  end
  -- stylua: ignore start
  if not opts.skip_async then
    vim.system({
      "git", "-C", vim.fn.fnamemodify(filepath, ":h"),
      "rev-parse", "--absolute-git-dir",
    }, { text = true }, vim.schedule_wrap(function(rev_parse_o)
      local gitdir = nil
      if rev_parse_o.code == 0 then
        gitdir = vim.fn.trim(rev_parse_o.stdout, "\n", 2)
      end
      if gitdir ~= nil then
        -- Found standard repo or work tree from `git worktree add`.
        if h.providers.git_head.is_filepath_tracked(filepath, gitdir)
            or h.providers.git_head.should_show_untracked(gitdir) then
          bareline.redraw_on_fs_event(gitdir)
          vim.w.bareline_async_git_head =
            h.providers.git_head.get_pretty_head(gitdir)
          h.draw_statusline_from_async_component()
        end
      else
        local matched_worktree = h.providers.git_head.get_matching_worktree(
          h.providers.git_head.get_opt_worktrees(opts),
          filepath
        )
        if matched_worktree ~= nil then
          -- Found work tree from `worktrees` custom component opt.
          bareline.redraw_on_fs_event(matched_worktree.gitdir)
          vim.w.bareline_async_git_head =
            h.providers.git_head.get_pretty_head(matched_worktree.gitdir)
          h.draw_statusline_from_async_component()
        end
      end
    end))
  end
  -- stylua: ignore end
  if vim.w.bareline_async_git_head == nil then
    vim.w.bareline_async_git_head = "{{NIL}}"
  end
  return "%{w:bareline_async_git_head}"
end, { async = true })

--- LSP servers.
--- The LSP servers attached to the current buffer.
--- Mockup: `[lua_ls]`
---@type BareComponent
bareline.components.lsp_servers = bareline.BareComponent:new(function()
  local lsp_servers = h.providers.lsp_servers.get_names()
  if lsp_servers == nil or vim.tbl_isempty(lsp_servers) then
    return nil
  end
  return "[" .. vim.fn.join(lsp_servers, ",") .. "]"
end, {
  redraw_on_autocmd = {
    event = { "LspAttach", "LspDetach" },
  },
})

--- Stable `%f`.
--- The file path relative to the current working directory (|:pwd|). When the
--- user home directory appears in the file path, `~` is used to shorten the path.
--- Mockup: `lua/bareline.lua`
---@type BareComponent
bareline.components.file_path_relative_to_cwd = bareline.BareComponent:new(
  function()
    local buf_name = vim.api.nvim_buf_get_name(0)
    if buf_name == "" or vim.bo.filetype == "help" then
      return "%f"
    end
    local cwd = vim.uv.cwd() .. ""
    if cwd ~= h.state.system_root_dir then
      cwd = cwd .. h.state.file_path_sep
    end
    local sanitized_file_path_relative_to_cwd = string.gsub(
      h.replace_prefix(
        h.replace_prefix(buf_name, cwd, ""),
        vim.uv.os_homedir() or "",
        "~"
      ),
      "%%",
      "%%%0"
    )
    return "%<" .. sanitized_file_path_relative_to_cwd
  end,
  {}
)

--- Diagnostics.
--- The diagnostics of the current buffer. Respects the value of:
--- `update_in_insert` from |vim.diagnostic.config()|.
--- Mockup: `e:2,w:1`
---@type BareComponent
bareline.components.diagnostics = bareline.BareComponent:new(function()
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
end, {
  redraw_on_autocmd = {
    event = "DiagnosticChanged",
  },
  cache_on_vim_modes = function()
    if vim.diagnostic.config().update_in_insert then
      return {}
    end
    return { "i" }
  end,
})

--- Cursor position.
--- The current cursor position in the format: line,column/total-lines.
--- Mockup: `181:43/329`
---@type BareComponent
bareline.components.position = bareline.BareComponent:new("%02l:%02c/%02L", {})

--- Current working directory.
--- When the current working directory (cwd) is the home dir then `~` is shown,
--- otherwise the tail of the cwd is displayed. When the buffer's name is not
--- under the cwd, the component is omitted.
--- Mockup: `bareline.nvim`
---@type BareComponent
bareline.components.cwd = bareline.BareComponent:new(function()
  local cwd_tail = nil
  local cwd = vim.uv.cwd() or ""
  local buf_name = vim.api.nvim_buf_get_name(0)
  if buf_name == "" or #buf_name == #h.replace_prefix(buf_name, cwd, "") then
    return nil
  end
  if cwd == vim.uv.os_homedir() then
    cwd_tail = "~"
  elseif cwd == h.state.system_root_dir then
    cwd_tail = h.state.system_root_dir
  else
    cwd_tail = vim.fn.fnamemodify(cwd, ":t")
  end
  return cwd_tail
end, {})

--- %m%h%r
--- Display the modified, help and read-only markers using the built-in statusline
--- fields, see 'statusline' for a list of fields where these are included.
---
--- Custom options:
---     {display_modified} `(boolean|fun():boolean)`
--- Control when the modified field (`%m`) is included in the statusline. Default:
--- true; meaning to always include the field. The only exception to the inclusion
--- is when the buffer has set 'nomodifiable'.
---
--- Mockups: `[+]`, `[Help][RO]`
---@type BareComponent
bareline.components.mhr = bareline.BareComponent:new(function(opts)
  local display_modified = h.providers.mhr.get_opt_display_modified(opts)
  if type(display_modified) == "function" then
    display_modified = display_modified()
  end
  local value = "%h%r"
  if display_modified and vim.bo.modifiable then
    value = "%m" .. value
  end
  return value
end, {})

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

h.providers.git_head = {}

--- Retrieve all, pick with highest precedence, validate, return.
---@param opts table `opts` field of the component.
---@return table Valid worktrees config.
function h.providers.git_head.get_opt_worktrees(opts)
  local worktrees = opts.worktrees
  if worktrees == nil then
    worktrees = bareline.config.components.git_head.worktrees
  end
  vim.validate({
    ["worktrees"] = { worktrees, { "table" }, true },
  })
  if worktrees ~= nil and #worktrees > 0 then
    for i = 1, #worktrees do
      vim.validate({
        ["worktrees[" .. i .. "].toplevel"] = {
          worktrees[i].toplevel,
          "string",
        },
        ["worktrees[" .. i .. "].gitdir"] = {
          worktrees[i].toplevel,
          "string",
        },
      })
    end
  end
  return worktrees
end

---@param gitdir string Git directory.
---@return string?
function h.providers.git_head.get_pretty_head(gitdir)
  local git_head = nil
  -- stylua: ignore start
  local rev_parse_o = vim.system({
    "git", "-C", gitdir, "rev-parse", "--abbrev-ref", "HEAD"
  }, { text = true }):wait()
  -- stylua: ignore end
  if rev_parse_o.code == 0 then
    git_head = vim.fn.trim(rev_parse_o.stdout, "\n", 2)
  end
  if git_head == "HEAD" then
    -- stylua: ignore start
    local rev_parse_short_o = vim.system({
      "git", "-C", gitdir, "rev-parse", "--short", "HEAD"
    }, { text = true }):wait()
    -- stylua: ignore end
    if rev_parse_short_o.code == 0 then
      git_head = vim.fn.trim(rev_parse_short_o.stdout, "\n", 2)
    end
  end
  if git_head ~= nil then
    return "(" .. git_head .. ")"
  end
  return git_head
end

---@param filepath string
---@param gitdir string
---@return boolean
function h.providers.git_head.is_filepath_tracked(filepath, gitdir)
  -- stylua: ignore start
  local ls_files_o = vim.system({
    "git", "--git-dir", gitdir, "--work-tree", vim.fn.fnamemodify(filepath, ":h"),
    "ls-files", "--error-unmatch", filepath,
  }):wait()
  -- stylua: ignore end
  return ls_files_o.code == 0
end

---@param gitdir string Git directory.
---@return boolean
function h.providers.git_head.should_show_untracked(gitdir)
  -- stylua: ignore start
  local config_o = vim.system({
    "git", "-C", gitdir, "config", "status.showUntrackedFiles",
  }, { text = true }):wait()
  -- stylua: ignore end
  local config_o_stdout = vim.trim(vim.fn.trim(config_o.stdout, "\n", 2))
  return config_o_stdout ~= "no" and config_o_stdout ~= "false"
end

---@param worktrees table Custom opt for the `git_head` component.
---@param filepath string Absolute file path of the file in the current buf.
---@return table? Matched worktree.
function h.providers.git_head.get_matching_worktree(worktrees, filepath)
  local matched_worktree = nil
  for _, wt in ipairs(worktrees) do
    if matched_worktree ~= nil then
      break
    end
    if vim.startswith(vim.fn.fnamemodify(filepath, ":h"), wt.toplevel) then
      local is_filepath_tracked =
        h.providers.git_head.is_filepath_tracked(filepath, wt.gitdir)
      if
        is_filepath_tracked
        or h.providers.git_head.should_show_untracked(wt.gitdir)
      then
        matched_worktree = wt
      end
    end
  end
  return matched_worktree
end

h.providers.lsp_servers = {}

--- LSP attached servers.
--- Returns the names of the LSP servers attached to the current buffer.
--- Example output: `{ "lua_ls" }`
---@return table
function h.providers.lsp_servers.get_names()
  return vim.tbl_map(function(client)
    return client.name
  end, vim.lsp.get_clients({ bufnr = 0 }))
end

h.providers.mhr = {}

--- Retrieve all, pick with highest precedence, validate, return.
---@param opts table `opts` field of the component.
---@return boolean Valid option value.
function h.providers.mhr.get_opt_display_modified(opts)
  local display_modified = opts.display_modified
  if display_modified == nil then
    display_modified = bareline.config.components.mhr.display_modified
  end
  vim.validate({
    ["opts.display_modified"] = { display_modified, { "boolean", "function" } },
  })
  return display_modified
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
  if h.component_cache_by_win_id[win_id] == nil then
    return nil
  end
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

---@param cache_on_vim_modes string[]|fun():string[]
---@return string[]
function h.get_vim_modes_for_cache(cache_on_vim_modes)
  if type(cache_on_vim_modes) == "function" then
    return cache_on_vim_modes()
  end
  if type(cache_on_vim_modes) == "table" then
    return cache_on_vim_modes
  end
  return {}
end

---@param component UserSuppliedComponent
---@return BareComponent
function h.standardize_component(component)
  vim.validate({
    component = { component, { "string", "function", "table" }, true },
  })
  if type(component) == "table" then
    return bareline.BareComponent:new(component.value, component.opts or {})
  elseif type(component) == "string" or type(component) == "function" then
    return bareline.BareComponent:new(component, {})
  end
  return bareline.BareComponent:new(nil, {})
end

---@param component UserSuppliedComponent
---@param skip_async boolean
---@return ComponentValue
function h.build_user_supplied_component(component, skip_async)
  local bare_component = h.standardize_component(component)
  local component_cache = h.get_component_cache(bare_component)
  local opts = bare_component.opts

  if opts.cache_on_vim_modes and component_cache then
    local short_current_vim_mode = vim.fn.mode():lower():sub(1, 1)
    local vim_modes_for_cache =
      h.get_vim_modes_for_cache(opts.cache_on_vim_modes)
    if vim.tbl_contains(vim_modes_for_cache, short_current_vim_mode) then
      return component_cache.value
    end
  end

  local value = bare_component:get(skip_async)
  h.store_bare_component_cache(bare_component, value)

  return value
end

h.component_separator = "  "

---@alias BareSection UserSuppliedComponent[]
---@alias BareStatusline BareSection[]

--- At least one component is expected to be built into a non-nil value.
---@param section table Statusline section, as may be provided by a user.
---@param skip_async boolean
---@return string
function h.build_section(section, skip_async)
  local built_components = {}
  for _, component in ipairs(section) do
    table.insert(
      built_components,
      h.build_user_supplied_component(component, skip_async)
    )
  end
  return table.concat(
    vim.tbl_filter(function(built_component)
      return built_component ~= nil
    end, built_components),
    h.component_separator
  )
end

--- Use this function when implementing a custom draw method.
--- See |bareline.draw_methods|.
---@param sections table
---@param skip_async boolean
---@return string _ String assignable to 'statusline'.
function h.build_statusline(sections, skip_async)
  local built_sections = {}
  for _, section in ipairs(sections) do
    table.insert(built_sections, h.build_section(section, skip_async))
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
  if vim.bo.filetype == "qf" then
    return true
  end
  return matched_filetype == nil
    and not vim.bo.buflisted
    and not vim.tbl_contains(special_non_plugin_filetypes, filetype)
end

---@param statusline BareStatusline
---@param skip_async boolean
function h.draw_window_statusline(statusline, skip_async)
  local built_statusline = h.build_statusline(statusline, skip_async)
  h.log(built_statusline, vim.log.levels.DEBUG)
  vim.wo.statusline = built_statusline
end

--- Draw the stl of the current window but skip the logic of all async components.
function h.draw_statusline_from_async_component()
  h.draw_statusline_if_plugin_window(
    bareline.config.statuslines.plugin,
    bareline.config.statuslines.active,
    true
  )
end

---@param statusline_1 BareStatusline Statusline for a plugin window.
---@param statusline_2 BareStatusline Statusline drawn otherwise.
function h.draw_statusline_if_plugin_window(
  statusline_1,
  statusline_2,
  skip_async
)
  if h.is_plugin_window(vim.fn.bufnr()) then
    h.draw_window_statusline(statusline_1, skip_async)
  else
    h.draw_window_statusline(statusline_2, skip_async)
  end
end

---@param nested_components_list BareComponent[] Statusline(s) definition(s).
---@param depth number Depth at which the components exist in the list.
---@param callback fun() Autocmd callback.
function h.create_bare_component_autocmds(
  nested_components_list,
  depth,
  callback
)
  local autocmds = vim
    .iter(nested_components_list)
    :flatten(depth)
    :map(function(bare_component)
      local bc = bare_component
      if type(bc) ~= "table" then
        return nil
      end
      local autocmd = bc.opts and bc.opts.redraw_on_autocmd
      if autocmd == nil then
        return
      end
      vim.validate({
        ["autocmd.event"] = {
          autocmd.event,
          { "string", "table" },
        },
      })
      if autocmd.opts == nil then
        autocmd.opts = {}
      end
      autocmd.opts.group = h.draw_methods_augroup
      autocmd.opts.callback = callback
      return autocmd
    end)
    -- Remove duplicate autocmds.
    :fold({}, function(acc, v)
      local is_duplicate_autocmd = vim.tbl_contains(acc, function(accv)
        return vim.deep_equal(accv, v)
      end, { predicate = true })
      if not is_duplicate_autocmd then
        table.insert(acc, v)
      end
      return acc
    end)
  -- Create autocmds.
  for _, autocmd in ipairs(autocmds) do
    vim.api.nvim_create_autocmd(autocmd.event, autocmd.opts)
  end
end

h.fs_path_to_uv_fs_event_handle = {}

---@param fs_path string
---@param callback fun()
---@return uv_fs_event_t
function h.create_uv_fs_event(fs_path, callback)
  local uv_fs_event, error = vim.uv.new_fs_event()
  assert(uv_fs_event, error)
  local success, err_name = uv_fs_event:start(
    fs_path,
    {},
    vim.schedule_wrap(function()
      callback()
    end)
  )
  assert(success, err_name)
  return uv_fs_event
end

function h.close_all_uv_fs_event_handles()
  for _, handle in pairs(h.fs_path_to_uv_fs_event_handle) do
    handle:close()
  end
  h.fs_path_to_uv_fs_event_handle = {}
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
  vim.validate({ config = { config, "table", true } })
  config =
    vim.tbl_deep_extend("force", vim.deepcopy(default_config), config or {})
  vim.validate({
    statuslines = { config.statuslines, "table" },
  })
  vim.validate({
    ["statuslines.active"] = { config.statuslines.active, "table" },
    ["statuslines.inactive"] = { config.statuslines.inactive, "table" },
    ["statuslines.plugin"] = { config.statuslines.plugin, "table" },
  })
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
function h.get_file_path_sep()
  local file_path_sep = "/"
  if string.sub(vim.uv.os_uname().sysname, 1, 7) == "Windows" then
    file_path_sep = "\\"
  end
  return file_path_sep
end

---@return string
function h.get_system_root_dir()
  local system_root_dir = "/"
  if string.sub(vim.uv.os_uname().sysname, 1, 7) == "Windows" then
    system_root_dir = "C:\\"
  end
  return system_root_dir
end

---@param message string
---@param level integer As per |vim.log.levels|.
function h.log(message, level)
  if not bareline.config.logging.enabled then
    return
  end
  if h.state.log_file ~= nil then
    local level_to_label = { "D", "I", "W", "E" }
    h.state.log_file:write(
      string.format(
        "%s %s - %s\n",
        level_to_label[level],
        vim.fn.strftime("%Y-%m-%dT%H:%M:%S"),
        message
      )
    )
    h.state.log_file:flush()
  end
end

h.state = {
  log_file = nil,
  file_path_sep = h.get_file_path_sep(),
  system_root_dir = h.get_system_root_dir(),
}

return bareline
