#!/bin/sh
# PostToolUse hook (matcher: Write|Edit)
# Enforces the BLOCKING image rules from CLAUDE.md Section 6 / Rule 1:
#   - Markdown image references in docs/ must use /img/ , never /static/img/
#   - Image files must never be written inside docs/ (they belong in static/img/)
# Exit 2 = block: stderr is fed back to the model so it can self-correct.
# Scope: only product content under docs/ . Skill/template files (.claude/**, _templates/**)
# are NOT checked here because they intentionally contain negative "do not do this" examples.

input=$(cat)

# Extract the written file path from the hook JSON payload.
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

[ -z "$file_path" ] && exit 0

# Normalize: we only care about files under a docs/ directory.
case "$file_path" in
  */docs/*) : ;;       # in scope
  docs/*)   : ;;       # in scope (relative)
  *) exit 0 ;;         # out of scope (e.g. .claude/, _templates/, static/)
esac

# Rule A: image binaries must not live under docs/
case "$file_path" in
  *.png|*.jpg|*.jpeg|*.gif|*.webp|*.svg)
    echo "BLOCKED: image file written under docs/ ($file_path)." >&2
    echo "Images must be stored in static/img/{section}/ and referenced as /img/{section}/ (CLAUDE.md Section 6 / Rule 1)." >&2
    exit 2
    ;;
esac

# Rule B: markdown files must not reference images via /static/img/
case "$file_path" in
  *.md)
    if [ -f "$file_path" ] && grep -q '](/static/img/' "$file_path"; then
      echo "BLOCKED: markdown in $file_path references images via /static/img/." >&2
      echo "Use /img/{section}/ instead (physical storage stays static/img/). See CLAUDE.md Section 6 / Rule 1." >&2
      exit 2
    fi
    ;;
esac

exit 0
