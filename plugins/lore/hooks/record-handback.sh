#!/bin/sh
# record-handback.sh — PostToolUse hook (matcher: SubagentHandback), never blocks
#
# WHY THIS EXISTS. Claude Code ≥ 2.1.271 (in auto mode) delivers a subagent's report
# through a SubagentHandback tool call, not as its final text. The SubagentStop payload
# then has no report: on 2.1.301 `last_assistant_message` is absent altogether (measured),
# and the report is that call's `tool_input.message`. Lore's SubagentStop hooks parse
# the report — the validator's verdict, the reviser's `Files edited:`, an extraction
# worker's RECEIPT lines — so without it every validator run was recorded as UNKNOWN and
# the Stop gate blocked every turn. The hooks reference names this hook event as the way
# to read the report; the subagent's transcript is only a fallback, because the
# transcript is written asynchronously and is not guaranteed to hold the call yet when
# SubagentStop fires.
#
# PostToolUse, not PreToolUse: the call has then actually delivered the report (a
# PreToolUse can still be denied), and it fires before the subagent's SubagentStop
# (measured on 2.1.301: PreToolUse → PostToolUse → SubagentStop).
#
# Store: .claude/sources/.handback/<agent_id> — the report text, overwritten by a later
#   hand-back of the same agent (the last one is what its caller received). Read by
#   lore_subagent_report in lib/common.sh. Hook-written and git-ignored, like every
#   other run artifact; files older than a day are pruned here.
# Scope: only Lore's own subagents whose report a SubagentStop hook parses.
# Guard: only acts in a scaffolded Lore project.

# shellcheck disable=SC2034  # read by json_field() in lib/common.sh, per its contract
input=$(cat 2>/dev/null || true)

_lib="$(dirname "$0")/lib/common.sh"
[ -r "$_lib" ] || exit 0
# shellcheck source=lib/common.sh
. "$_lib"

lore_env_marker_ok || exit 0

case "$(json_field 'agent_type')" in
  doc-validator|lore:doc-validator|doc-reviser|lore:doc-reviser|figma-extractor|lore:figma-extractor) : ;;
  *) exit 0 ;;
esac
aid=$(lore_subagent_id)
[ -n "$aid" ] || exit 0

root=$(lore_root "$(json_field 'cwd')")
lore_is_project "$root" || exit 0

# The report is free text with escaped newlines and quotes; the last-resort text scan
# cannot decode that faithfully, so with no JSON tool nothing is recorded.
[ -n "$_json_tool" ] || exit 0
msg=$(json_field 'tool_input message')
[ -n "$msg" ] || exit 0

lore_ensure_sources_dir "$root" || exit 0
dir="$root/.claude/sources/.handback"
mkdir -p "$dir" 2>/dev/null || exit 0
find "$dir" -type f -mtime +1 -exec rm -f {} + 2>/dev/null
printf '%s\n' "$msg" >"$dir/$aid.tmp" 2>/dev/null && mv "$dir/$aid.tmp" "$dir/$aid" 2>/dev/null
rm -f "$dir/$aid.tmp" 2>/dev/null
exit 0
