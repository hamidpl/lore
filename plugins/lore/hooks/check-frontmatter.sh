#!/bin/sh
# PostToolUse hook (matcher: Write|Edit)
# Enforces the BLOCKING frontmatter requirement from CLAUDE.md Section 2 / Section 6:
#   every docs/ page must begin with a YAML frontmatter block carrying the required
#   keys (sidebar_position, title, description, tags).
# Exit 2 = block: stderr is fed back to the model so it can self-correct.
#
# Scope: only Markdown/MDX under the project's docs/ (resolved relative to the
# project root). Intentional example/placeholder trees (.claude/, templates/,
# _templates/) are carved out. The scoping rationale lives with the code that
# implements it, in lib/common.sh.

input=$(cat)

_lib="$(dirname "$0")/lib/common.sh"
[ -r "$_lib" ] || { echo "lore hooks: missing $_lib — frontmatter rule NOT enforced." >&2; exit 0; }
# shellcheck source=lib/common.sh
. "$_lib"

file_path=$(json_field 'tool_input file_path')
cwd=$(json_field 'cwd')

if [ -z "$file_path" ]; then
  if [ -z "$_json_tool" ] && [ -n "$input" ]; then
    echo "lore hooks: jq/python3 not found and payload could not be parsed — frontmatter rule NOT enforced for this write." >&2
  fi
  exit 0
fi

root=$(lore_root "$cwd")
rel=$(lore_rel "$file_path" "$root")

lore_is_project "$root" || exit 0
lore_carved_out "$rel" && exit 0

# --- in scope only under docs/ ---
case "$rel" in
  docs/*) : ;;
  *) exit 0 ;;
esac

# Only Markdown / MDX content pages.
case "$rel" in
  *.md|*.mdx) : ;;
  *) exit 0 ;;
esac

# File must exist on disk to inspect (Write/Edit have completed by PostToolUse).
[ -f "$file_path" ] || exit 0

# 1) First line must be a frontmatter fence (---), tolerating a UTF-8 BOM and CRLF.
first_line=$(awk 'NR==1{ sub(/^\357\273\277/,""); sub(/\r$/,""); print; exit }' "$file_path")
if [ "$first_line" != "---" ]; then
  echo "BLOCKED: $rel is missing a YAML frontmatter block (the first line must be ---)." >&2
  echo "Add frontmatter at the top with: sidebar_position, title, description, tags (CLAUDE.md Section 2 / Section 6)." >&2
  exit 2
fi

# 2) Extract the frontmatter block; require a closing --- fence.
fm=$(awk '
  NR==1 { sub(/^\357\273\277/,"") }
  { sub(/\r$/,"") }
  NR==1 && $0=="---" { f=1; next }
  f && $0=="---" { closed=1; exit }
  f { print }
  END { if (!closed) exit 3 }
' "$file_path")
if [ "$?" -eq 3 ]; then
  echo "BLOCKED: $rel has an unclosed YAML frontmatter block (missing the closing ---)." >&2
  echo "Close the frontmatter with a --- line before the document body (CLAUDE.md Section 2 / Section 6)." >&2
  exit 2
fi

# 3) Every required key must be present at the top level (column 0).
missing=""
for key in sidebar_position title description tags; do
  printf '%s\n' "$fm" | grep -qE "^${key}[[:space:]]*:" || missing="$missing $key"
done

if [ -n "$missing" ]; then
  echo "BLOCKED: $rel frontmatter is missing required key(s):$missing" >&2
  echo "Every docs/ page needs sidebar_position, title, description, tags (CLAUDE.md Section 2 / Section 6)." >&2
  exit 2
fi

exit 0
