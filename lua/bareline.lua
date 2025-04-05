--- *bareline* A statusline plugin for the pragmatic.
---
--- MIT License Copyright (c) 2024 Hernán Cervera.
---
--- Contents:
---
--- 1. Introduction                             |bareline-introduction|
--- 2. Configuration                            |bareline-configuration|
--- 3. Built-in components                      |bareline-built-in-components|
--- 4. Create your own component                |bareline-create-your-own-component|
--- 5. Control statusline redraws               |bareline-control-stl-redraws|
---
---                   Press `gO` to load the table of contents in the location list.
--- ==============================================================================
--- #tag bareline-introduction
--- Introduction ~
---
--- Goals
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

--- Quickstart
---
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
          bareline.config.statuslines.active,
          h.constants.ANY_VAR_NAME
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
        "virtualedit",
        "scrolloff",
        "cmdheight",
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

  -- Create component-specific autocmds.
  h.create_bare_component_autocmds(bareline.config.statuslines.active)
  h.create_bare_component_autocmds(bareline.config.statuslines.inactive)
  h.create_bare_component_autocmds(bareline.config.statuslines.inactive)

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
      bareline.config.statuslines.active,
      h.constants.ANY_VAR_NAME
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
          bareline.components.filepath_relative_to_cwd,
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
          bareline.components.filepath_relative_to_cwd,
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
      level = vim.log.levels.DEBUG,
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
---
--- #tag bareline.config.logging.level
---     {level} `(integer)`
--- Log statements on this level and up are written to the log file, the others
--- are discarded. Default: `vim.log.levels.DEBUG`.

--- #delimiter

---
--- All |bareline-built-in-components| are a |bareline.BareComponent|.

--- Standardized statusline component.
--- All |bareline-built-in-components| are a |bareline.BareComponent|. To create
--- your own components, you can use this class or use simpler types as described
--- in |bareline-custom-components|.
---@class BareComponent
---@field value string|fun(opts:BareComponentCommonOpts):any Provides the value
--- displayed in the statusline, like the Vim mode. When the value is a function,
--- it gets the field `opts`. This is powerful, as it allows configuring
--- components after creation and setting custom options.
--- See: |bareline.BareComponent:config()|
---@field opts BareComponentCommonOpts
bareline.BareComponent = {}
bareline.BareComponent["__index"] = bareline.BareComponent

--- #tag bareline-BareComponentCommonOpts
--- Options applicable to any |bareline.BareComponent|.
---@class BareComponentCommonOpts
---@field callback fun(opts:BareComponentCommonOpts, set:fun(var_value:any))?
--- For async components. See |bareline-create-your-own-component|.
---@field register_redraw_on_autocmd table? Expects a table with the keys `event`
--- and `opts`. These values are passed as-is to |vim.api.nvim_create_autocmd()|.
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
---@return string?
function bareline.BareComponent:get()
  local value = nil
  self._value = value
  if type(self.value) == "function" then
    value = self.value(self.opts)
    self._value = value
  elseif type(self.value) == "string" then
    value = self.value
    self._value = value
  end
  if value ~= nil and self.opts ~= nil and self.opts.mask then
    vim.validate("mask", self.opts.mask, "string")
    value = string.gsub(value, ".", string.sub(self.opts.mask, 1, 1))
    self._value = value
  end
  return value
end


-- COMPONENTS

bareline.components = {}

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
  register_redraw_on_autocmd = {
    event = "ModeChanged",
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

local component_git_head_var_name = "bareline_git_head"

--- Git HEAD.
---
--- Attributes:
--- * async
---
--- Git needs to be installed for this component to work.
---
--- The search for the HEAD is done in relationship to the name of the current
--- buffer, Neovim's cwd is irrelevant. To learn the HEAD, a repo is needed.
---
--- Steps to find a repo:
--- 1. If the buf name (filepath) is empty, do nothing.
--- 2. Else, search with: `git -C {parent} rev-parse --absolute-git-dir`, where
---    `{parent}` is the parent dir of the filepath.
--- 3. Else, search through `worktrees` in the order they are provided. A matching
---    worktree is one which its absolute toplevel is the start of the absolute
---    parent dir of the filepath.
---
--- A HEAD is shown if and only if a Git repo was found and either the file is
--- tracked (exists in a revision or is staged) or the config option
--- `status.showUntrackedFiles` is enabled.
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
bareline.components.git_head =
  bareline.BareComponent:new(component_git_head_var_name, {
    callback = function(opts, set)
      local filepath = vim.api.nvim_buf_get_name(0)
      if filepath == "" then
        set(nil)
        return
      end
      local parent_path = vim.fn.fnamemodify(filepath, ":h")
      vim.system(
        { "git", "-C", parent_path, "rev-parse", "--absolute-git-dir" },
        { text = true },
        vim.schedule_wrap(function(rev_parse_o)
          local gitdir = nil
          if rev_parse_o.code == 0 then
            gitdir = vim.fn.trim(rev_parse_o.stdout, "\n", 2)
          end
          if gitdir ~= nil then
            h.providers.git_head.is_filepath_tracked(
              filepath,
              gitdir,
              parent_path,
              function(is_filepath_tracked)
                if is_filepath_tracked then
                  -- Found standard repo or work tree from `git worktree add`.
                  bareline.register_redraw_on_fs_event(
                    gitdir,
                    component_git_head_var_name
                  )
                  h.providers.git_head.get_pretty_head(
                    gitdir,
                    function(pretty_head)
                      set(pretty_head)
                    end
                  )
                else
                  h.providers.git_head.should_show_untracked(
                    gitdir,
                    function(should_show_untracked)
                      if should_show_untracked then
                        -- Found standard repo or work tree from `git worktree add`.
                        bareline.register_redraw_on_fs_event(
                          gitdir,
                          component_git_head_var_name
                        )
                        h.providers.git_head.get_pretty_head(
                          gitdir,
                          function(pretty_head)
                            set(pretty_head)
                          end
                        )
                      else
                        set(nil)
                        return
                      end
                    end
                  )
                end
              end
            )
          else
            local worktree = h.providers.git_head.get_matching_worktree(
              h.providers.git_head.get_opt_worktrees(opts),
              filepath
            )
            if worktree ~= nil then
              h.providers.git_head.is_filepath_tracked(
                filepath,
                worktree.gitdir,
                worktree.toplevel,
                function(is_filepath_tracked)
                  if is_filepath_tracked then
                    -- Found work tree from `worktrees` custom component opt.
                    bareline.register_redraw_on_fs_event(
                      worktree.gitdir,
                      component_git_head_var_name
                    )
                    h.providers.git_head.get_pretty_head(
                      worktree.gitdir,
                      function(pretty_head)
                        set(pretty_head)
                      end
                    )
                  else
                    h.providers.git_head.should_show_untracked(
                      worktree.gitdir,
                      function(should_show_untracked)
                        if should_show_untracked then
                          -- Found work tree from `worktrees` custom component opt.
                          bareline.register_redraw_on_fs_event(
                            worktree.gitdir,
                            component_git_head_var_name
                          )
                          h.providers.git_head.get_pretty_head(
                            worktree.gitdir,
                            function(pretty_head)
                              set(pretty_head)
                            end
                          )
                        else
                          set(nil)
                          return
                        end
                      end
                    )
                  end
                end
              )
            end
          end
        end)
      )
    end,
    register_redraw_on_autocmd = {
      var_name = component_git_head_var_name,
      event = {
        "VimResume",
        "FocusGained",
        "CmdlineLeave",
        "BufEnter",
        "WinEnter",
      },
    },
  })

local component_lsp_servers_var_name = "bareline_lsp_servers"

--- Lsp servers.
---
--- Attritubes:
--- * async
---
--- The LSP servers attached to the current buffer.
--- Mockup: `[lua_ls]`
---@type BareComponent
bareline.components.lsp_servers =
  bareline.BareComponent:new(component_lsp_servers_var_name, {
    callback = function(_, set)
      h.providers.lsp_servers.get_names(function(lsp_servers)
        if lsp_servers == nil or vim.tbl_isempty(lsp_servers) then
          set(nil)
        else
          set("[" .. vim.fn.join(lsp_servers, ",") .. "]")
        end
      end)
    end,
    {
      register_redraw_on_autocmd = {
        var_name = component_lsp_servers_var_name,
        event = { "LspAttach", "LspDetach" },
      },
    },
  })

--- Stable `%f`.
--- If the file is in the cwd (|:pwd|) at any depth level, the filepath relative
--- to the cwd is displayed. Otherwise, the full filepath is displayed.
--- Mockup: `lua/bareline.lua`
---@type BareComponent
bareline.components.filepath_relative_to_cwd = bareline.BareComponent:new(
  function()
    local buf_name = vim.api.nvim_buf_get_name(0)
    if buf_name == "" or vim.bo.filetype == "help" then
      return "%f"
    end
    local cwd = vim.uv.cwd() .. ""
    if cwd ~= h.state.system_root_dir then
      cwd = cwd .. h.state.fs_sep
    end
    return "%<"
      .. h.replace_prefix(
        h.replace_prefix(buf_name, cwd, ""),
        vim.uv.os_homedir() or "",
        "~"
      )
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
  if output == "" then
    return nil
  end
  return string.sub(output, 1, #output - 1)
end, {
  register_redraw_on_autocmd = {
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
--- The tail of the current working directory (cwd).
--- Mockup: `bareline.nvim`
---@type BareComponent
bareline.components.cwd = bareline.BareComponent:new(function()
  local cwd_tail = nil
  local cwd = vim.uv.cwd() or ""
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

---@alias UserSuppliedComponent any|fun():any|BareComponent

--- #delimiter
--- #tag bareline-create-your-own-component
--- Create your own component ~
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
---    local component_wrap = function()
---      local label = nil
---      if vim.wo.wrap then
---        label = "S-WRAP"
---      end
---      return label
---    end
--- <
--- 3. |bareline.BareComponent|: This allows the most granular customization.
---
--- For many use cases you don't need to use a |bareline.BareComponent| since out
--- of the box the statusline gets redrawn on several autocmds.
--- See: |bareline-control-stl-redraws|.
---
--- Create an async component ~
---
--- * The component must be a |bareline.BareComponent|.
--- * The `value` of the `BareComponent` must be the name (string) of a buf-local
---   var. You don't need to do anytyhing prior with this var, just pass the name.
--- * The `callback` of the `BareComponent` must be set. This function assigns the
---   value for the buf-local var. To achieve that, call `set()` in `callback`
---   exactly once, passing the value of the buf-local var as the single arg.
--- * Distribute the processing in the `callback` function in as many event loop
---   cycles as possible. If the whole async function runs in a single cycle, then
---   there is no performance gain vs a sync component. Leverage the `on_exit`
---   callback of |vim.system| and consider using |vim.defer_fn()|. Go down the
---   road of callback hell.

--- #delimiter
--- #tag bareline-control-stl-redraws
---
--- Control statusline redraws ~
---
--- Bareline does not use a timer to redraw the statusline, instead it uses:
--- 1. |autocmd|s. See |bareline-BareComponentCommonOpts|, `register_redraw_on_autocmd`.
--- 2. |uv| file watchers. See |bareline.register_redraw_on_fs_event()|.
---
--- These are the base |autocmd-events| to redraw the stl: BufEnter, BufWinEnter,
--- WinEnter, VimResume, FocusGained, OptionSet, DirChanged, TermLeave.
---
--- With the default config, these are the fs paths watched to redraw the stl:
--- * Git repository directories to fulfill |bareline.components.git_head|.

--- Conditionally create a |uv_fs_event_t| to monitor `fs_path` for changes. When
--- a change is detected, redraw the statusline of the current window. If a luv fs
--- event handle already exists for the `fs_path`, then do nothing.
---@param fs_path string Full or relative path to a dir or file.
---@param var_name string
function bareline.register_redraw_on_fs_event(fs_path, var_name)
  local fs_path_absolute = vim.uv.fs_realpath(fs_path)
  if
    fs_path_absolute ~= nil
    and h.fs_path_to_uv_fs_event_handle[fs_path_absolute] == nil
  then
    local uv_fs_event_handle = h.create_uv_fs_event(fs_path_absolute, function()
      if var_name then
        h.log("Redraw on *fs_event*: For var: " .. var_name, vim.log.levels.INFO)
      end
      h.draw_statusline_if_plugin_window(
        bareline.config.statuslines.plugin,
        bareline.config.statuslines.active,
        var_name
      )
    end)
    h.fs_path_to_uv_fs_event_handle[fs_path_absolute] = uv_fs_event_handle
    h.log(
      "Added to fs_path_to_uv_fs_event_handle. Resulting table: "
        .. vim.inspect(h.fs_path_to_uv_fs_event_handle),
      vim.log.levels.INFO
    )
  end
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

h.providers.git_head = {}

--- Retrieve all, pick with highest precedence, validate, return.
---@param opts table `opts` field of the component.
---@return table Valid worktrees config.
function h.providers.git_head.get_opt_worktrees(opts)
  local worktrees = opts.worktrees
  if worktrees == nil then
    worktrees = bareline.config.components.git_head.worktrees
  end
  vim.validate("worktrees", worktrees, "table", true)
  if worktrees ~= nil and #worktrees > 0 then
    for i = 1, #worktrees do
      vim.validate(
        "worktrees[" .. i .. "].toplevel",
        worktrees[i].toplevel,
        "string"
      )
      vim.validate(
        "worktrees[" .. i .. "].gitdir",
        worktrees[i].toplevel,
        "string"
      )
    end
  end
  return worktrees
end

---@param git_head string
---@return string
local function format_git_head(git_head)
  return "(" .. git_head .. ")"
end

---@param gitdir string Git directory.
---@param callback fun(pretty_head:string?)
---@return string?
function h.providers.git_head.get_pretty_head(gitdir, callback)
  vim.system(
    { "git", "-C", gitdir, "rev-parse", "--abbrev-ref", "HEAD" },
    { text = true },
    vim.schedule_wrap(function(rev_parse_abbrev_ref_o)
      local git_head = nil
      if rev_parse_abbrev_ref_o.code == 0 then
        git_head = vim.fn.trim(rev_parse_abbrev_ref_o.stdout, "\n", 2)
      end
      if git_head == "HEAD" then
        vim.system(
          { "git", "-C", gitdir, "rev-parse", "--short", "HEAD" },
          { text = true },
          vim.schedule_wrap(function(rev_parse_short_o)
            if rev_parse_short_o.code == 0 then
              git_head = vim.fn.trim(rev_parse_short_o.stdout, "\n", 2)
            end
            if git_head ~= nil then
              callback(format_git_head(git_head))
            else
              callback(nil)
            end
          end)
        )
      elseif git_head ~= nil then
        callback(format_git_head(git_head))
      else
        callback(nil)
      end
    end)
  )
end

---@param filepath string
---@param gitdir string
---@param toplevel string
---@param callback fun(is_file_tracked:boolean)
function h.providers.git_head.is_filepath_tracked(
  filepath,
  gitdir,
  toplevel,
  callback
)
  -- stylua: ignore start
  vim.system({
    "git", "--git-dir", gitdir, "--work-tree", toplevel,
    "ls-files", "--error-unmatch", filepath,
  }, {}, function(ls_files_o)
    callback(ls_files_o.code == 0)
  end)
  -- stylua: ignore end
end

--- Config key `status.showUntrackedFiles` explained here:
--- <https://git-scm.com/docs/git-config>.
---@param gitdir string Git directory.
---@param callback fun(should_show_untracked:boolean)
function h.providers.git_head.should_show_untracked(gitdir, callback)
  vim.system(
    { "git", "-C", gitdir, "config", "status.showUntrackedFiles" },
    { text = true },
    vim.schedule_wrap(function(config_o)
      local config_o_stdout = vim.trim(vim.fn.trim(config_o.stdout, "\n", 2))
      callback(
        config_o_stdout == "" -- Default behavior is yes.
          or config_o_stdout == "normal"
          or config_o_stdout == "all"
          or config_o_stdout == "yes"
          or config_o_stdout == "true"
      )
    end)
  )
end

---@param worktrees table Custom opt for the `git_head` component.
---@param filepath string Absolute file path of the file in the current buf.
---@return table? Matched worktree.
function h.providers.git_head.get_matching_worktree(worktrees, filepath)
  local matched_worktree = nil
  for _, worktree in ipairs(worktrees) do
    local toplevel_realpath = vim.uv.fs_realpath(worktree.toplevel) or ""
    if vim.startswith(vim.fn.fnamemodify(filepath, ":h"), toplevel_realpath) then
      matched_worktree = worktree
      break
    end
  end
  return matched_worktree
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
---@param opts table `opts` field of the component.
---@return boolean Valid option value.
function h.providers.mhr.get_opt_display_modified(opts)
  local display_modified = opts.display_modified
  if display_modified == nil then
    display_modified = bareline.config.components.mhr.display_modified
  end
  vim.validate(
    "opts.display_modified",
    display_modified,
    { "boolean", "function" }
  )
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
  vim.validate("component", component, { "string", "function", "table" }, true)
  if type(component) == "table" then
    return bareline.BareComponent:new(component.value, component.opts or {})
  elseif type(component) == "string" or type(component) == "function" then
    return bareline.BareComponent:new(component, {})
  end
  return bareline.BareComponent:new(nil, {})
end

---@param component BareComponent
function h.call_async_component_callback(component)
  vim.defer_fn(function()
    component.opts.callback(component.opts, function(var_value)
      vim.b[component._value] = var_value
      h.draw_statusline_if_plugin_window(
        bareline.config.statuslines.plugin,
        bareline.config.statuslines.active
      )
    end)
  end, 0)
end

---@param component BareComponent
---@param var_name string?
---@return ComponentValue
function h.build_component(component, var_name)
  local component_cache = h.get_component_cache(component)
  local opts = component.opts

  if opts.cache_on_vim_modes and component_cache then
    local short_current_vim_mode = vim.fn.mode():lower():sub(1, 1)
    local vim_modes_for_cache = h.get_vim_modes_for_cache(opts.cache_on_vim_modes)
    if vim.tbl_contains(vim_modes_for_cache, short_current_vim_mode) then
      return component_cache.value
    end
  end

  local value = component:get()
  if type(component.opts.callback) == "function" and component._value ~= nil then
    if vim.b[component._value] ~= nil and vim.b[component._value] ~= "" then
      value = "%{b:" .. component._value .. "}"
    else
      value = nil
    end
    if var_name == component._value or var_name == h.constants.ANY_VAR_NAME then
      h.call_async_component_callback(component)
    end
  end
  h.store_bare_component_cache(component, value)
  return value
end

h.component_separator = "  "

---@alias BareSection UserSuppliedComponent[]
---@alias BareStatusline BareSection[]

--- At least one component is expected to be built into a non-nil value.
---@param section table Statusline section, as may be provided by a user.
---@param var_name string?
---@return string
function h.build_section(section, var_name)
  local built_components = {}
  for _, component in ipairs(section) do
    table.insert(
      built_components,
      h.build_component(h.standardize_component(component), var_name)
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
---@param var_name string?
---@return string _ String assignable to 'statusline'.
function h.build_statusline(sections, var_name)
  local built_sections = {}
  for _, section in ipairs(sections) do
    table.insert(built_sections, h.build_section(section, var_name))
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

---@param win_id integer
---@return boolean
function h.is_win_floating(win_id)
  -- See |api-floatwin| to learn how to check whether a win is floating.
  return vim.api.nvim_win_get_config(win_id).relative ~= ""
end

---@param statusline BareStatusline
---@param var_name string?
function h.draw_window_statusline(statusline, var_name)
  if h.is_win_floating(0) then
    return
  end
  local built_statusline = h.build_statusline(statusline, var_name)
  vim.wo.statusline = built_statusline
  h.log(built_statusline)
end

---@param statusline_1 BareStatusline Statusline for a plugin window.
---@param statusline_2 BareStatusline Statusline drawn otherwise.
---@param var_name string?
function h.draw_statusline_if_plugin_window(statusline_1, statusline_2, var_name)
  if h.is_plugin_window(vim.fn.bufnr()) then
    h.draw_window_statusline(statusline_1, var_name)
  else
    h.draw_window_statusline(statusline_2, var_name)
  end
end

---@param statusline BareStatusline
function h.create_bare_component_autocmds(statusline)
  vim.iter(statusline):flatten():each(function(component)
    if
      type(component) ~= "table"
      or type(component.opts) ~= "table"
      or type(component.opts.register_redraw_on_autocmd) ~= "table"
      or component.opts.register_redraw_on_autocmd.event == nil
    then
      return
    end
    local autocmd = component.opts.register_redraw_on_autocmd
    autocmd.opts = autocmd.opts or {}
    autocmd.opts.group = h.draw_methods_augroup
    autocmd.opts.callback = function()
      if autocmd.var_name then
        h.log(
          "Redraw on *autocmd* for var: " .. autocmd.var_name,
          vim.log.levels.INFO
        )
      end
      h.draw_statusline_if_plugin_window(
        bareline.config.statuslines.plugin,
        bareline.config.statuslines.active,
        autocmd.var_name
      )
    end
    -- Duplicates might be getting registered.
    vim.api.nvim_create_autocmd(autocmd.event, autocmd.opts)
  end)
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
  vim.validate("config", config, "table", true)
  config =
    vim.tbl_deep_extend("force", vim.deepcopy(default_config), config or {})
  vim.validate("statuslines", config.statuslines, "table")
  vim.validate("statuslines.active", config.statuslines.active, "table")
  vim.validate("statuslines.inactive", config.statuslines.inactive, "table")
  vim.validate("statuslines.plugin", config.statuslines.plugin, "table")
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
  level = level or vim.log.levels.DEBUG
  if h.should_log(level) then
    vim.defer_fn(function()
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
    end, 0)
  end
end

h.state = {
  log_file = nil,
  fs_sep = h.get_fs_sep(),
  system_root_dir = h.get_system_root_dir(),
}

h.constants = {
  ANY_VAR_NAME = "bareline_any",
}

return bareline
