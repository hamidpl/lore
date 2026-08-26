#!/bin/sh
# require-worker-evidence.sh — SubagentStop hook (matcher: lore:figma-extractor), BLOCKING (exit 2)
#
# WHY THIS EXISTS. When extraction fans out to several lore:figma-extractor workers, each
# returns a summary — and a summary is the laundering surface the evidence model exists to
# close: a worker that fetched nothing can still return counts. The main agent merges
# what it is given. So a worker may not finish until its claims are backed by artifacts
# a hook or a script wrote: every RECEIPT line it returns names a raw payload that exists
# on disk, and the evidence log holds a verified Figma fetch.
#
# HOW A WORKER'S FETCHES ARE KNOWN. Two ways, either suffices:
#   - by attribution: on Claude Code ≥ 2.1.69 tool hooks inside a subagent carry agent_id,
#     and record-evidence.sh writes it as field 5 — so `verified` lines carrying THIS
#     worker's id are its own fetches;
#   - by the worker's own claims: the RECEIPT lines in its final message (`raw=<path>`),
#     which figma-probe.sh prints and self-logs. This is the path on 2.1.52, where tool
#     hooks inside a subagent carry no agent_id (measured); the claim is falsified against
#     the file on disk and the log, which is the evidence model's own shape.
# A worker with neither is told, via exit 2, what to do and keeps running (SubagentStop
# exit 2 re-prompts the subagent). `stop_hook_active` guards the loop.
#
# Guard: only acts in a scaffolded Lore project; never blocks a worker that is not an
# extraction worker (matcher), and exits 0 rather than guess when the message is empty.

# shellcheck disable=SC2034  # read by json_field() in lib/common.sh, per its contract
input=$(cat 2>/dev/null || true)

_lib="$(dirname "$0")/lib/common.sh"
[ -r "$_lib" ] || exit 0
# shellcheck source=lib/common.sh
. "$_lib"

root=$(lore_root "$(json_field 'cwd')")
lore_is_project "$root" || exit 0
[ "$(json_field 'stop_hook_active')" = "true" ] && exit 0

case "$(json_field 'agent_type')" in
  ''|figma-extractor|lore:figma-extractor) : ;;
  *) exit 0 ;;
esac

msg=$(json_field 'last_assistant_message')
[ -n "$msg" ] || exit 0
agent_id=$(json_field 'agent_id')
log="$root/.claude/sources/.evidence-log"

# --- attributed fetches (runtime ≥ 2.1.69) ------------------------------------------
attributed=0
if [ -n "$agent_id" ] && [ -f "$log" ]; then
  attributed=$(awk -F'\t' -v a="$agent_id" 'NF >= 5 && $5 == a && $4 == "verified"' "$log" 2>/dev/null | grep -c . || true)
fi

# --- claimed receipts ---------------------------------------------------------------
raws=$(printf '%s' "$msg" | grep -oE 'raw=[^[:space:]`|)]+' 2>/dev/null | sed 's/^raw=//' | sort -u)

problems=""
if [ -z "$raws" ] && [ "${attributed:-0}" -eq 0 ]; then
  problems="no RECEIPT line in the summary and no fetch attributed to this worker in the evidence log"
fi
for r in $raws; do
  case "$r" in
    /*) p=$r ;;
    *)  p="$root/$r" ;;
  esac
  [ -s "$p" ] || problems="$problems
  - raw payload named by a RECEIPT is missing or empty: $r"
done
if [ -n "$raws" ] || [ "${attributed:-0}" -gt 0 ]; then
  if ! awk -F'\t' '{ tier = (NF >= 4 ? $4 : "verified") } tier == "verified" && index($3, "api.figma.com") { f = 1 } END { exit(f ? 0 : 1) }' "$log" 2>/dev/null; then
    problems="$problems
  - the evidence log holds no verified api.figma.com fetch (figma-probe.sh records one per call)"
  fi
fi

[ -n "$problems" ] || exit 0

cat >&2 <<EOF
BLOCKED (§0.1): this extraction worker cannot finish yet — $problems
A count is a claim; the receipt behind it is the probe's RECEIPT line and the raw payload it names. Fetch every node set you were given through \${CLAUDE_PLUGIN_ROOT}/scripts/figma-probe.sh (it saves the payload and logs the fetch), then return every RECEIPT and COUNT line verbatim in your summary. A source you could not fetch is reported as a failed read with its HTTP status, never as a zero.
EOF
exit 2
