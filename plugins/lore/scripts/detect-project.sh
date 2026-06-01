#!/bin/sh
# detect-project.sh — report the state of the target directory so the
# /lore:init command can branch. Read-only.
#
# Usage: detect-project.sh [target-dir]   (defaults to current directory)
# Echoes exactly one of:
#   empty           — no files (ignoring dotfiles like .git, .DS_Store)
#   docs-only       — has docs/ or .claude/ but NO docusaurus.config.ts
#   has-docusaurus  — has docusaurus.config.ts (a Docusaurus site already)
#   non-empty       — has other files but none of the markers above

target="${1:-.}"
cd "$target" 2>/dev/null || { echo "error: cannot cd to $target" >&2; exit 1; }

if [ -f docusaurus.config.ts ] || [ -f docusaurus.config.js ]; then
  echo "has-docusaurus"
  exit 0
fi

if [ -d docs ] || [ -d .claude ]; then
  echo "docs-only"
  exit 0
fi

# Count visible entries (exclude . .. and common noise dotfiles).
count=$(ls -A 2>/dev/null | grep -vE '^(\.git|\.DS_Store|\.gitkeep)$' | wc -l | tr -d ' ')
if [ "$count" = "0" ]; then
  echo "empty"
else
  echo "non-empty"
fi
