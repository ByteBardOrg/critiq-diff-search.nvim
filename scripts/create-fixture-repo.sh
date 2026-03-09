#!/usr/bin/env bash

set -euo pipefail

DEST="${1:-}"
if [[ -z "$DEST" ]]; then
  echo "Usage: $0 <destination-directory>" >&2
  exit 1
fi

rm -rf "$DEST"
mkdir -p "$DEST"

git init -q -b main "$DEST"
git -C "$DEST" config user.name "Critiq Diff Search"
git -C "$DEST" config user.email "critiq-diff-search@example.com"

mkdir -p "$DEST/src"

cat >"$DEST/src/notes.txt" <<'EOF'
alpha
removed_branch_token
keep_shared
EOF

git -C "$DEST" add .
git -C "$DEST" commit -m "seed base content" >/dev/null

git -C "$DEST" checkout -q -b alex/deeplinks

cat >"$DEST/src/notes.txt" <<'EOF'
alpha
added_branch_token
keep_shared
EOF

cat >"$DEST/src/new.html" <<'EOF'
<main>
  <h1>branch_new_file_token</h1>
</main>
EOF

git -C "$DEST" add .
git -C "$DEST" commit -m "branch diff content" >/dev/null

git -C "$DEST" checkout -q main

cat >"$DEST/src/notes.txt" <<'EOF'
alpha
working_added_token
keep_shared
EOF

echo "Fixture created at: $DEST"
echo "- Compare target branch: alex/deeplinks"
echo "- Working-tree added token: working_added_token"
echo "- Working-tree removed token: removed_branch_token"
