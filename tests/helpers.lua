local Helpers = {}

function Helpers.rename_gitdir_to_dotdir()
  vim.uv.fs_rename("tests/resources/git_dir_branch/gitdir/",
  "tests/resources/git_dir_branch/.git/")
  vim.uv.fs_rename("tests/resources/git_dir_hash/gitdir/",
  "tests/resources/git_dir_hash/.git/")
  vim.uv.fs_rename("tests/resources/git_dir_tag/gitdir/",
  "tests/resources/git_dir_tag/.git/")
end

function Helpers.rename_dotdir_to_gitdir()
  vim.uv.fs_rename("tests/resources/git_dir_branch/.git/",
  "tests/resources/git_dir_branch/gitdir/")
  vim.uv.fs_rename("tests/resources/git_dir_hash/.git/",
  "tests/resources/git_dir_hash/gitdir/")
  vim.uv.fs_rename("tests/resources/git_dir_tag/.git/",
  "tests/resources/git_dir_tag/gitdir/")
end

return Helpers
