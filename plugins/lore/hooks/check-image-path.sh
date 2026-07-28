#!/bin/sh
# PostToolUse hook (matcher: Write|Edit)
# Enforces the BLOCKING image rules from CLAUDE.md Section 6 / Rule 1:
#   - Image files must never be written inside docs/ (they belong in static/img/)
#   - Markdown/MDX in docs/ must not reference images via /static/img/ (use /img/)
# Exit 2 = block: stderr is fed back to the model so it can self-correct.
#
# Scope: only product content under the project's docs/ directory. The path is
# resolved RELATIVE to the project root (CLAUDE_PROJECT_DIR, else the payload cwd)
# so a project that merely lives under some /.../docs/... ancestor is not affected.
# Intentional example/placeholder trees are carved out: .claude/, templates/,
# _templates/ are never checked.
#
# Degradation: if neither jq nor python3 is available and the payload cannot be
# parsed, the hook warns loudly on stderr and exits 0 (it never silently passes
# without telling anyone enforcement was skipped).

input=$(cat)

# --- pick a JSON extraction backend once (jq → python3 → sed last resort) ---
_json_tool=""
if command -v jq >/dev/null 2>&1; then
  _json_tool="jq"
elif command -v python3 >/dev/null 2>&1; then
  _json_tool="python3"
fi

# json_field <jq-filter> <python-dotted-path> <sed-key>
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
  # Empty only because we have no parser AND the payload was non-empty → warn.
  if [ -z "$_json_tool" ] && [ -n "$input" ]; then
    echo "lore hooks: jq/python3 not found and payload could not be parsed — image-path rule NOT enforced for this write." >&2
  fi
  exit 0
fi

# --- compute the project-relative path ---
root="${CLAUDE_PROJECT_DIR:-$cwd}"
root="${root%/}"
case "$file_path" in
  /*) [ -n "$root" ] && rel="${file_path#"$root"/}" || rel="$file_path" ;;
  *)  rel="$file_path" ;;   # already relative
esac
# If an absolute path did not live under root, rel still starts with '/', so the
# docs/ checks below simply do not match and we exit 0 (file outside project).

# --- guard: a scaffolded Lore docs project only -------------------------------------
# These rules are Lore's Definition of Done, not universal truth. The plugin is
# installed per user, so this hook also runs in repos that have nothing to do with it —
# and plenty of projects keep plain markdown and images under docs/. Blocking those
# writes enforced a DoD their author never opted into. The marker is the same one every
# evidence hook uses: a .claude/CLAUDE.md that imports the methodology.
[ -f "$root/.claude/CLAUDE.md" ] || exit 0
grep -q '@lore-methodology.md' "$root/.claude/CLAUDE.md" 2>/dev/null || exit 0

# --- carve-out: intentional examples/placeholders are never checked ---
case "$rel" in
  .claude/*|templates/*|_templates/*) exit 0 ;;
esac

# --- in scope only when the path is under the project's docs/ ---
# NOTE: matches a leading docs/ segment only. A nested docs dir in a monorepo
# (e.g. packages/site/docs/...) is intentionally NOT matched when Claude runs
# from the repo root — scope the hook per-package if you need that.
case "$rel" in
  docs/*) : ;;
  *) exit 0 ;;
esac

# Rule A: image binaries must not live under docs/
case "$rel" in
  *.png|*.jpg|*.jpeg|*.gif|*.webp|*.svg|*.ico)
    echo "BLOCKED: image file written under docs/ ($rel)." >&2
    echo "Images must be stored in static/img/{section}/ and referenced as /img/{section}/ (CLAUDE.md Section 6 / Rule 1)." >&2
    exit 2
    ;;
esac

# Rule B: markdown/MDX must not reference images via /static/img/
case "$rel" in
  *.md|*.mdx)
    if [ -f "$file_path" ] && grep -qE '\]\(/static/img/|src="/static/img/' -- "$file_path"; then
      echo "BLOCKED: markdown in $rel references images via /static/img/." >&2
      echo "Use /img/{section}/ instead (physical storage stays static/img/). See CLAUDE.md Section 6 / Rule 1." >&2
      exit 2
    fi
    # Rule C: mobile-view screenshots must be embedded as raw HTML <img>, not
    # markdown syntax — Docusaurus rewrites markdown-embedded images to hashed
    # /assets/images/ URLs at build time, stripping the /mobile/ segment the
    # half-width stylesheet keys on (CLAUDE.md Section 6).
    if [ -f "$file_path" ] && grep -qE '!\[[^]]*\]\([^)]*/mobile/' -- "$file_path"; then
      echo "BLOCKED: markdown in $rel embeds a /mobile/ screenshot with markdown ![..](..) syntax." >&2
      echo 'Use a raw HTML tag instead: <img src="/img/{section}/mobile/..." alt="..." /> — markdown-embedded images lose the /mobile/ path at build time, so the half-width mobile styling never applies (CLAUDE.md Section 6).' >&2
      exit 2
    fi
    ;;
esac

exit 0
