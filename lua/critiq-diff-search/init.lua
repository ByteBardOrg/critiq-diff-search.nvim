local search = require("critiq-diff-search.search")
local quickfix = require("critiq-diff-search.presenters.quickfix")
local context = require("critiq-diff-search.context")
local navigation = require("critiq-diff-search.navigation")
local git = require("critiq-diff-search.git")

local M = {}

local config = {
  max_results = 500,
  open_quickfix = true,
  notify = true,
  critiq_command = "critiq",
}

local function notify(message, level)
  if config.notify then
    vim.notify(message, level or vim.log.levels.INFO)
  end
end

local function run_search(opts)
  local results, err = search.run(opts, config)
  if err then
    notify("DiffSearch: " .. err, vim.log.levels.WARN)
    return
  end

  quickfix.present(results, {
    title = string.format("DiffSearch: %s", opts.query),
    open_quickfix = config.open_quickfix,
    notify = config.notify,
  })
end

local function get_selection_text(range)
  range = range or {}
  local vmode = vim.fn.visualmode()
  if vmode == "\22" then
    return nil, "block selections are not supported"
  end

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_lnum = range.line1 or start_pos[2]
  local start_col = start_pos[3]
  local end_lnum = range.line2 or end_pos[2]
  local end_col = end_pos[3]

  if start_lnum == 0 or end_lnum == 0 then
    return nil, "no visual selection found"
  end

  if start_lnum > end_lnum or (start_lnum == end_lnum and start_col > end_col) then
    start_lnum, end_lnum = end_lnum, start_lnum
    start_col, end_col = end_col, start_col
  end

  local lines = vim.api.nvim_buf_get_lines(0, start_lnum - 1, end_lnum, false)
  if #lines == 0 then
    return nil, "selection is empty"
  end

  if vmode ~= "V" then
    local first_len = #lines[1]
    local last_len = #lines[#lines]
    local safe_start = math.max(1, math.min(start_col, first_len > 0 and first_len or 1))
    local safe_end = math.max(1, math.min(end_col, last_len > 0 and last_len or 1))
    lines[1] = lines[1]:sub(safe_start)
    lines[#lines] = lines[#lines]:sub(1, safe_end)
  end

  local text = table.concat(lines, " ")
  text = text:gsub("%s+", " ")
  text = vim.trim(text)
  if text == "" then
    return nil, "selection is empty"
  end

  return text, nil
end

function M.setup(opts)
  opts = opts or {}
  config = vim.tbl_deep_extend("force", config, opts)
end

function M.search(opts)
  run_search(opts or {})
end

function M.search_command(raw_query, opts)
  opts = opts or {}
  local query = vim.trim(raw_query or "")
  if query ~= "" then
    run_search({ query = query })
    return
  end

  if opts.use_selection then
    M.search_selection({ line1 = opts.line1, line2 = opts.line2 })
    return
  end

  notify("DiffSearch: provide a query or run from a visual selection", vim.log.levels.WARN)
end

function M.search_word()
  local word = vim.fn.expand("<cword>")
  if not word or word == "" then
    notify("DiffSearchWord: no word under cursor", vim.log.levels.WARN)
    return
  end
  run_search({ query = word })
end

function M.search_buffer(raw_query)
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    notify("DiffSearchBuffer: current buffer has no file", vim.log.levels.WARN)
    return
  end
  run_search({ query = raw_query, scope_file = file })
end

function M.search_selection(opts)
  local text, err = get_selection_text(opts)
  if not text then
    notify("DiffSearch: " .. (err or "invalid selection"), vim.log.levels.WARN)
    return
  end
  run_search({ query = text, literal = true })
end

function M.debug_context()
  local ctx, err = context.resolve({
    scope_file = vim.api.nvim_buf_get_name(0),
  })
  if not ctx then
    notify("DiffSearch debug: " .. (err or "failed to resolve context"), vim.log.levels.WARN)
    return
  end

  local message = string.format(
    "mode=%s source=%s range=%s base=%s compare=%s files=%d",
    tostring(ctx.mode),
    tostring(ctx.source),
    tostring(ctx.range),
    tostring(ctx.base_ref),
    tostring(ctx.compare_ref),
    ctx.files_hint and #ctx.files_hint or 0
  )
  notify("DiffSearch debug: " .. message)
end

function M.next_result()
  navigation.move(1, { notify = config.notify })
end

function M.prev_result()
  navigation.move(-1, { notify = config.notify })
end

function M.open_current_result()
  navigation.open_current({ notify = config.notify })
end

function M.open_qf_cursor_result()
  navigation.open_from_qf_cursor({ notify = config.notify })
end

function M.open_critiq_repo()
  local repo_root, err = git.repo_root(vim.loop.cwd())
  if not repo_root then
    notify("CritiqOpenRepo: " .. (err or "not inside a git repository"), vim.log.levels.WARN)
    return
  end

  local command = config.critiq_command or "critiq"
  local jobid = vim.fn.jobstart({ command, repo_root }, { detach = true })
  if jobid <= 0 then
    notify(
      "CritiqOpenRepo: failed to launch '" .. command .. "'. Ensure Critiq CLI is installed and on PATH.",
      vim.log.levels.WARN
    )
    return
  end

  notify("CritiqOpenRepo: opening Critiq for current repository")
end

return M
