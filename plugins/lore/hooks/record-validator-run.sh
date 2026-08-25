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
# Receipt: .claude/sources/.validator-receipt (TAB-separated, overwritten atomically):
#   line 1     iso8601 <TAB> verdict            — byte-identical to the old one-line (v1) receipt
#   line 2     format <TAB> 2                   — presence of this exact line is the v2 detector
#   file lines file <TAB> status <TAB> sha256 <TAB> project-relative path
#              one per docs/**/*.md|mdx, digested BY THIS HOOK at receipt time. Status:
#                reviewed  — named in the report's "Files reviewed:" line (no line at all
#                            blesses the whole snapshot, preserving v1 semantics)
#                inherited — unchanged (same sha) since a previous GREEN receipt covered it
#                waived    — covered by a user-approved .validation-waiver entry at this
#                            exact sha (the waiver is folded in here, then removed)
#                uncovered — present on disk but validated by nothing; the digest snapshot
#                            alone never grants coverage, so a narrow APPROVED cannot
#                            silently bless files the validator did not open
# History: .claude/sources/.validator-history — APPEND-ONLY, one line per run
#   (iso8601, verdict, reviewed-count, total-docs-count). The receipt keeps only the
#   latest state, which is all the Stop gate needs; how many rounds a delivery took, and
#   how the verdicts moved, is only reconstructible from this file.
# Degrade: with no sha tool on PATH the hook writes the v1 one-line receipt and the Stop
#   gate falls back to its mtime path — never crash, never block.
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
receipt="$root/.claude/sources/.validator-receipt"
waiver="$root/.claude/sources/.validation-waiver"
history="$root/.claude/sources/.validator-history"
tab=$(printf '\t')

# The files that exist right now — the snapshot the receipt describes. Paths are
# project-relative ("docs/…"), the same form the Stop gate rebuilds them in.
snapshot=$( (cd "$root" 2>/dev/null &&
  find docs -type f \( -name '*.md' -o -name '*.mdx' \) 2>/dev/null) || true)
total=0
[ -n "$snapshot" ] && total=$(printf '%s\n' "$snapshot" | grep -c .)

# --- degrade: no digest tool → the v1 one-line receipt, exactly as before ------------
if [ -z "$_sha_tool" ]; then
  printf '%s\t%s\n' "$ts" "$verdict" >"$receipt" 2>/dev/null || true
  printf '%s\t%s\t%s\t%s\n' "$ts" "$verdict" "-" "$total" >>"$history" 2>/dev/null || true
  exit 0
fi

# --- which files did the validator actually open and judge? --------------------------
# Parsed from the report's "**Files reviewed:** docs/a.md, docs/b.md" line, with the
# same defensive stance as the verdict parser: markdown decoration is stripped, the
# label must OPEN a line, and only comma-separated tokens that resolve to a
# docs/….md|mdx path survive — so prose cannot inject entries. No such line at all
# means a report predating this format: the whole snapshot is treated as reviewed,
# which is exactly what the v1 receipt asserted.
reviewed=$(printf '%s' "$msg" | awk '
  {
    line = $0
    gsub(/[*_`#>]/, "", line)
    sub(/^[^A-Za-z]+/, "", line)
    if (tolower(line) !~ /^files reviewed[[:space:]]*:/) next
    line = substr(line, index(line, ":") + 1)
    n = split(line, toks, ",")
    for (i = 1; i <= n; i++) {
      t = toks[i]
      sub(/^[[:space:]]+/, "", t); sub(/[[:space:]]+$/, "", t)
      p = index(t, "docs/")
      if (p == 0) continue
      t = substr(t, p)
      if (t ~ /\.(md|mdx)$/) print t
    }
  }' 2>/dev/null | sort -u)

# --- what did the previous receipt already cover? ------------------------------------
# Only a GREEN v2 receipt can pass coverage forward: inheriting from a BLOCKED run
# would launder its failures, and a v1 receipt carries no per-file state to inherit.
prev_ok=0
if [ -f "$receipt" ] && grep -q "^format${tab}2\$" "$receipt" 2>/dev/null; then
  case "$(head -n 1 "$receipt" 2>/dev/null | cut -f2)" in
    "APPROVED"|"APPROVED WITH WARNINGS") prev_ok=1 ;;
  esac
fi

# --- write the v2 receipt atomically -------------------------------------------------
# Status resolution per file, first match wins: reviewed (this run judged it) →
# inherited (same content a previous green run covered) → waived (user-approved waiver
# names this exact content) → uncovered.
reviewed_count=0
tmp="$receipt.tmp"
{
  printf '%s\t%s\n' "$ts" "$verdict"
  printf 'format\t2\n'
  if [ -n "$snapshot" ]; then
    printf '%s\n' "$snapshot" | while IFS= read -r f; do
      sha=$(lore_sha256 "$root/$f")
      [ -n "$sha" ] || continue
      status="uncovered"
      if [ -z "$reviewed" ] || printf '%s\n' "$reviewed" | grep -qxF "$f"; then
        status="reviewed"
      elif [ "$prev_ok" -eq 1 ] &&
           awk -F'\t' -v p="$f" -v s="$sha" \
             '$1 == "file" && $4 == p && $3 == s &&
              ($2 == "reviewed" || $2 == "inherited" || $2 == "waived") { ok = 1 }
              END { exit(ok ? 0 : 1) }' "$receipt" 2>/dev/null; then
        status="inherited"
      elif [ -f "$waiver" ] &&
           awk -F'\t' -v p="$f" -v s="$sha" \
             'NR > 1 { sub(/\r$/, ""); if ($1 == s && $2 == p) ok = 1 }
              END { exit(ok ? 0 : 1) }' "$waiver" 2>/dev/null; then
        status="waived"
      fi
      printf 'file\t%s\t%s\t%s\n' "$status" "$sha" "$f"
    done
  fi
} >"$tmp" 2>/dev/null
if ! mv "$tmp" "$receipt" 2>/dev/null; then
  # Leave the previous receipt intact rather than a half-written one: the Stop gate
  # blocks on a receipt it cannot read, and this hook must never be why a turn dies.
  rm -f "$tmp" 2>/dev/null
  exit 0
fi

reviewed_count=$(awk -F'\t' '$1 == "file" && $2 == "reviewed"' "$receipt" 2>/dev/null | grep -c . || true)

# A validator run supersedes any standing waiver: matching entries were folded into the
# receipt above, and stale ones must not linger to cover a future edit.
rm -f "$waiver" 2>/dev/null

printf '%s\t%s\t%s\t%s\n' "$ts" "$verdict" "$reviewed_count" "$total" >>"$history" 2>/dev/null || true

exit 0
