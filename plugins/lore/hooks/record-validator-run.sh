#!/bin/sh
# record-validator-run.sh — SubagentStop hook (matcher: lore:doc-validator).
#
# Producer skills have always been told to run lore:doc-validator before delivery,
# and nothing ever checked that they did — so the one step that would have caught a
# skipped source was itself the easiest step to skip. This hook records each real
# validator run and the verdict it returned; verify-docs.sh (Stop) then refuses to
# let a turn end when documentation changed but no fresh, green run exists.
#
# The receipt is written by this hook from the subagent's own final message, so a run
# that never happened leaves no receipt in the ordinary course of writing documentation.
# It is a plain file, and an agent with shell access can write one — the gate exists to
# stop a step being skipped by accident, not to withstand a deliberate forgery.
#
# NEVER BLOCKS — always exit 0.
#
# Receipt: .claude/sources/.validator-receipt  (TAB-separated: iso8601, verdict)
# Guard: only acts in a scaffolded Lore project.

# shellcheck disable=SC2034  # read by json_field() in lib/common.sh, per its contract
input=$(cat 2>/dev/null || true)

_lib="$(dirname "$0")/lib/common.sh"
[ -r "$_lib" ] || exit 0
# shellcheck source=lib/common.sh
. "$_lib"

root=$(lore_root "$(json_field 'cwd')")
lore_is_project "$root" || exit 0

msg=$(json_field 'last_assistant_message')

# The validator ends with an explicit recommendation line. Order matters: BLOCKED
# wins, then the qualified pass, then the clean pass. Anything else is UNKNOWN,
# which the Stop gate treats as "not green".
#
# The verdict must OPEN a line — a bare substring search read the verdict out of
# ordinary prose ("Nothing was BLOCKED" → BLOCKED; a report mentioning APPROVED in
# passing → APPROVED). Markdown decoration, a leading emoji and a "Recommendation:"
# style label are stripped before the comparison, so `❌ **BLOCKED — DO NOT DELIVER**`
# and `Verdict: APPROVED` both resolve, while mid-sentence mentions do not.
verdict=$(printf '%s' "$msg" | awk '
  {
    line = $0
    gsub(/[*_`#>]/, "", line)                       # markdown emphasis / headings
    sub(/^[^A-Za-z]+/, "", line)                    # emoji, bullets, whitespace
    sub(/^(Final|Overall)[[:space:]]+/, "", line)
    sub(/^(Recommendation|Verdict|Result|Status)[Ss]?[[:space:]]*/, "", line)
    sub(/^[^A-Za-z]+/, "", line)                    # the separator after a label
    up = toupper(line)
    if (up ~ /^BLOCKED([^A-Z]|$)/) b = 1
    else if (up ~ /^APPROVED WITH WARNINGS([^A-Z]|$)/) w = 1
    else if (up ~ /^APPROVED([^A-Z]|$)/) a = 1
  }
  END {
    if (b) print "BLOCKED"
    else if (w) print "APPROVED WITH WARNINGS"
    else if (a) print "APPROVED"
  }
' 2>/dev/null)

# Fallback: the verdict is defined to sit at the END of the report, so if nothing
# opened a line, look for it in the tail only. This keeps a differently-formatted
# report from silently becoming UNKNOWN (which blocks), without letting prose in the
# body of a long report set the verdict.
if [ -z "$verdict" ]; then
  tail_msg=$(printf '%s' "$msg" | grep -v '^[[:space:]]*$' | tail -n 10)
  if printf '%s' "$tail_msg" | grep -q 'BLOCKED'; then
    verdict="BLOCKED"
  elif printf '%s' "$tail_msg" | grep -q 'APPROVED WITH WARNINGS'; then
    verdict="APPROVED WITH WARNINGS"
  elif printf '%s' "$tail_msg" | grep -q 'APPROVED'; then
    verdict="APPROVED"
  fi
fi

[ -n "$verdict" ] || verdict="UNKNOWN"

mkdir -p "$root/.claude/sources" 2>/dev/null || exit 0
ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo 'unknown')
printf '%s\t%s\n' "$ts" "$verdict" >"$root/.claude/sources/.validator-receipt" 2>/dev/null || true

exit 0
