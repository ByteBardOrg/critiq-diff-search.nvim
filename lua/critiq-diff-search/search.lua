local context = require("critiq-diff-search.context")
local git = require("critiq-diff-search.git")
local hunks = require("critiq-diff-search.hunks")

local M = {}

local function add_file(out, seen, file)
  if file and file ~= "" and not seen[file] then
    seen[file] = true
    table.insert(out, file)
  end
end

local function derive_file_lists(parsed, fallback_files)
  local working_files = {}
  local base_files = {}
  local seen_working = {}
  local seen_base = {}

  if parsed and parsed.entries then
    for _, entry in ipairs(parsed.entries) do
      add_file(working_files, seen_working, entry.new_path)
      add_file(base_files, seen_base, entry.old_path)
    end
  end

  if #working_files == 0 and fallback_files then
    for _, file in ipairs(fallback_files) do
      add_file(working_files, seen_working, file)
    end
  end

  if #base_files == 0 and fallback_files then
    for _, file in ipairs(fallback_files) do
      add_file(base_files, seen_base, file)
    end
  end

  return working_files, base_files
end

local function parse_working_grep_line(line)
  local file, lnum, text = line:match("^([^:]+):(%d+):(.*)$")
  if not file then
    return nil
  end
  return {
    file = file,
    line = tonumber(lnum),
    text = text,
    col = 1,
  }
end

local function parse_rev_grep_line(line, rev)
  local prefix = rev .. ":"
  if line:sub(1, #prefix) == prefix then
    line = line:sub(#prefix + 1)
  end
  return parse_working_grep_line(line)
end

local function search_compare_side(ctx, query, files, opts)
  opts = opts or {}
  if ctx.mode == "compare" and ctx.compare_ref and ctx.compare_ref ~= "" and ctx.compare_ref ~= "WORKTREE" then
    local lines, err = git.grep_rev(ctx.repo_root, query, ctx.compare_ref, files, { literal = opts.literal })
    if not lines then
      return nil, err
    end

    local parsed = {}
    for _, line in ipairs(lines) do
      local match = parse_rev_grep_line(line, ctx.compare_ref)
      if match then
        table.insert(parsed, match)
      end
    end
    return parsed, nil
  end

  local lines, err = git.grep_working(ctx.repo_root, query, files, { literal = opts.literal })
  if not lines then
    return nil, err
  end

  local parsed = {}
  for _, line in ipairs(lines) do
    local match = parse_working_grep_line(line)
    if match then
      table.insert(parsed, match)
    end
  end
  return parsed, nil
end

local function dedupe(results)
  local out = {}
  local seen = {}

  for _, result in ipairs(results) do
    local key = table.concat({ result.side, result.file, result.line, result.text }, "|")
    if not seen[key] then
      seen[key] = true
      table.insert(out, result)
    end
  end

  return out
end

local function sort_results(results)
  table.sort(results, function(a, b)
    if a.file == b.file then
      if a.line == b.line then
        return a.side < b.side
      end
      return a.line < b.line
    end
    return a.file < b.file
  end)
  return results
end

function M.run(opts, config)
  opts = opts or {}
  config = config or {}

  local query = vim.trim(opts.query or "")
  if query == "" then
    return nil, "DiffSearch query cannot be empty"
  end

  local ctx, ctx_err = context.resolve({
    scope_file = opts.scope_file,
    files = opts.files,
  })
  if not ctx then
    return nil, ctx_err
  end

  local files, files_err = git.changed_files(ctx.repo_root, ctx.range, ctx.files_hint)
  if not files then
    return nil, files_err
  end
  if #files == 0 then
    return {}, nil
  end

  local patch, patch_err = git.diff_patch(ctx.repo_root, ctx.range, files)
  if not patch then
    return nil, patch_err
  end

  local parsed = hunks.parse(patch)
  local working_files, base_files = derive_file_lists(parsed, files)

  local compare_matches, working_err = search_compare_side(ctx, query, working_files, { literal = opts.literal })
  if not compare_matches then
    return nil, working_err
  end

  local results = {}
  for _, match in ipairs(compare_matches) do
    local entry = parsed.by_new[match.file]
    if entry and entry.added[match.line] then
      match.repo_root = ctx.repo_root
      match.side = "A"
      table.insert(results, match)
    end
  end

  local search_base = ctx.base_ref and ctx.base_ref ~= "" and ctx.base_ref ~= "WORKTREE"
  if search_base then
    local base_lines, base_err = git.grep_rev(ctx.repo_root, query, ctx.base_ref, base_files, { literal = opts.literal })
    if not base_lines then
      return nil, base_err
    end

    for _, line in ipairs(base_lines) do
      local match = parse_rev_grep_line(line, ctx.base_ref)
      if match then
        local entry = parsed.by_old[match.file] or parsed.by_new[match.file]
        if entry and entry.deleted[match.line] then
          match.repo_root = ctx.repo_root
          match.side = "R"
          table.insert(results, match)
        end
      end
    end
  end

  results = sort_results(dedupe(results))

  local max_results = config.max_results or 500
  if #results > max_results then
    local sliced = {}
    for i = 1, max_results do
      sliced[i] = results[i]
    end
    return sliced, nil
  end

  return results, nil
end

return M
