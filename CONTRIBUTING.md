# Contributing

Thanks for contributing to `critiq-diff-search.nvim`.

## Development setup

1. Clone the repository
2. Ensure `git` and `nvim` are installed
3. Load the plugin locally in Neovim via `dir = "/path/to/critiq-diff-search.nvim"`

## Smoke tests

Run the local smoke suite:

```bash
./scripts/run-smoke-tests.sh
```

This script creates a temporary git fixture and validates:

- fallback mode (`HEAD` vs working tree)
- compare mode (`HEAD...alex/deeplinks`)
- added and removed side matching

## Manual test fixture

Create a manual fixture repository:

```bash
./scripts/create-fixture-repo.sh /tmp/critiq-diff-search-fixture
```

Then open it and try:

```vim
:DiffviewOpen HEAD...alex/deeplinks
:DiffSearchWord
```
