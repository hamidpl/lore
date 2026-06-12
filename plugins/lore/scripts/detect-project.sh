#!/bin/sh
# detect-project.sh — report the state of the target directory so the
# /lore:init command can branch. Read-only.
#
# Usage: detect-project.sh [target-dir]   (defaults to current directory)
# Echoes exactly one of:
#   empty           — no files (ignoring dotfiles like .git, .DS_Store)
#   docs-only       — a Lore docs project (has .claude/lore.json marker, or a
#                     legacy docs/ + .claude/CLAUDE.md) but NO docusaurus.config.*
#   has-docusaurus  — has docusaurus.config.ts/js (a Docusaurus site already)
#   non-empty       — has other files but none of the markers above (a bare
#                     .claude/ with no Lore marker counts as non-empty, NOT as a
#                     Lore project)

target="${1:-.}"
cd "$target" 2>/dev/null || { echo "error: cannot cd to $target" >&2; exit 1; }

if [ -f docusaurus.config.ts ] || [ -f docusaurus.config.js ]; then
  echo "has-docusaurus"
  exit 0
fi

# Positive marker written by /lore:init. Authoritative signal of a Lore project.
if [ -f .claude/lore.json ]; then
  echo "docs-only"
  exit 0
fi

# Legacy Lore projects (created before the marker existed): require BOTH a docs/
# tree and a project CLAUDE.md, so an unrelated repo that merely has a .claude/
# settings dir is not misclassified as a Lore docs project.
if [ -d docs ] && [ -f .claude/CLAUDE.md ]; then
  echo "docs-only"
  exit 0
fi

# Count visible entries (exclude . .. and common noise dotfiles).
count=$(find . -maxdepth 1 -mindepth 1 \
  ! -name '.git' ! -name '.DS_Store' ! -name '.gitkeep' 2>/dev/null | wc -l | tr -d ' ')
if [ "$count" = "0" ]; then
  echo "empty"
else
  echo "non-empty"
fi
