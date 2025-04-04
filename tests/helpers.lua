local h = {}

h.resources_dir = vim.uv.cwd() .. "/tests/resources"
h.tmp_testing_dir = vim.fn.stdpath("data") .. "/bareline.nvim/tmp_testing_dir"

--- It seems necessary to call sleep in a loop to go through several event loop cycles, so the
--- values of the vars of async components have an opportunity to be computed.
---@param child any Return value from `MiniTest.new_child_neovim()`
---@param milliseconds integer
---@param times integer
function h.sleep(child, milliseconds, times)
  for _ = 1, times do
    child.lua("vim.uv.sleep(" .. milliseconds .. ")")
  end
end

---@param child any Return value from `MiniTest.new_child_neovim()`
function h.get_child_evaluated_stl(child)
  return child.lua_get("vim.api.nvim_eval_statusline(vim.wo.statusline, {}).str")
end

function h.rename_git_dirs_for_testing()
  vim.uv.fs_rename(
    h.resources_dir .. "/git_dir_branch/dot_git",
    h.resources_dir .. "/git_dir_branch/.git"
  )
  vim.uv.fs_rename(
    h.resources_dir .. "/git_dir_branch_no_showUntrackedFiles/dot_git",
    h.resources_dir .. "/git_dir_branch_no_showUntrackedFiles/.git"
  )
  vim.uv.fs_rename(
    h.resources_dir .. "/git_dir_hash/dot_git",
    h.resources_dir .. "/git_dir_hash/.git"
  )
  vim.uv.fs_rename(
    h.resources_dir .. "/git_dir_tag/dot_git",
    h.resources_dir .. "/git_dir_tag/.git"
  )
end

function h.rename_git_dirs_for_tracking()
  vim.uv.fs_rename(
    h.resources_dir .. "/git_dir_branch/.git",
    h.resources_dir .. "/git_dir_branch/dot_git"
  )
  vim.uv.fs_rename(
    h.resources_dir .. "/git_dir_branch_no_showUntrackedFiles/.git",
    h.resources_dir .. "/git_dir_branch_no_showUntrackedFiles/dot_git"
  )
  vim.uv.fs_rename(
    h.resources_dir .. "/git_dir_hash/.git",
    h.resources_dir .. "/git_dir_hash/dot_git"
  )
  vim.uv.fs_rename(
    h.resources_dir .. "/git_dir_tag/.git",
    h.resources_dir .. "/git_dir_tag/dot_git"
  )
end

function h.create_git_worktree()
  vim
    .system({
      "git",
      "--git-dir",
      h.resources_dir .. "/git_dir_branch/.git",
      "worktree",
      "add",
      "-B",
      "hotfix",
      h.resources_dir .. "/git_dir_branch_worktree",
    })
    :wait()
end

function h.remove_git_worktree()
  vim
    .system({
      "git",
      "--git-dir",
      h.resources_dir .. "/git_dir_branch/.git",
      "worktree",
      "remove",
      h.resources_dir .. "/git_dir_branch_worktree",
    })
    :wait()
end

function h.create_tmp_testing_dir()
  vim.fn.mkdir(h.tmp_testing_dir, "p")
  vim.fn.mkdir(h.tmp_testing_dir .. "/sub_dir_a/sub_dir_a_a/sub_dir_a_a_a", "p")
  vim.fn.mkdir(h.tmp_testing_dir .. "/sub_dir_b/sub_dir_b_b/sub_dir_b_b_b", "p")
  vim.fn.writefile({}, h.tmp_testing_dir .. "/file.txt")
  vim.fn.writefile({}, h.tmp_testing_dir .. "/untracked.txt")
  vim.fn.writefile({}, h.tmp_testing_dir .. "/sub_dir_a/sub_dir_a_a/file.txt")
  vim.fn.writefile({}, h.tmp_testing_dir .. "/sub_dir_a/sub_dir_a_a/file2.txt")
  vim.fn.writefile({}, h.tmp_testing_dir .. "/sub_dir_b/sub_dir_b_b/sub_dir_b_b_b/file.txt")
end

function h.delete_tmp_testing_dir()
  vim.fn.delete(h.tmp_testing_dir .. "/file.txt")
  vim.fn.delete(h.tmp_testing_dir .. "/untracked.txt")
  vim.fn.delete(h.tmp_testing_dir .. "/sub_dir_a/sub_dir_a_a/file.txt")
  vim.fn.delete(h.tmp_testing_dir .. "/sub_dir_a/sub_dir_a_a/file2.txt")
  vim.fn.delete(h.tmp_testing_dir .. "/sub_dir_b/sub_dir_b_b/sub_dir_b_b_b/file.txt")
  vim.fn.delete(h.tmp_testing_dir .. "/sub_dir_a/sub_dir_a_a/sub_dir_a_a_a", "d")
  vim.fn.delete(h.tmp_testing_dir .. "/sub_dir_a/sub_dir_a_a", "d")
  vim.fn.delete(h.tmp_testing_dir .. "/sub_dir_a", "d")
  vim.fn.delete(h.tmp_testing_dir .. "/sub_dir_b/sub_dir_b_b/sub_dir_b_b_b", "d")
  vim.fn.delete(h.tmp_testing_dir .. "/sub_dir_b/sub_dir_b_b", "d")
  vim.fn.delete(h.tmp_testing_dir .. "/sub_dir_b", "d")
  vim.fn.delete(h.tmp_testing_dir, "d")
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

return h
