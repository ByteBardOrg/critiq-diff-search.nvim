local ok, mod = pcall(require, "critiq-diff-search")
if not ok then
  return
end

vim.api.nvim_create_user_command("DiffSearch", function(args)
  mod.search_command(table.concat(args.fargs, " "), {
    use_selection = args.range and args.range > 0,
    line1 = args.line1,
    line2 = args.line2,
  })
end, {
  nargs = "*",
  range = true,
  desc = "Diff-aware search across changed and removed lines",
})

vim.api.nvim_create_user_command("DiffSearchWord", function()
  mod.search_word()
end, {
  nargs = 0,
  desc = "DiffSearch using word under cursor",
})

vim.api.nvim_create_user_command("DiffSearchBuffer", function(args)
  mod.search_buffer(table.concat(args.fargs, " "))
end, {
  nargs = "+",
  desc = "DiffSearch scoped to current buffer",
})

vim.api.nvim_create_user_command("DiffSearchSelection", function()
  mod.search_selection()
end, {
  nargs = 0,
  desc = "DiffSearch selection alias",
})

vim.api.nvim_create_user_command("DiffSearchDebugContext", function()
  mod.debug_context()
end, {
  nargs = 0,
  desc = "Show resolved diff-search context",
})

vim.api.nvim_create_user_command("DiffSearchNext", function()
  mod.next_result()
end, {
  nargs = 0,
  desc = "Jump to next DiffSearch result",
})

vim.api.nvim_create_user_command("DiffSearchPrev", function()
  mod.prev_result()
end, {
  nargs = 0,
  desc = "Jump to previous DiffSearch result",
})

vim.api.nvim_create_user_command("CritiqOpenRepo", function()
  mod.open_critiq_repo()
end, {
  nargs = 0,
  desc = "Open current repository in Critiq",
})
