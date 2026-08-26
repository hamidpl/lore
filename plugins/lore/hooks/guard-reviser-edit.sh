#!/bin/sh
# guard-reviser-edit.sh — PreToolUse hook (matcher: Edit|Write), BLOCKING (exit 2)
#
# WHY THIS EXISTS. lore:doc-reviser is the one subagent allowed to edit documentation,
# and its authority is deliberately small: the targets a validator report names, one
# exact occurrence at a time, under docs/ only. Its agent file says so — but a rule
# only the model enforces is enforced by nothing. The runtime puts `agent_type` on
# every hook payload fired inside a subagent (Claude Code ≥ 2.1.69), so the three
# boundaries a careless reviser is most likely to cross can be denied here:
#
#   - a Write            → it may not create files or rewrite one wholesale
#   - replace_all        → one exact occurrence; a tree-wide identical edit once
#                          falsified twenty-one pages while every line read correctly
#   - a path outside docs/ → never the census or the evidence artifacts under .claude/
#
# The reviser's frontmatter already withholds Write; this hook is the second lock on
# the same door, and the only lock on the other two. Any other agent — including the
# main thread — is untouched. Without an agent_type field (older runtime) the hook
# cannot tell who is editing and exits 0: the prose still governs, and CLAUDE.md
# states the limit.
#
# Guard: acts only in a scaffolded Lore project.

input=$(cat 2>/dev/null || true)

_lib="$(dirname "$0")/lib/common.sh"
[ -r "$_lib" ] || exit 0
# shellcheck source=lib/common.sh
. "$_lib"

lore_env_marker_ok || exit 0
case "$input" in
  *doc-reviser*) : ;;
  *) exit 0 ;;
esac

agent_type=$(json_field 'agent_type')
case "$agent_type" in
  doc-reviser|lore:doc-reviser) : ;;
  *) exit 0 ;;
esac

tool=$(json_field 'tool_name')
fp=$(json_field 'tool_input file_path')
root=$(lore_root "$(json_field 'cwd')")
lore_is_project "$root" || exit 0
rel=$(lore_rel "$fp" "$root")

deny() {
  printf 'BLOCKED (lore:doc-reviser): %s\nThe reviser applies the validator'"'"'s findings at the targets they name, one exact occurrence at a time, under docs/ only. Return the finding as skipped-needs-scope or rejected instead; the user decides what lies outside that authority.\n' "$1" >&2
  exit 2
}

case "$tool" in
  Write) deny "a Write is not an edit — the reviser may not create or rewrite a file wholesale ($rel)." ;;
  Edit)
    case "$rel" in
      docs/*) : ;;
      *) deny "the path is outside docs/ ($rel) — the census and the evidence artifacts are the record the reviser is checked against, never its target." ;;
    esac
    [ "$(json_field 'tool_input replace_all')" = "true" ] &&
      deny "replace_all on $rel — every reviser edit is one exact occurrence in one file."
    ;;
esac
exit 0
