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

_lib="$(dirname "$0")/lib/common.sh"
[ -r "$_lib" ] || { echo "lore hooks: missing $_lib — image-path rule NOT enforced." >&2; exit 0; }
# shellcheck source=lib/common.sh
. "$_lib"

file_path=$(json_field 'tool_input file_path')
cwd=$(json_field 'cwd')

if [ -z "$file_path" ]; then
  # Empty only because we have no parser AND the payload was non-empty → warn.
  if [ -z "$_json_tool" ] && [ -n "$input" ]; then
    echo "lore hooks: jq/python3 not found and payload could not be parsed — image-path rule NOT enforced for this write." >&2
  fi
  exit 0
fi

root=$(lore_root "$cwd")
rel=$(lore_rel "$file_path" "$root")

lore_is_project "$root" || exit 0
lore_carved_out "$rel" && exit 0

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
