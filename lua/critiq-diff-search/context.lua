local git = require("critiq-diff-search.git")

local M = {}

local function parse_compare_range(raw)
  if type(raw) ~= "string" or raw == "" then
    return nil
  end

  local base, compare = raw:match("^(.+)%.%.%.(.+)$")
  if base and compare then
    return {
      mode = "compare",
      range = raw,
      base_ref = base,
      compare_ref = compare,
    }
  end

  base, compare = raw:match("^(.+)%.%.(.+)$")
  if base and compare then
    return {
      mode = "compare",
      range = raw,
      base_ref = base,
      compare_ref = compare,
    }
  end

  return nil
end

local function normalize_path(path, repo_root)
  if not path or path == "" then
    return nil
  end
  path = path:gsub("\\", "/")
  repo_root = repo_root:gsub("\\", "/")
  local prefix = repo_root .. "/"
  if path:sub(1, #prefix) == prefix then
    return path:sub(#prefix + 1)
  end
  return path
end

local function extract_diffview_range()
  local ok, lib = pcall(require, "diffview.lib")
  if not ok or not lib or type(lib.get_current_view) ~= "function" then
    return nil
  end

  local ok_view, view = pcall(lib.get_current_view)
  if not ok_view or not view then
    return nil
  end

  local candidates = {
    view.rev_arg,
    view.range,
    view.rev,
    view.args and view.args.rev_arg,
    view.adapter and view.adapter.ctx and view.adapter.ctx.rev_arg,
  }

  local state = {
    range = nil,
    mode = "working",
    base_ref = "HEAD",
    compare_ref = "WORKTREE",
    files_hint = {},
  }

  for _, candidate in ipairs(candidates) do
    local parsed = parse_compare_range(candidate)
    if parsed then
      state.range = parsed.range
      state.mode = parsed.mode
      state.base_ref = parsed.base_ref
      state.compare_ref = parsed.compare_ref
      break
    end
  end

  if state.range == nil and type(view.rev_arg) == "string" and view.rev_arg ~= "" then
    state.range = view.rev_arg
    state.mode = "compare"
    state.base_ref = view.rev_arg
    state.compare_ref = "WORKTREE"
  end

  if view.files and type(view.files.iter) == "function" then
    local seen = {}
    for _, entry in view.files:iter() do
      if entry and type(entry.path) == "string" and entry.path ~= "" and not seen[entry.path] then
        seen[entry.path] = true
        table.insert(state.files_hint, entry.path)
      end
    end
  end

  return state
end

function M.resolve(opts)
  opts = opts or {}

  local cwd = vim.loop.cwd()
  local repo_root, err = git.repo_root(cwd)
  if not repo_root then
    return nil, err or "Not inside a git repository"
  end

  local diffview = extract_diffview_range()
  local context = diffview or {
    mode = "working",
    range = nil,
    base_ref = "HEAD",
    compare_ref = "WORKTREE",
  }

  if opts.scope_file and opts.scope_file ~= "" then
    context.files_hint = { normalize_path(opts.scope_file, repo_root) }
  elseif opts.files and #opts.files > 0 then
    local list = {}
    for _, file in ipairs(opts.files) do
      local normalized = normalize_path(file, repo_root)
      if normalized and normalized ~= "" then
        table.insert(list, normalized)
      end
    end
    context.files_hint = list
  elseif diffview and diffview.files_hint and #diffview.files_hint > 0 then
    local list = {}
    for _, file in ipairs(diffview.files_hint) do
      local normalized = normalize_path(file, repo_root)
      if normalized and normalized ~= "" then
        table.insert(list, normalized)
      end
    end
    context.files_hint = list
  end

  context.repo_root = repo_root
  context.source = diffview and "diffview" or "fallback"
  return context
end

return M
