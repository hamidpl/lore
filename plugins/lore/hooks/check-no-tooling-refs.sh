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
# _templates/) are carved out. See check-frontmatter.sh for the scoping rationale.

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
    echo "lore hooks: jq/python3 not found and payload could not be parsed — reader-facing-output rule NOT enforced for this write." >&2
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

# --- guard: a scaffolded Lore docs project only -------------------------------------
# These rules are Lore's Definition of Done, not universal truth. The plugin is
# installed per user, so this hook also runs in repos that have nothing to do with it —
# and plenty of projects keep plain markdown and images under docs/. Blocking those
# writes enforced a DoD their author never opted into. The marker is the same one every
# evidence hook uses: a .claude/CLAUDE.md that imports the methodology.
[ -f "$root/.claude/CLAUDE.md" ] || exit 0
grep -q '@lore-methodology.md' "$root/.claude/CLAUDE.md" 2>/dev/null || exit 0

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
