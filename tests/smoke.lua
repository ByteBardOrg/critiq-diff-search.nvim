local search = require("critiq-diff-search.search")
local context = require("critiq-diff-search.context")

local function assert_true(value, message)
  if not value then
    error(message)
  end
end

local function run_query(query)
  local results, err = search.run({ query = query }, { max_results = 500 })
  assert_true(err == nil, "query failed for '" .. query .. "': " .. tostring(err))
  return results
end

local function has_side(results, side)
  for _, item in ipairs(results) do
    if item.side == side then
      return true
    end
  end
  return false
end

local function with_context_override(ctx, fn)
  local old = context.resolve
  context.resolve = function()
    return ctx
  end
  local ok, result = pcall(fn)
  context.resolve = old
  if not ok then
    error(result)
  end
  return result
end

local function test_fallback_mode()
  local added = run_query("working_added_token")
  assert_true(#added > 0, "expected at least one fallback added match")
  assert_true(has_side(added, "A"), "expected fallback added match with side A")

  local removed = run_query("removed_branch_token")
  assert_true(#removed > 0, "expected at least one fallback removed match")
  assert_true(has_side(removed, "R"), "expected fallback removed match with side R")
end

local function test_compare_mode()
  local repo_root = vim.loop.cwd()
  local compare_ctx = {
    mode = "compare",
    source = "test",
    repo_root = repo_root,
    range = "HEAD...alex/deeplinks",
    base_ref = "HEAD",
    compare_ref = "alex/deeplinks",
  }

  with_context_override(compare_ctx, function()
    local added = run_query("added_branch_token")
    assert_true(has_side(added, "A"), "expected compare added_branch_token side A")

    local removed = run_query("removed_branch_token")
    assert_true(has_side(removed, "R"), "expected compare removed_branch_token side R")

    local new_file = run_query("branch_new_file_token")
    assert_true(has_side(new_file, "A"), "expected compare new file token side A")
  end)
end

local function test_empty_query()
  local results, err = search.run({ query = "" }, {})
  assert_true(results == nil, "expected nil results for empty query")
  assert_true(err ~= nil, "expected error for empty query")
end

local ok, failure = pcall(function()
  test_fallback_mode()
  test_compare_mode()
  test_empty_query()
end)

if not ok then
  vim.api.nvim_err_writeln("Smoke test failed: " .. tostring(failure))
  vim.cmd("cq")
  return
end

print("critiq-diff-search smoke tests passed")
