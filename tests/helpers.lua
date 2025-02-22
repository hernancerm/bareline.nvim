local h = {}

h.resources_dir = vim.uv.cwd() .. "/tests/resources"
h.tmp_dir_for_testing = vim.fn.stdpath("data")
  .. "/bareline.nvim/tmp_dir_for_testing"

function h.rename_gitdir_to_dotdir()
  vim.uv.fs_rename(
    h.resources_dir .. "/git_dir_branch/gitdir",
    h.resources_dir .. "/git_dir_branch/.git"
  )
  vim.uv.fs_rename(
    h.resources_dir .. "/git_dir_hash/gitdir",
    h.resources_dir .. "/git_dir_hash/.git"
  )
  vim.uv.fs_rename(
    h.resources_dir .. "/git_dir_tag/gitdir",
    h.resources_dir .. "/git_dir_tag/.git"
  )
end

function h.rename_dotdir_to_gitdir()
  vim.uv.fs_rename(
    h.resources_dir .. "/git_dir_branch/.git",
    h.resources_dir .. "/git_dir_branch/gitdir"
  )
  vim.uv.fs_rename(
    h.resources_dir .. "/git_dir_hash/.git",
    h.resources_dir .. "/git_dir_hash/gitdir"
  )
  vim.uv.fs_rename(
    h.resources_dir .. "/git_dir_tag/.git",
    h.resources_dir .. "/git_dir_tag/gitdir"
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

function h.create_tmp_dir_with_contents_for_testing()
  vim.fn.mkdir(h.tmp_dir_for_testing, "p")
  -- Sub-dirs and files.
  vim.fn.mkdir(
    h.tmp_dir_for_testing .. "/sub_dir_a/sub_dir_a_a/sub_dir_a_a_a",
    "p"
  )
  vim.fn.mkdir(
    h.tmp_dir_for_testing .. "/sub_dir_b/sub_dir_b_b/sub_dir_b_b_b",
    "p"
  )
  vim.fn.writefile({ "text" }, h.tmp_dir_for_testing .. "/file.txt")
  vim.fn.writefile(
    { "text" },
    h.tmp_dir_for_testing .. "/sub_dir_a/sub_dir_a_a/file.txt"
  )
  vim.fn.writefile(
    { "text" },
    h.tmp_dir_for_testing .. "/sub_dir_b/sub_dir_b_b/sub_dir_b_b_b/file.txt"
  )
end

function h.delete_tmp_dir_for_testing()
  vim.fn.delete(h.tmp_dir_for_testing .. "/file.txt")
  vim.fn.delete(h.tmp_dir_for_testing .. "/sub_dir_a/sub_dir_a_a/file.txt")
  vim.fn.delete(
    h.tmp_dir_for_testing .. "/sub_dir_b/sub_dir_b_b/sub_dir_b_b_b/file.txt"
  )
  vim.fn.delete(h.tmp_dir_for_testing, "d")
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
