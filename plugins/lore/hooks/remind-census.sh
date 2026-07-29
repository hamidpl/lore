#!/bin/sh
# remind-census.sh — PreToolUse hook (matcher: Write). NEVER BLOCKS.
#
# The producer skills already say "⛔ do not start writing until the census exists",
# and nothing enforced it — a rule read once at session start has little pull by the
# time the model is deep in a write. This puts the reminder at the moment of the
# action instead, where it can actually land.
#
# Deliberately advisory: it emits additionalContext and exits 0. Denying the write
# would false-block /lore:init (which scaffolds docs/intro.md before any census) and
# ordinary hand edits. The real gates are check-census.sh (on the census write) and
# verify-docs.sh (on Stop).

# shellcheck disable=SC2034  # read by json_field() in lib/common.sh, per its contract
input=$(cat 2>/dev/null || true)

_lib="$(dirname "$0")/lib/common.sh"
[ -r "$_lib" ] || exit 0
# shellcheck source=lib/common.sh
. "$_lib"

file_path=$(json_field 'tool_input file_path')
cwd=$(json_field 'cwd')
[ -n "$file_path" ] || exit 0

root=$(lore_root "$cwd")
rel=$(lore_rel "$file_path" "$root")

# Only a genuinely new content page under docs/.
case "$rel" in
  docs/*.md|docs/*.mdx) : ;;
  *) exit 0 ;;
esac
[ -e "$file_path" ] && exit 0          # an overwrite of an existing page, not a new one
lore_is_project "$root" || exit 0

# Already have a census for this run? Then nothing to say.
ls "$root"/.claude/sources/*-census.md >/dev/null 2>&1 && exit 0

# The § signs are load-bearing: this text is injected verbatim as additionalContext, and
# the rules it points at are numbered §0.1–§0.4 everywhere else. Stripped of the sign it
# read "DoD 0", "CLAUDE.md 1", "(0.4)" — section numbers the model cannot resolve back to
# anything, in the one message whose whole job is to point at them.
msg="DoD §0: you are creating a new page under docs/ and no source census exists yet at .claude/sources/*-census.md. Before writing prose: record the Run contract (§0.4 — every explicit instruction the user gave for this run), fetch every source in this skill's manifest AND every trusted source configured in CLAUDE.md §1, and write each finding into the census with its receipt (§0.1 — probe, HTTP status, saved raw payload). A zero-case needs the same receipt (§0.2), and a source may only be called inaccessible on an observed status code (§0.3)."

if command -v jq >/dev/null 2>&1; then
  jq -n --arg m "$msg" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse", additionalContext:$m}}'
elif command -v python3 >/dev/null 2>&1; then
  MSG="$msg" python3 -c 'import json,os;print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":os.environ["MSG"]}}))'
else
  echo "$msg" >&2
fi

exit 0
