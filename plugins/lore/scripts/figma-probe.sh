#!/bin/sh
# figma-probe.sh — the canonical Figma REST probe for lore:figma-to-doc.
#
# WHY THIS EXISTS. Every Figma fetch used to be improvised: each run wrote its own
# curl and its own JSON walk, keyed on a field name copied from prose. Figma's own
# OpenAPI spec declares `AnnotationsTrait` as `properties: {}` — the annotation
# object's shape is UNDOCUMENTED and has changed. Keying on one field name (we used
# `notes`; the API returns `label`/`labelMarkdown`) turns a schema drift into
# `0 annotations — confirmed none`, which reads as a fact and silently deletes every
# business rule the designers wrote. So this script:
#
#   1. saves the RAW response to disk before anything interprets it (§0.1 receipt),
#   2. extracts annotations SCHEMA-AGNOSTICALLY — it dumps whole annotation objects,
#      never a named text field, so a Figma rename cannot hide them,
#   3. CORROBORATES every zero against the raw payload (§0.2) and fails loudly when
#      the raw bytes contain annotation data that the parse did not surface.
#
# Usage:
#   figma-probe.sh comments <fileKey> [outdir]
#   figma-probe.sh nodes    <fileKey> <ids>  [outdir]   # ids: comma-separated node ids
#   figma-probe.sh file     <fileKey>        [outdir]   # whole file (no depth limit)
#   figma-probe.sh parse    <rawFile>                   # re-analyse a saved payload, no network
#
# outdir defaults to .claude/sources/raw (created if missing).
# Auth: FIGMA_TOKEN in the environment. The token is never echoed or written.
#
# Prints a receipt line for the census, e.g.:
#   RECEIPT probe=GET:/v1/files/K/nodes status=200 bytes=482113 raw=.claude/sources/raw/figma-K-nodes.json scanned=412
#   COUNT annotations=17 corroboration=raw-has-annotations
#
# Exit codes: 0 ok · 1 usage/auth/dependency error · 3 transport or HTTP error
#             4 ⛔ PARSER FAILURE — raw payload carries annotation data but the
#               parse produced 0 (§0.2). Never record this as a zero.

set -u

usage() {
  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 1
}

[ "$#" -ge 2 ] || usage
mode=$1
key=$2

# --- annotation analysis, shared by the fetch modes and by `parse` -----------------
# Schema-agnostic by construction: it selects on the presence of a non-empty
# `annotations` array and emits whole objects. No annotation field name appears
# anywhere in this function, which is the entire point (see the header).
analyse_annotations() { # $1 raw file
  _raw=$1
  if ! command -v jq >/dev/null 2>&1; then
    echo "COUNT annotations=unknown corroboration=jq-unavailable-read-$_raw-by-hand"
    echo "figma-probe: jq not installed — cannot parse. Read $_raw directly; do NOT record a zero (DoD 0.2)." >&2
    return 0
  fi

  _n=$(jq '[.. | objects | select((.annotations? // []) | length > 0) | .annotations[]] | length' \
    "$_raw" 2>/dev/null || echo 0)
  : "${_n:=0}"

  # Second, independent method (DoD 0.2): look for the key in the raw TEXT rather
  # than in the parse. `"annotations":[]` is a real empty array; anything else is data.
  _rawdata=0
  if grep -q '"annotations"[[:space:]]*:[[:space:]]*\[[[:space:]]*[^][:space:]]' "$_raw" 2>/dev/null; then
    _rawdata=1
  fi

  if [ "$_n" -eq 0 ] && [ "$_rawdata" -eq 1 ]; then
    echo "COUNT annotations=0 corroboration=RAW-HAS-ANNOTATION-DATA"
    echo "⛔ figma-probe: PARSER FAILURE (DoD 0.2). The raw payload at $_raw contains non-empty" >&2
    echo "   \"annotations\" arrays, but the parse surfaced 0. This is NOT an absence — do not" >&2
    echo "   record '0 annotations — confirmed none'. Inspect the raw payload and fix the read." >&2
    return 4
  fi

  if [ "$_n" -eq 0 ]; then
    echo "COUNT annotations=0 corroboration=raw-confirms-none"
    return 0
  fi

  echo "COUNT annotations=$_n corroboration=raw-has-annotations"
  # Dump whole annotation objects (every key, verbatim) for the census raw list.
  jq -c '[.. | objects | select((.annotations? // []) | length > 0)
         | {node: .id, name: (.name // null), annotations: .annotations}] | .[]' "$_raw" 2>/dev/null
  return 0
}

# `parse` is offline: re-analyse a payload that is already on disk.
if [ "$mode" = "parse" ]; then
  [ -s "$key" ] || { echo "figma-probe: '$key' is missing or empty — that is a failed read, not a zero (DoD 0.2)." >&2; exit 3; }
  analyse_annotations "$key"
  exit $?
fi

# From here on `$key` is a Figma file key, not a path (`parse` took the path form and
# already exited above). It is interpolated into both the request path and the
# raw-payload filename, so constrain it to the character set a real key uses: without
# this, a key like `../../x` walks out of the output directory and reshapes the URL.
# `$ids` is already slugged below; this gives `$key` the same guarantee.
case "$key" in
  ''|*[!A-Za-z0-9_-]*)
    echo "figma-probe: invalid file key '$key' — a Figma file key is letters, digits, '-' and '_' only." >&2
    exit 1
    ;;
esac

case "$mode" in
  comments|file) outdir=${3:-.claude/sources/raw} ;;
  nodes)
    [ "$#" -ge 3 ] || usage
    ids=$3
    outdir=${4:-.claude/sources/raw}
    ;;
  *) usage ;;
esac

if [ -z "${FIGMA_TOKEN:-}" ]; then
  echo "figma-probe: FIGMA_TOKEN is not set — export it (or use the Figma MCP server) and retry." >&2
  exit 1
fi
command -v curl >/dev/null 2>&1 || { echo "figma-probe: curl not found." >&2; exit 1; }
have_jq=0
command -v jq >/dev/null 2>&1 && have_jq=1

mkdir -p "$outdir" || { echo "figma-probe: cannot create $outdir" >&2; exit 1; }

# Keep raw payloads (which can be large and carry product data) out of git, while
# the census itself stays committed. Self-healing for repos created before this.
if [ ! -f "$outdir/.gitignore" ]; then
  printf '# Raw source payloads — receipts for the census (%s). Not committed.\n*\n!.gitignore\n' \
    'DoD 0.1' >"$outdir/.gitignore"
fi

case "$mode" in
  comments) path="/v1/files/$key/comments"; raw="$outdir/figma-$key-comments.json" ;;
  file)     path="/v1/files/$key";          raw="$outdir/figma-$key-file.json" ;;
  nodes)
    path="/v1/files/$key/nodes?ids=$ids"
    # One raw file per id-set; keep the name stable and filesystem-safe.
    slug=$(printf '%s' "$ids" | tr -c 'A-Za-z0-9' '-' | cut -c1-40)
    raw="$outdir/figma-$key-nodes-$slug.json"
    ;;
esac

# NOTE ON `depth`: this script deliberately never sends one. Dev-Mode annotations
# and prototype `interactions[]` live on DEEP descendant nodes — a depth-limited
# fetch cannot see them and returns a structurally guaranteed false zero. Use depth
# only for the separate frame-inventory pass, never for the annotation pass.
status=$(curl -sS -w '%{http_code}' -o "$raw" \
  -H "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com$path" 2>/dev/null) || {
  echo "figma-probe: request failed (transport error) for $path" >&2
  exit 3
}

bytes=$(wc -c <"$raw" 2>/dev/null | tr -d ' ')
[ -n "$bytes" ] || bytes=0

# Record this fetch as VERIFIED evidence. The PostToolUse recorder sees this run only as
# a Bash command, and a URL inside a command string is not proof of a fetch — so it logs
# `mentioned`, which the census check does not accept. Here we have an actual HTTP status
# in hand, so the probe vouches for itself. Recorded whatever the status: an observed 403
# is exactly the evidence §0.3 demands before calling a source inaccessible.
_ev="${CLAUDE_PROJECT_DIR:-.}/.claude/sources/.evidence-log"
if [ -d "$(dirname "$_ev")" ]; then
  printf '%s\tfigma-probe\thttps://api.figma.com%s\tverified\n' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo unknown)" "$path" \
    >>"$_ev" 2>/dev/null || true
fi

if [ "$status" != "200" ]; then
  echo "RECEIPT probe=GET:$path status=$status bytes=$bytes raw=$raw scanned=0"
  echo "figma-probe: HTTP $status — this is a FAILED READ, not a zero (DoD 0.2). Body saved at $raw" >&2
  exit 3
fi

if [ "$bytes" -eq 0 ]; then
  echo "RECEIPT probe=GET:$path status=$status bytes=0 raw=$raw scanned=0"
  echo "figma-probe: empty body — FAILED READ, not a zero (DoD 0.2)." >&2
  exit 3
fi

scanned=0
if [ "$have_jq" -eq 1 ]; then
  scanned=$(jq '[.. | objects | select(has("id") and has("type"))] | length' "$raw" 2>/dev/null || echo 0)
fi
: "${scanned:=0}"

echo "RECEIPT probe=GET:$path status=$status bytes=$bytes raw=$raw scanned=$scanned"

if [ "$mode" = "comments" ]; then
  if [ "$have_jq" -eq 1 ]; then
    comments=$(jq '(.comments // []) | length' "$raw" 2>/dev/null || echo 0)
    echo "COUNT comments=${comments:-0} corroboration=parsed-from-raw"
  else
    echo "COUNT comments=unknown corroboration=jq-unavailable-read-$raw-by-hand"
  fi
  exit 0
fi

analyse_annotations "$raw"
exit $?
