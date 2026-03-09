local M = {}

local function system(args, cwd)
  if vim.system then
    local result = vim.system(args, { cwd = cwd, text = true }):wait()
    return {
      code = result.code,
      stdout = result.stdout or "",
      stderr = result.stderr or "",
    }
  end

  local escaped = vim.tbl_map(vim.fn.shellescape, args)
  local previous_cwd = vim.fn.getcwd()
  if cwd and cwd ~= "" then
    vim.cmd("silent cd " .. vim.fn.fnameescape(cwd))
  end

  local output = vim.fn.system(table.concat(escaped, " "))
  local code = vim.v.shell_error

  if cwd and cwd ~= "" then
    vim.cmd("silent cd " .. vim.fn.fnameescape(previous_cwd))
  end

  return {
    code = code,
    stdout = output or "",
    stderr = code == 0 and "" or (output or ""),
  }
end

local function split_lines(text)
  if text == "" then
    return {}
  end
  return vim.split(text, "\n", { trimempty = true })
end

local function normalize_file_list(files)
  if not files or #files == 0 then
    return {}
  end
  local dedup = {}
  local out = {}
  for _, file in ipairs(files) do
    if file and file ~= "" and not dedup[file] then
      dedup[file] = true
      table.insert(out, file)
    end
  end
  return out
end

function M.repo_root(start_path)
  local response = system({ "git", "rev-parse", "--show-toplevel" }, start_path)
  if response.code ~= 0 then
    return nil, response.stderr
  end
  return vim.trim(response.stdout)
end

function M.diff_patch(repo_root, range, files)
  local args = { "git", "diff", "--no-color", "--no-ext-diff", "--unified=0" }
  if range and range ~= "" then
    table.insert(args, range)
  else
    table.insert(args, "HEAD")
  end
  table.insert(args, "--")
  for _, file in ipairs(normalize_file_list(files)) do
    table.insert(args, file)
  end

  local response = system(args, repo_root)
  if response.code ~= 0 then
    return nil, response.stderr
  end
  return response.stdout
end

function M.changed_files(repo_root, range, files_hint)
  if files_hint and #files_hint > 0 then
    return normalize_file_list(files_hint), nil
  end

  local args = { "git", "diff", "--name-only", "-z" }
  if range and range ~= "" then
    table.insert(args, range)
  else
    table.insert(args, "HEAD")
  end

  local response = system(args, repo_root)
  if response.code ~= 0 then
    return nil, response.stderr
  end

  local files = {}
  for file in response.stdout:gmatch("([^%z]+)") do
    table.insert(files, file)
  end
  return normalize_file_list(files), nil
end

function M.grep_working(repo_root, query, files, opts)
  opts = opts or {}
  local args = { "git", "grep", "-n", "--full-name" }
  if opts.literal then
    table.insert(args, "-F")
  end
  table.insert(args, "-e")
  table.insert(args, query)
  table.insert(args, "--")
  for _, file in ipairs(normalize_file_list(files)) do
    table.insert(args, file)
  end

  local response = system(args, repo_root)
  if response.code == 1 then
    return {}, nil
  end
  if response.code ~= 0 then
    return nil, response.stderr
  end
  return split_lines(response.stdout), nil
end

function M.grep_rev(repo_root, query, rev, files, opts)
  opts = opts or {}
  local args = { "git", "grep", "-n", "--full-name" }
  if opts.literal then
    table.insert(args, "-F")
  end
  table.insert(args, "-e")
  table.insert(args, query)
  table.insert(args, rev)
  table.insert(args, "--")
  for _, file in ipairs(normalize_file_list(files)) do
    table.insert(args, file)
  end

  local response = system(args, repo_root)
  if response.code == 1 then
    return {}, nil
  end
  if response.code ~= 0 then
    return nil, response.stderr
  end
  return split_lines(response.stdout), nil
end

return M
