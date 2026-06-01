#!/bin/sh
# PostToolUse hook (matcher: Write|Edit)
# Enforces the BLOCKING frontmatter requirement from CLAUDE.md Section 2 / Section 6:
#   every docs/ page must have a YAML frontmatter block with the required keys
#   (sidebar_position, title, description, tags).
# Exit 2 = block: stderr is fed back to the model so it can self-correct.
# Scope: only Markdown/MDX under docs/ . Skill/template files (.claude/**, templates/**,
# _templates/**) are out of scope (they hold intentional examples/placeholders).

input=$(cat)

file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$file_path" ] && exit 0

# In scope: only files under a docs/ directory.
case "$file_path" in
  */docs/*) : ;;
  docs/*)   : ;;
  *) exit 0 ;;
esac

# Only Markdown / MDX content pages.
case "$file_path" in
  *.md|*.mdx) : ;;
  *) exit 0 ;;
esac

# File must exist on disk to inspect (Write/Edit have completed by PostToolUse).
[ -f "$file_path" ] || exit 0

# 1) Must start with a YAML frontmatter fence (--- on the first line).
first_line=$(head -n 1 "$file_path")
if [ "$first_line" != "---" ]; then
  echo "BLOCKED: $file_path is missing a YAML frontmatter block." >&2
  echo "Add frontmatter at the top with: sidebar_position, title, description, tags (CLAUDE.md Section 2 / Section 6)." >&2
  exit 2
fi

# 2) Extract the frontmatter block (between the first two --- fences).
fm=$(awk 'NR==1 && $0=="---"{f=1; next} f && $0=="---"{exit} f{print}' "$file_path")

missing=""
for key in sidebar_position title description tags; do
  printf '%s\n' "$fm" | grep -qE "^[[:space:]]*$key[[:space:]]*:" || missing="$missing $key"
done

if [ -n "$missing" ]; then
  echo "BLOCKED: $file_path frontmatter is missing required key(s):$missing" >&2
  echo "Every docs/ page needs sidebar_position, title, description, tags (CLAUDE.md Section 2 / Section 6)." >&2
  exit 2
fi

exit 0
