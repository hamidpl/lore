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

input=$(cat 2>/dev/null || true)

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
[ -n "$file_path" ] || exit 0

root="${CLAUDE_PROJECT_DIR:-$cwd}"
root="${root%/}"
case "$file_path" in
  /*) [ -n "$root" ] && rel="${file_path#"$root"/}" || rel="$file_path" ;;
  *)  rel="$file_path" ;;
esac

# Only a genuinely new content page under docs/.
case "$rel" in
  docs/*.md|docs/*.mdx) : ;;
  *) exit 0 ;;
esac
[ -e "$file_path" ] && exit 0          # an overwrite of an existing page, not a new one
[ -f "$root/.claude/CLAUDE.md" ] || exit 0
grep -q '@lore-methodology.md' "$root/.claude/CLAUDE.md" 2>/dev/null || exit 0

# Already have a census for this run? Then nothing to say.
ls "$root"/.claude/sources/*-census.md >/dev/null 2>&1 && exit 0

msg="DoD 0: you are creating a new page under docs/ and no source census exists yet at .claude/sources/*-census.md. Before writing prose: record the Run contract (0.4 — every explicit instruction the user gave for this run), fetch every source in this skill's manifest AND every trusted source configured in CLAUDE.md 1, and write each finding into the census with its receipt (0.1 — probe, HTTP status, saved raw payload). A zero-case needs the same receipt (0.2), and a source may only be called inaccessible on an observed status code (0.3)."

if command -v jq >/dev/null 2>&1; then
  jq -n --arg m "$msg" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse", additionalContext:$m}}'
elif command -v python3 >/dev/null 2>&1; then
  MSG="$msg" python3 -c 'import json,os;print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":os.environ["MSG"]}}))'
else
  echo "$msg" >&2
fi

exit 0
