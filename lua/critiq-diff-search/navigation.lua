local M = {}

local function notify(message, level, enabled)
  if enabled ~= false then
    vim.notify(message, level or vim.log.levels.INFO)
  end
end

local function infer_side(item)
  if item.user_data and item.user_data.side then
    return item.user_data.side
  end
  local side = item.text and item.text:match("^%[([AR])%]")
  return side
end

local function infer_file(item)
  if item.user_data and item.user_data.file then
    return item.user_data.file
  end
  if item.filename and item.filename ~= "" then
    return item.filename
  end
  if item.bufnr and item.bufnr > 0 then
    return vim.api.nvim_buf_get_name(item.bufnr)
  end
  return nil
end

local function set_qf_index(id, items, idx, title)
  local ok = pcall(vim.fn.setqflist, {}, "a", { id = id, idx = idx })
  if ok then
    return
  end

  vim.fn.setqflist({}, " ", {
    title = title,
    context = { source = "critiq-diff-search" },
    items = items,
    idx = idx,
  })
end

local function set_cursor(winid, line, col)
  if not winid or not vim.api.nvim_win_is_valid(winid) then
    return false
  end
  pcall(vim.api.nvim_set_current_win, winid)
  pcall(vim.api.nvim_win_set_cursor, winid, { math.max(1, line or 1), math.max((col or 1) - 1, 0) })
  return true
end

local function open_in_diffview(item, side)
  local ok_lib, lib = pcall(require, "diffview.lib")
  if not ok_lib or not lib or type(lib.get_current_view) ~= "function" then
    return false
  end

  local view = lib.get_current_view()
  if not view or type(view.set_file_by_path) ~= "function" then
    return false
  end

  local rel_file = infer_file(item)
  if not rel_file or rel_file == "" then
    return false
  end

  if rel_file:sub(1, 1) == "/" and item.user_data and item.user_data.repo_root then
    local root = tostring(item.user_data.repo_root):gsub("/$", "")
    local prefix = root .. "/"
    if rel_file:sub(1, #prefix) == prefix then
      rel_file = rel_file:sub(#prefix + 1)
    end
  end

  pcall(view.set_file_by_path, view, rel_file, true, true)

  vim.schedule(function()
    if not view.cur_layout then
      return
    end

    local target = nil
    if side == "R" and view.cur_layout.a then
      target = view.cur_layout.a
    elseif side == "A" and view.cur_layout.b then
      target = view.cur_layout.b
    elseif type(view.cur_layout.get_main_win) == "function" then
      target = view.cur_layout:get_main_win()
    end

    local winid = target and target.id or nil
    if set_cursor(winid, item.lnum, item.col) and type(view.cur_layout.sync_scroll) == "function" then
      pcall(view.cur_layout.sync_scroll, view.cur_layout)
    end
  end)

  return true
end

local function is_diffsearch_list(qf)
  if qf.context and qf.context.source == "critiq-diff-search" then
    return true
  end
  if type(qf.title) == "string" and qf.title:match("^DiffSearch") then
    return true
  end
  return false
end

local function open_item(qf, item)
  local side = infer_side(item)
  if is_diffsearch_list(qf) then
    if open_in_diffview(item, side) then
      return
    end
  end

  vim.cmd("cc")
end

function M.move(offset, opts)
  opts = opts or {}
  local qf = vim.fn.getqflist({ id = 0, idx = 0, title = 1, context = 1, items = 1 })
  local items = qf.items or {}

  if #items == 0 then
    notify("DiffSearch: quickfix list is empty", vim.log.levels.INFO, opts.notify)
    return
  end
  if not is_diffsearch_list(qf) then
    notify("DiffSearch: current quickfix list is not a DiffSearch result list", vim.log.levels.WARN, opts.notify)
    return
  end

  local idx = qf.idx or 1
  local next_idx = idx + offset
  if next_idx < 1 then
    next_idx = 1
  elseif next_idx > #items then
    next_idx = #items
  end

  local item = items[next_idx]
  if not item then
    notify("DiffSearch: no item at target position", vim.log.levels.WARN, opts.notify)
    return
  end

  set_qf_index(qf.id, items, next_idx, qf.title)
  open_item(qf, item)
end

function M.open_current(opts)
  opts = opts or {}
  local qf = vim.fn.getqflist({ id = 0, idx = 0, title = 1, context = 1, items = 1 })
  local items = qf.items or {}

  if #items == 0 then
    notify("DiffSearch: quickfix list is empty", vim.log.levels.INFO, opts.notify)
    return
  end

  local idx = qf.idx or 1
  local item = items[idx]
  if not item then
    notify("DiffSearch: no item at current quickfix index", vim.log.levels.WARN, opts.notify)
    return
  end

  open_item(qf, item)
end

function M.open_from_qf_cursor(opts)
  opts = opts or {}
  local qf = vim.fn.getqflist({ id = 0, idx = 0, title = 1, context = 1, items = 1 })
  local items = qf.items or {}

  if #items == 0 then
    notify("DiffSearch: quickfix list is empty", vim.log.levels.INFO, opts.notify)
    return
  end

  local row = vim.api.nvim_win_get_cursor(0)[1]
  if row < 1 or row > #items then
    notify("DiffSearch: no item at quickfix cursor", vim.log.levels.WARN, opts.notify)
    return
  end

  set_qf_index(qf.id, items, row, qf.title)
  open_item(qf, items[row])
end

return M
