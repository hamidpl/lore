#!/bin/sh
# PostToolUse hook (matcher: Write|Edit)
# Enforces the BLOCKING reader-facing-output rule from CLAUDE.md Rule 5 / Section 6:
#   published docs/ pages are written for product readers and must never reference
#   the authoring tooling — no `.claude/` paths, no `CLAUDE.md` citation, no `lore:*`
#   skill/subagent namespace. (Bare "Claude"/"Anthropic"/"Playwright" are left to the
#   validator as warnings — a real product may legitimately mention them.)
# Exit 2 = block: stderr is fed back to the model so it can self-correct.
#
# Scope: only Markdown/MDX under the project's docs/ (resolved relative to the
# project root). Intentional example/placeholder trees (.claude/, templates/,
# _templates/) are carved out. The scoping rationale lives with the code that
# implements it, in lib/common.sh.

input=$(cat)

_lib="$(dirname "$0")/lib/common.sh"
[ -r "$_lib" ] || { echo "lore hooks: missing $_lib — reader-facing-output rule NOT enforced." >&2; exit 0; }
# shellcheck source=lib/common.sh
. "$_lib"

file_path=$(json_field 'tool_input file_path')
cwd=$(json_field 'cwd')

if [ -z "$file_path" ]; then
  if [ -z "$_json_tool" ] && [ -n "$input" ]; then
    echo "lore hooks: jq/python3 not found and payload could not be parsed — reader-facing-output rule NOT enforced for this write." >&2
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

# Detect unambiguous tooling references. `lore:` requires a non-alphanumeric
# boundary before it so prose like "folklore:" does not trip the rule.
hits=$(grep -nE '(\.claude/|CLAUDE\.md|(^|[^[:alnum:]])lore:)' -- "$file_path" 2>/dev/null)

if [ -n "$hits" ]; then
  echo "BLOCKED: $rel references the authoring tooling in reader-facing docs (CLAUDE.md Rule 5):" >&2
  printf '%s\n' "$hits" | sed 's/^/  /' >&2
  echo "Remove every .claude/ path, CLAUDE.md citation, and lore:* skill/subagent name. State facts directly; do not cite config sections or internal artifacts." >&2
  exit 2
fi

exit 0
