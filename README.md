# critiq-diff-search.nvim

critiq-diff-search.nvim brings [Critiq](https://getcritiq.dev)'s change-aware search model to Neovim.

This plugin focuses on one thing: finding matches that matter to the current diff.

- Search is scoped to diff context, not generic full-repo text search
- Results include both added/changed-side (`[A]`) and removed/base-side (`[R]`) matches
- Works best in `diffview.nvim` compare sessions and also supports repo-diff fallback
- Output is quickfix-first so it composes with normal Neovim workflows

## Why this exists

Critiq desktop includes change-aware search that focuses on what actually changed.
This plugin brings that same idea into Neovim so you can keep moving inside editor-first review flows.

## Requirements

- Neovim 0.9+
- Git available in `$PATH`
- `diffview.nvim` recommended for best context resolution

## Install

Lazy.nvim example:

```lua
{
  "ByteBardOrg/critiq-diff-search.nvim",
  dependencies = { "sindrets/diffview.nvim" },
  config = function()
    require("critiq-diff-search").setup({
      max_results = 500,
      open_quickfix = true,
    })
  end,
}
```

LazyVim example (`~/.config/nvim/lua/plugins/critiq-diff-search.lua`):

```lua
return {
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory", "DiffviewRefresh" },
  },
  {
    "ByteBardOrg/critiq-diff-search.nvim",
    dependencies = { "sindrets/diffview.nvim" },
    cmd = {
      "DiffSearch",
      "DiffSearchWord",
      "DiffSearchBuffer",
      "DiffSearchNext",
      "DiffSearchPrev",
      "CritiqOpenRepo",
    },
    keys = {
      { "<leader>ds", ":DiffSearch ", desc = "Diff search" },
      { "<leader>ds", ":'<,'>DiffSearch<cr>", mode = "x", desc = "Diff search selection" },
      { "<leader>dw", "<cmd>DiffSearchWord<cr>", desc = "Diff search word" },
      { "<leader>db", ":DiffSearchBuffer ", desc = "Diff search buffer" },
      { "<leader>dn", "<cmd>DiffSearchNext<cr>", desc = "Next diff search result" },
      { "<leader>dp", "<cmd>DiffSearchPrev<cr>", desc = "Previous diff search result" },
    },
    opts = {
      max_results = 500,
      open_quickfix = true,
      notify = true,
    },
    config = function(_, opts)
      require("critiq-diff-search").setup(opts)
    end,
  },
}
```

For local development, you can replace the plugin spec with `dir = "/path/to/critiq-diff-search.nvim"`.

## Commands

- `:DiffSearch {query}`
- `:DiffSearchWord`
- `:DiffSearchBuffer {query}`
- `:DiffSearchNext`
- `:DiffSearchPrev`
- `:CritiqOpenRepo`

Compatibility alias (not required for normal use):

- `:DiffSearchSelection`

## Typical workflow

1. Open a comparison in Diffview (for example `:DiffviewOpen origin/main...HEAD`)
2. Search using one of:
   - `:DiffSearchWord` on a token under cursor
   - visual selection + `:DiffSearch`
   - `:DiffSearch your_query`
3. Move through results with `:DiffSearchNext` / `:DiffSearchPrev`
   - or press `<CR>` on an item in the quickfix window
4. Read labels:
   - `[A]` added/changed side
   - `[R]` removed/base side

## What gets searched

- Files are scoped to the active diff context
- Match candidates are filtered to changed lines only
- Removed-line matches are included alongside added-line matches

If no diff context is available, the plugin reports that clearly instead of falling back to generic grep behavior.

## Optional Critiq integration

This plugin works fully on its own. If you also use [Critiq](https://getcritiq.dev), you can run:

- `:CritiqOpenRepo` to open the current repository in Critiq

Planned next step:

- `:CritiqOpen` for deeper handoff from active diff context

## Configuration

```lua
require("critiq-diff-search").setup({
  max_results = 500,
  open_quickfix = true,
  notify = true,
  critiq_command = "critiq",
})
```

Defaults:

- `max_results = 500`
- `open_quickfix = true`
- `notify = true`
- `critiq_command = "critiq"`

## Notes

- In fallback mode, base ref defaults to `HEAD`
- Empty visual selections are ignored and do not execute a search

## Development

- Run smoke tests: `./scripts/run-smoke-tests.sh`
- Create a local fixture repo: `./scripts/create-fixture-repo.sh /tmp/critiq-diff-search-fixture`
- See contribution workflow in `CONTRIBUTING.md`
- Release notes live in `CHANGELOG.md`
