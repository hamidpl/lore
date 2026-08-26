#!/bin/sh
# record-evidence.sh — PostToolUse hook (matcher: WebFetch|Task|Bash|mcp__*browser*)
#
# WHY THIS EXISTS. Every §0 obligation used to be discharged by writing a sentence:
# "nothing relevant — confirmed searched" is the same string whether the source was
# read or never touched, and the model that skipped the work authors the sentence.
# This hook writes an APPEND-ONLY log of the fetches and subagent runs that actually
# happened. The model does not author it, so an entry for a source it never touched
# is not something it produces in the ordinary course of work, and check-census.sh can
# hold every census claim against it (DoD 0.1). This is a guard against a step being
# skipped by accident, not a tamper-proof record: an agent with shell access can append
# to any file. See the threat model in the plugin's CLAUDE.md.
#
# NEVER BLOCKS — always exit 0. This is a recorder, not a gate.
#
# Log: .claude/sources/.evidence-log
#   TAB-separated: iso8601, tool, detail, TIER, [agent], [sha]   (written via
#   lore_append_evidence in lib/common.sh — the single writer of this file)
#
# AGENT COLUMN. When the tool call happened inside a subagent, the runtime puts an
# `agent_id` on the hook payload (Claude Code ≥ 2.1.69) and it is recorded as field 5,
# so a fetch made by one of several parallel extraction workers is attributable to
# that worker. Absent the field (main thread, or an older runtime) the line has 4
# fields; every reader uses `NF >= 4`, so both shapes are read the same way.
#
# TIERS. Not every entry is a fetch. `verified` means a fetching tool actually ran:
# WebFetch, a browser navigation, a subagent. `mentioned` means a URL merely appeared
# inside a Bash command — `grep -rn "https://x" ./notes` contacted nothing, and a
# `curl` that failed contacted nothing either. check-census.sh accepts only `verified`
# entries as proof a source was read; `mentioned` stays for context. Without the split,
# a model manufactured a receipt for a source it never opened, during ordinary work.
# Lines with no 4th field predate tiering and are read as `verified`.
# Guard: only acts in a scaffolded Lore project (a .claude/CLAUDE.md that imports
# lore-methodology.md), so it never litters unrelated repos.

input=$(cat 2>/dev/null || true)

_lib="$(dirname "$0")/lib/common.sh"
[ -r "$_lib" ] || exit 0
# shellcheck source=lib/common.sh
. "$_lib"

# --- FAST PATH: bail before spawning any JSON parser -------------------------------
# This hook is on the Bash matcher, so it runs on the highest-frequency tool there is,
# in every repo where Lore is installed — including repos that have nothing to do with
# documentation. Parsing first and checking the guard second cost ~16ms on every Bash
# call in an unrelated project. When CLAUDE_PROJECT_DIR is set (the normal case) the
# guard is two filesystem ops and we exit without ever starting jq.
lore_env_marker_ok || exit 0

# Everything we record is either a URL or a subagent type. A payload containing
# neither can be dropped without parsing it — which is the overwhelming majority of
# Bash calls (`ls`, `git status`, a test run …).
case "$input" in
  *http*|*subagent_type*|*docs/*) : ;;
  *) exit 0 ;;
esac

tool=$(json_field 'tool_name')
cwd=$(json_field 'cwd')
[ -n "$tool" ] || exit 0

root=$(lore_root "$cwd")
lore_is_project "$root" || exit 0

# Who is fetching: empty on the main thread, the subagent id inside a subagent.
agent=$(json_field 'agent_id')

# --- what to record, per tool ---
# WebFetch / browser navigation → the URL. Task → the subagent type. Bash → any URL
# in the command (covers curl/wget, which is how a source often gets fetched).
detail=""
tier="verified"
case "$tool" in
  WebFetch)
    detail=$(json_field 'tool_input url')
    ;;
  Task)
    detail=$(json_field 'tool_input subagent_type')
    [ -n "$detail" ] && detail="subagent:$detail"
    ;;
  Bash)
    cmd=$(json_field 'tool_input command')
    # Extract every http(s) URL the command mentioned; one log line each. A URL in a
    # command string is NOT evidence the command fetched it, so these are `mentioned`.
    # A real fetch from a script records itself: figma-probe.sh appends its own
    # `verified` entry once it has an HTTP status in hand.
    detail=$(printf '%s' "$cmd" | grep -oE 'https?://[^ "'"'"'`)>]+' 2>/dev/null | head -n 10)
    tier="mentioned"
    ;;
  Write|Edit)
    # Record that THIS session edited documentation. The Stop gate uses this to
    # apply only to sessions that actually produced docs — otherwise an unrelated
    # `git pull` that touches docs/ would block the next turn in any session,
    # which is a false block on someone who did nothing wrong.
    fp=$(json_field 'tool_input file_path')
    sid=$(json_field 'session_id')
    case "${fp#"$root"/}" in
      docs/*)
        [ -n "$sid" ] || sid="unknown-session"
        lore_ensure_sources_dir "$root" || exit 0
        touched="$root/.claude/sources/.docs-touched"
        grep -qxF "$sid" "$touched" 2>/dev/null || printf '%s\n' "$sid" >>"$touched" 2>/dev/null
        ;;
    esac
    exit 0
    ;;
  *)
    # MCP browser tools (mcp__<server>__browser_navigate, …) carry a url too.
    detail=$(json_field 'tool_input url')
    ;;
esac

[ -n "$detail" ] || exit 0

# Only the Bash branch is legitimately multi-line — grep emits one URL per line, and
# each becomes its own entry. For every other tool the value comes straight from tool
# input, and lore_append_evidence keeps only its first line: a URL carrying an embedded
# newline used to become TWO log lines, the second one a forged entry for a host never
# contacted, in the very record the census is checked against.
case "$tool" in
  Bash) : ;;
  *) detail=$(printf '%s' "$detail" | head -n 1) ;;
esac

lore_ensure_sources_dir "$root" || exit 0

printf '%s\n' "$detail" | while IFS= read -r d; do
  lore_append_evidence "$root" "$tool" "$d" "$tier" "$agent"
done

exit 0
