local M = {}

local function absolute_path(repo_root, file)
  if not repo_root or repo_root == "" then
    return file
  end
  if file:sub(1, 1) == "/" then
    return file
  end
  return repo_root:gsub("/$", "") .. "/" .. file
end

local function install_quickfix_mappings()
  local info = vim.fn.getqflist({ winid = 1 })
  if not info.winid or info.winid == 0 then
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(info.winid)
  if not bufnr or bufnr == 0 then
    return
  end

  local opts = { buffer = bufnr, silent = true, noremap = true }
  vim.keymap.set("n", "<CR>", function()
    require("critiq-diff-search").open_qf_cursor_result()
  end, opts)
  vim.keymap.set("n", "<2-LeftMouse>", function()
    require("critiq-diff-search").open_qf_cursor_result()
  end, opts)
end

function M.present(results, opts)
  opts = opts or {}
  local items = {}

  for _, result in ipairs(results) do
    local absolute = absolute_path(result.repo_root, result.file)
    table.insert(items, {
      filename = absolute,
      lnum = result.line,
      col = result.col or 1,
      text = string.format("[%s] %s", result.side, result.text),
      user_data = {
        source = "critiq-diff-search",
        side = result.side,
        file = result.file,
        repo_root = result.repo_root,
      },
    })
  end

  local title = opts.title or "DiffSearch"
  vim.fn.setqflist({}, " ", {
    title = title,
    context = {
      source = "critiq-diff-search",
    },
    items = items,
  })

  if #items == 0 then
    if opts.notify ~= false then
      vim.notify("DiffSearch: no diff-aware matches found", vim.log.levels.INFO)
    end
    return
  end

  if opts.open_quickfix ~= false then
    vim.cmd("copen")
    install_quickfix_mappings()
  end
end

return M
