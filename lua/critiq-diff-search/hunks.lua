local M = {}

local function strip_prefix(path)
  if not path then
    return nil
  end
  if path:sub(1, 2) == "a/" or path:sub(1, 2) == "b/" then
    return path:sub(3)
  end
  return path
end

local function parse_diff_git_header(line)
  local a, b = line:match("^diff %-%-git a/(.+) b/(.+)$")
  if not a or not b then
    return nil, nil
  end
  return a, b
end

local function parse_hunk_header(line)
  local old_start, old_count, new_start, new_count =
    line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
  if not old_start then
    return nil
  end
  old_start = tonumber(old_start)
  new_start = tonumber(new_start)
  old_count = tonumber(old_count) or 1
  new_count = tonumber(new_count) or 1
  return old_start, old_count, new_start, new_count
end

function M.parse(patch)
  local entries = {}
  local by_new = {}
  local by_old = {}

  local current = nil
  local old_line = nil
  local new_line = nil

  for raw in (patch .. "\n"):gmatch("(.-)\n") do
    if raw:match("^diff %-%-git ") then
      local old_path, new_path = parse_diff_git_header(raw)
      current = {
        old_path = old_path,
        new_path = new_path,
        added = {},
        deleted = {},
      }
      table.insert(entries, current)
      if new_path and new_path ~= "/dev/null" then
        by_new[new_path] = current
      end
      if old_path and old_path ~= "/dev/null" then
        by_old[old_path] = current
      end
      old_line = nil
      new_line = nil
    elseif current and raw:match("^%-%-%- ") then
      local old_path = raw:match("^%-%-%- (.+)$")
      old_path = strip_prefix(old_path)
      if old_path ~= "/dev/null" then
        current.old_path = old_path
        by_old[old_path] = current
      end
    elseif current and raw:match("^%+%+%+ ") then
      local new_path = raw:match("^%+%+%+ (.+)$")
      new_path = strip_prefix(new_path)
      if new_path ~= "/dev/null" then
        current.new_path = new_path
        by_new[new_path] = current
      end
    elseif current and raw:match("^@@ ") then
      local o_start, _, n_start = parse_hunk_header(raw)
      old_line = o_start
      new_line = n_start
    elseif current and old_line and new_line then
      local prefix = raw:sub(1, 1)
      if prefix == "+" and not raw:match("^%+%+%+") then
        current.added[new_line] = true
        new_line = new_line + 1
      elseif prefix == "-" and not raw:match("^%-%-%-") then
        current.deleted[old_line] = true
        old_line = old_line + 1
      elseif prefix == " " then
        old_line = old_line + 1
        new_line = new_line + 1
      elseif prefix == "\\" then
      else
        old_line = nil
        new_line = nil
      end
    end
  end

  return {
    entries = entries,
    by_new = by_new,
    by_old = by_old,
  }
end

return M
