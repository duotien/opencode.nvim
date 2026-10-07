vim.api.nvim_create_user_command("OpencodeSession", function(opts)
  if opts.args == "--clear" then
    require("opencode").clear_session()
  elseif opts.args == "" then
    require("opencode").pick_session()
  else
    vim.notify("opencode: unknown argument `" .. opts.args .. "` (use `--clear` to unpin)", vim.log.levels.ERROR, {
      title = "opencode",
    })
  end
end, {
  nargs = "?",
  desc = "Pick (pin) which OpenCode session this Neovim instance drives (`--clear` unpins)",
})
