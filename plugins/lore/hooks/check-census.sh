#!/bin/sh
# check-census.sh — the single place every source-census rule lives.
#
# TWO MODES, because a census is written incrementally and judging it needs to happen
# twice, at different strictnesses:
#
#   (default)            PostToolUse hook (matcher: Write|Edit), BLOCKING (exit 2).
#                        Validates SHAPE — is what has been written so far well formed
#                        and receipted? A census is written at pre-flight, before any
#                        fetching, so shape is all that can be true yet.
#   --complete <file>    Invoked by verify-docs.sh at Stop, BLOCKING (exit 2).
#                        Validates COMPLETENESS — the run is over, so every source type
#                        the input's manifest names must now carry a real count.
#
# Why the split: completeness used to be enforced at write time, which blocked the
# exact pre-flight write the skills prescribe. The cheapest way out of that block was a
# placeholder ("## Observation coverage" with no rows; one prose line naming the six
# Figma source types), and the placeholder then satisfied the check FOREVER, because
# nothing re-examined it. The gate taught the model to disarm the gate. Shape at write,
# completeness at Stop.
#
# The rules enforced:
#   §0.1  every source row carries a receipt (status + a raw payload that exists), and
#         every URL claimed appears in the hook-written .evidence-log as a VERIFIED fetch
#   §0.2  a zero sits beside the same receipt and a corroboration from the raw payload
#   §0.4  a Run contract block exists
#   site  Observation coverage exists with real rows, and its screenshots exist
#   figma every manifest source type has a counted row
#
# Scope: ONLY .claude/sources/*-census.md. Everything else exits 0 untouched — the
# other Lore hooks deliberately skip .claude/, and this one is the single carve-out.

problems=""
add() { problems="$problems
  - $1"; }

# --- shared helpers ----------------------------------------------------------------

# Print the table rows of a "## <heading>" section, minus the |---| separator. Fenced
# blocks are skipped — a census may quote the format it is following, and a quoted
# example is not a claim. The column header is left in: callers match on cell content,
# and no header cell can satisfy those matches, so guessing which row is the header
# would add a failure mode without removing one.
section_rows() { # $1 file, $2 heading regex
  awk -v want="$2" '
    /^```/ { fence = !fence; next }
    fence { next }
    /^##/ { inside = ($0 ~ want) ? 1 : 0; next }
    inside && /^\|/ && $0 !~ /^\|[[:space:]]*-+/ { print }
  ' "$1" 2>/dev/null
}

# Every non-fenced line of the file, so row checks never judge a quoted example.
live_lines() { # $1 file
  awk '/^```/ { fence = !fence; next } !fence { print }' "$1" 2>/dev/null
}

has_status() { printf '%s' "$1" | grep -qE '(^|[^0-9])[1-5][0-9][0-9]([^0-9]|$)'; }
has_raw()    { printf '%s' "$1" | grep -qE '\.claude/sources/raw/[^ |]+'; }

# --- COMPLETENESS (Stop) ------------------------------------------------------------
# The run is over. Every source the active input type's manifest names must now carry a
# counted row — a heading with nothing under it is not coverage.
if [ "${1:-}" = "--complete" ]; then
  f=$2
  [ -n "$f" ] && [ -f "$f" ] || exit 0
  base=${f##*/}

  case "$base" in
    site-*-census.md)
      if ! grep -q '^##[[:space:]]*Observation coverage' "$f" 2>/dev/null; then
        add "site §0.4: no '## Observation coverage' block. One row per state actually observed (auth state × role × route × viewport) with its screenshot — a guest-only run must be visible as such, not implied."
      elif ! section_rows "$f" '[Oo]bservation coverage' |
             grep -qE '^\|[[:space:]]*[oO][0-9]+[[:space:]]*\|'; then
        add "site §0.4: '## Observation coverage' has no observed states. The heading alone records nothing — every state you actually reached needs an [o#] row naming its auth state, role, route, viewport and screenshot."
      fi
      ;;
    figma-*-census.md)
      if ! grep -q '^##[[:space:]]*Counts' "$f" 2>/dev/null; then
        add "figma §0: no '## Counts' block. Every manifest source type needs a counted row with the receipt that produced it, even when the count is zero."
      else
        rows=$(section_rows "$f" '[Cc]ounts')
        for st in comment annotation flow interaction variant variable; do
          row=$(printf '%s\n' "$rows" | awk -F'|' -v k="$st" '
            { c = tolower($2) } index(c, k) { print; exit }')
          if [ -z "$row" ]; then
            add "figma §0: the Counts block has no row for '$st'. A missing source type means that source was never checked — state the count and the receipt behind it, even when it is zero."
          elif ! printf '%s' "$row" | awk -F'|' '{ exit ($3 ~ /[0-9]/) ? 0 : 1 }'; then
            add "figma §0.1: the Counts row for '$st' carries no number — '$(printf '%s' "$row" | cut -c1-90)'. A source type without a count was not read; a zero is a count, a blank is not."
          fi
        done
      fi
      ;;
  esac

  if [ -n "$problems" ]; then
    echo "BLOCKED: ${f} is incomplete (DoD §0):$problems" >&2
    exit 2
  fi
  exit 0
fi

# --- SHAPE (PostToolUse) ------------------------------------------------------------

input=$(cat)

# --- FAST PATH: bail before spawning any JSON parser --------------------------------
# This hook is on Write|Edit, so it runs on every write in every repo where the plugin
# is installed — including repos that have nothing to do with documentation. Parsing
# first and scoping second charged a JSON parser to all of them. The census path is a
# literal substring of the payload, so a single case test drops everything else.
case "$input" in
  *-census.md*) : ;;
  *) exit 0 ;;
esac

# The same Lore-project guard the other evidence hooks use, so this one never acts in an
# unrelated repo either. (CLAUDE.md claimed all of them did this; only some did.)
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  _r="${CLAUDE_PROJECT_DIR%/}"
  [ -f "$_r/.claude/CLAUDE.md" ] || exit 0
  grep -q '@lore-methodology.md' "$_r/.claude/CLAUDE.md" 2>/dev/null || exit 0
fi

# --- pick a JSON extraction backend once (jq → python3 → sed last resort) ---
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

if [ -z "$file_path" ]; then
  if [ -z "$_json_tool" ] && [ -n "$input" ]; then
    echo "lore hooks: jq/python3 not found and payload could not be parsed — census rules NOT enforced for this write." >&2
  fi
  exit 0
fi

root="${CLAUDE_PROJECT_DIR:-$cwd}"
root="${root%/}"
case "$file_path" in
  /*) [ -n "$root" ] && rel="${file_path#"$root"/}" || rel="$file_path" ;;
  *)  rel="$file_path" ;;
esac

# --- in scope only for a source census ---
case "$rel" in
  .claude/sources/*-census.md) : ;;
  *) exit 0 ;;
esac

# Skip the plugin's own template/example copies of a census.
case "$rel" in
  *templates/*) exit 0 ;;
esac

# Guard again from the payload's cwd, for the case where CLAUDE_PROJECT_DIR was unset
# and the fast path above could not run.
[ -f "$root/.claude/CLAUDE.md" ] || exit 0
grep -q '@lore-methodology.md' "$root/.claude/CLAUDE.md" 2>/dev/null || exit 0

[ -f "$file_path" ] || exit 0

# --- §0.4: the Run contract block must exist --------------------------------------
# This is the one thing that IS true at pre-flight: the skills order it written before
# anything is fetched, so requiring it here costs nothing and catches its absence early.
if ! grep -q '^##[[:space:]]*Run contract' "$file_path" 2>/dev/null; then
  add "§0.4: no '## Run contract' block. Record every explicit user instruction for this run as a [u#] row (or the zero-case 'no explicit run instructions beyond the skill default')."
fi

# --- §0.1: EVERY trusted-source row needs a receipt, not only the zero-cases --------
# Receipts used to be checked only on rows that matched a zero-case phrase, so a row
# claiming a positive finding — the majority of rows — was never examined at all,
# though §0.1 says every row carries a receipt.
live_lines "$file_path" | while IFS= read -r line; do
  case "$line" in '|'*) : ;; *) continue ;; esac
  printf '%s' "$line" | grep -qE '^\|[[:space:]]*[tT][0-9]+[[:space:]]*\|' || continue
  if ! has_status "$line" || ! has_raw "$line"; then
    printf 'NO_RECEIPT\t%s\n' "$(printf '%s' "$line" | cut -c1-100)"
  fi
done >"${TMPDIR:-/tmp}/lore-census-row.$$" 2>/dev/null
while IFS="$(printf '\t')" read -r _ l; do
  add "§0.1: a trusted-source row with no receipt — '$l'. Every row needs the probe's HTTP status AND the saved payload under .claude/sources/raw/, whether it found something or nothing."
done <"${TMPDIR:-/tmp}/lore-census-row.$$"
rm -f "${TMPDIR:-/tmp}/lore-census-row.$$" 2>/dev/null

# --- §0.1/§0.2: zero-cases need the same receipt ------------------------------------
# The per-source zero-case phrases are the exact strings the skills prescribe.
zero_re='nothing relevant|confirmed searched|confirmed none|inaccessible|requires login|needs login'
live_lines "$file_path" | while IFS= read -r line; do
  case "$line" in
    '|---'*|'|-'*) continue ;;
    '|'*|'- ['*) : ;;
    *) continue ;;
  esac
  printf '%s' "$line" | grep -qiE "$zero_re" || continue
  if ! has_status "$line" || ! has_raw "$line"; then
    printf 'NO_ZERO_RECEIPT\t%s\n' "$(printf '%s' "$line" | cut -c1-100)"
  fi
done >"${TMPDIR:-/tmp}/lore-census-zero.$$" 2>/dev/null
while IFS="$(printf '\t')" read -r _ l; do
  add "§0.1/§0.2: a zero-case with no receipt — '$l'. State what you actually probed: an HTTP status AND a saved payload under .claude/sources/raw/. 'confirmed' is not evidence; a zero from an unproven probe is a failed read, not an absence."
done <"${TMPDIR:-/tmp}/lore-census-zero.$$"
rm -f "${TMPDIR:-/tmp}/lore-census-zero.$$" 2>/dev/null

# --- §0.2: a zero the probe itself contradicts is a parser failure, not an absence ---
# figma-probe.sh emits corroboration=RAW-HAS-ANNOTATION-DATA when the saved payload
# carries data the parse missed. Recording that as a zero is the exact bug that deleted
# every business rule the designers had written.
if live_lines "$file_path" | grep -qi 'corroboration=RAW-HAS-'; then
  add "§0.2: the census records a zero whose corroboration says the raw payload HAS that data (corroboration=RAW-HAS-…). That is a parser failure, not an absence — fix the read and re-probe. Recording it as a zero is a blocking §0 failure."
fi

# --- §0.1: every raw payload a row points at must exist and be non-empty -----------
live_lines "$file_path" | grep -oE '\.claude/sources/raw/[A-Za-z0-9._-]+' | sort -u |
while IFS= read -r p; do
  [ -n "$p" ] || continue
  case "$p" in *…*|*'{'*) continue ;; esac
  if [ ! -s "$root/$p" ]; then
    printf 'MISSING_RAW\t%s\n' "$p"
  fi
done >"${TMPDIR:-/tmp}/lore-census-raw.$$" 2>/dev/null
while IFS="$(printf '\t')" read -r _ p; do
  add "§0.1: the census cites raw payload '$p' but that file is missing or empty. Save the raw response before summarising it — a receipt whose payload does not exist is not a receipt."
done <"${TMPDIR:-/tmp}/lore-census-raw.$$"
rm -f "${TMPDIR:-/tmp}/lore-census-raw.$$" 2>/dev/null

# --- §0.1: every URL claimed must appear in the log as a VERIFIED fetch --------------
# Tiers matter here. record-evidence.sh also logs URLs it merely saw inside a Bash
# command, which is not a fetch: `grep -rn "https://x" ./notes` never contacted x. Only
# entries a fetching tool produced (WebFetch, browser navigation, figma-probe) count.
# Matching is by host (+ path prefix when present) so a census listing a site root is
# satisfied by a fetch of any page on it. The log is append-only across sessions.
log="$root/.claude/sources/.evidence-log"
live_lines "$file_path" | grep -oE 'https?://[A-Za-z0-9._~:/?#@!$&*+,;=%-]+' |
  sed 's/[.,)]*$//' | sort -u |
while IFS= read -r u; do
  [ -n "$u" ] || continue
  case "$u" in *…*|*'{'*|*example.com*) continue ;; esac
  host=$(printf '%s' "$u" | sed -E 's#^https?://([^/]+).*#\1#')
  [ -n "$host" ] || continue
  if [ ! -f "$log" ] ||
     ! awk -F'\t' -v h="$host" '
         { tier = (NF >= 4 ? $4 : "verified") }   # 3-field lines predate tiering
         tier == "verified" && index($3, h) { found = 1 }
         END { exit(found ? 0 : 1) }
       ' "$log" 2>/dev/null; then
    printf 'UNFETCHED\t%s\n' "$u"
  fi
done >"${TMPDIR:-/tmp}/lore-census-url.$$" 2>/dev/null
while IFS="$(printf '\t')" read -r _ u; do
  add "§0.1: the census claims '$u' as a source, but no verified fetch of that host was ever recorded in .claude/sources/.evidence-log. A URL that merely appeared in a shell command is not a fetch. Actually fetch it, then write the row. (If it really is unreachable, probe it and record the observed status — §0.3 forbids assuming.)"
done <"${TMPDIR:-/tmp}/lore-census-url.$$"
rm -f "${TMPDIR:-/tmp}/lore-census-url.$$" 2>/dev/null

# --- site census: screenshots the matrix cites must exist ---------------------------
# Shape, not completeness: whether the block must EXIST is a Stop-time question, but a
# screenshot named here and absent from disk is wrong the moment it is written.
case "$rel" in
  .claude/sources/site-*-census.md)
    live_lines "$file_path" |
      grep -oE '(static/img|/img)/[A-Za-z0-9._/-]+\.(png|jpg|jpeg|webp)' |
      sort -u | while IFS= read -r img; do
        case "$img" in /img/*) disk="static${img}" ;; *) disk="$img" ;; esac
        [ -s "$root/$disk" ] || printf 'MISSING_SHOT\t%s\n' "$disk"
      done >"${TMPDIR:-/tmp}/lore-census-shot.$$" 2>/dev/null
    while IFS="$(printf '\t')" read -r _ s; do
      add "site §0.1: the census cites screenshot '$s', which does not exist. A state you cannot show a capture of was not observed."
    done <"${TMPDIR:-/tmp}/lore-census-shot.$$"
    rm -f "${TMPDIR:-/tmp}/lore-census-shot.$$" 2>/dev/null
    ;;
esac

if [ -n "$problems" ]; then
  echo "BLOCKED: $rel does not satisfy the DoD §0 evidence rules:$problems" >&2
  echo "" >&2
  echo "A census row is a claim; §0.1 requires a receipt behind it (probe, HTTP status, saved raw payload). The words 'confirmed', 'verified' and 'checked' carry no evidentiary weight." >&2
  exit 2
fi

exit 0
