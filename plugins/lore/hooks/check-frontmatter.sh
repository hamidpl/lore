#!/bin/sh
# PostToolUse hook (matcher: Write|Edit)
# Enforces the BLOCKING frontmatter requirement from CLAUDE.md Section 2 / Section 6:
#   every docs/ page must begin with a YAML frontmatter block carrying the required
#   keys (sidebar_position, title, description, tags).
# Exit 2 = block: stderr is fed back to the model so it can self-correct.
#
# Scope: only Markdown/MDX under the project's docs/ (resolved relative to the
# project root). Intentional example/placeholder trees (.claude/, templates/,
# _templates/) are carved out. See check-image-path.sh for the scoping rationale.

input=$(cat)

# --- pick a JSON extraction backend once (jq → python3 → sed last resort) ---
_json_tool=""
if command -v jq >/dev/null 2>&1; then
  _json_tool="jq"
elif command -v python3 >/dev/null 2>&1; then
  _json_tool="python3"
fi

json_field() {
  case "$_json_tool" in
    jq)
      printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null
      ;;
    python3)
      printf '%s' "$input" | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    sys.exit(0)
cur=d
for k in sys.argv[1:]:
    cur = cur.get(k) if isinstance(cur, dict) else None
    if cur is None:
        break
print(cur if isinstance(cur, str) else "")
' $2
      ;;
    *)
      printf '%s' "$input" | sed -n "s/.*\"$3\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" | head -n 1
      ;;
  esac
}

file_path=$(json_field '.tool_input.file_path' 'tool_input file_path' 'file_path')
cwd=$(json_field '.cwd' 'cwd' 'cwd')

if [ -z "$file_path" ]; then
  if [ -z "$_json_tool" ] && [ -n "$input" ]; then
    echo "lore hooks: jq/python3 not found and payload could not be parsed — frontmatter rule NOT enforced for this write." >&2
  fi
  exit 0
fi

# --- compute the project-relative path ---
root="${CLAUDE_PROJECT_DIR:-$cwd}"
root="${root%/}"
case "$file_path" in
  /*) [ -n "$root" ] && rel="${file_path#"$root"/}" || rel="$file_path" ;;
  *)  rel="$file_path" ;;
esac

# --- carve-out ---
case "$rel" in
  .claude/*|templates/*|_templates/*) exit 0 ;;
esac

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
