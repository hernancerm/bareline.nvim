local H = {}

function H.rename_gitdir_to_dotdir()
  vim.uv.fs_rename(
    "tests/resources/git_dir_branch/gitdir/",
    "tests/resources/git_dir_branch/.git/"
  )
  vim.uv.fs_rename(
    "tests/resources/git_dir_hash/gitdir/",
    "tests/resources/git_dir_hash/.git/"
  )
  vim.uv.fs_rename(
    "tests/resources/git_dir_tag/gitdir/",
    "tests/resources/git_dir_tag/.git/"
  )
end

function H.rename_dotdir_to_gitdir()
  vim.uv.fs_rename(
    "tests/resources/git_dir_branch/.git/",
    "tests/resources/git_dir_branch/gitdir/"
  )
  vim.uv.fs_rename(
    "tests/resources/git_dir_hash/.git/",
    "tests/resources/git_dir_hash/gitdir/"
  )
  vim.uv.fs_rename(
    "tests/resources/git_dir_tag/.git/",
    "tests/resources/git_dir_tag/gitdir/"
  )
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
