#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
REPO_DIR="$TMP_DIR/fixture"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

"$ROOT_DIR/scripts/create-fixture-repo.sh" "$REPO_DIR" >/dev/null

nvim --headless -u NONE \
  -c "lua vim.opt.rtp:append([[$ROOT_DIR]])" \
  -c "cd $REPO_DIR" \
  -c "luafile $ROOT_DIR/tests/smoke.lua" \
  -c "qa"

echo "Smoke tests passed"
