#!/bin/sh
# guard-under-review.sh — PreToolUse (Edit|Write|Task) + PostToolUse (Task), BLOCKING on edits
#
# WHY THIS EXISTS. The Auto-Validation Rule says fixes are applied by lore:doc-reviser,
# never by the agent that wrote the page. In the first measured runs of that rule the
# main agent read it, then applied the batch itself — twice out of two. A routing rule
# only the model follows is followed when convenient. This hook makes the boundary a
# denial: while the standing validator verdict is BLOCKED, an edit to docs/ is allowed
# only inside a lore:doc-reviser run.
#
# HOW "INSIDE A REVISER RUN" IS KNOWN. Not by `agent_type` on the edit's own payload —
# on Claude Code 2.1.52 tool hooks fired inside a subagent carry neither agent_id nor
# agent_type (measured). Instead the reviser's *invocation* is bracketed: the main
# thread's PreToolUse on `Task` with subagent_type lore:doc-reviser writes a marker
# file, and PostToolUse on that Task (or the reviser's SubagentStop, in
# record-validator-run.sh) removes it. Both events carry subagent_type in tool_input on
# every version the plugin supports. The marker is hook-written, lives with the other
# run artifacts, and is stale-proofed by age (30 min) so a crashed reviser cannot leave
# the door open.
#
# WHAT IS NOT GATED. Drafting (no receipt yet), edits after a green verdict (the digest
# gate reports those), anything outside docs/ (the census is the evidence-class fix and
# belongs to the main agent), and any repo that is not a Lore project.
#
# Consistent with the threat model: the marker is a plain file. It stops the routing
# from being skipped by accident, not a deliberate forgery.

input=$(cat 2>/dev/null || true)

_lib="$(dirname "$0")/lib/common.sh"
[ -r "$_lib" ] || exit 0
# shellcheck source=lib/common.sh
. "$_lib"

lore_env_marker_ok || exit 0
case "$input" in
  *docs/*|*subagent_type*) : ;;
  *) exit 0 ;;
esac

event=$(json_field 'hook_event_name')
tool=$(json_field 'tool_name')
root=$(lore_root "$(json_field 'cwd')")
lore_is_project "$root" || exit 0
marker="$root/.claude/sources/.reviser-active"

# --- bracket the reviser run -------------------------------------------------------
if [ "$tool" = "Task" ]; then
  case "$(json_field 'tool_input subagent_type')" in
    doc-reviser|lore:doc-reviser) : ;;
    *) exit 0 ;;
  esac
  case "$event" in
    PreToolUse)
      mkdir -p "$root/.claude/sources" 2>/dev/null || exit 0
      date -u '+%s' >"$marker" 2>/dev/null || true
      ;;
    PostToolUse) rm -f "$marker" 2>/dev/null ;;
  esac
  exit 0
fi

# --- gate an edit ------------------------------------------------------------------
[ "$event" = "PreToolUse" ] || exit 0
fp=$(json_field 'tool_input file_path')
rel=$(lore_rel "$fp" "$root")
case "$rel" in
  docs/*.md|docs/*.mdx) : ;;
  *) exit 0 ;;
esac
lore_carved_out "$rel" && exit 0

receipt="$root/.claude/sources/.validator-receipt"
[ -f "$receipt" ] || exit 0
[ "$(head -n 1 "$receipt" 2>/dev/null | cut -f2)" = "BLOCKED" ] || exit 0

# inside a reviser run? (marker younger than 30 minutes, or agent_type says so)
if [ -f "$marker" ]; then
  then=$(cat "$marker" 2>/dev/null || echo 0)
  now=$(date -u '+%s')
  case "$then" in *[!0-9]*|'') then=0 ;; esac
  [ $((now - then)) -lt 1800 ] && exit 0
fi
case "$(json_field 'agent_type')" in
  doc-reviser|lore:doc-reviser) exit 0 ;;
esac

cat >&2 <<EOF
BLOCKED (Auto-Validation Rule): the last lore:doc-validator verdict is BLOCKED, and $rel is being edited outside a lore:doc-reviser run.
Fixes are not applied by the agent that wrote the page. Hand every mechanical/content finding of this round to lore:doc-reviser (Task tool) as ONE batch, then run one scoped validator round over the files its 'Files edited:' line names. A finding of class 'evidence' is fixed in the census (not under docs/); a finding of class 'decision' goes to the user.
EOF
exit 2
