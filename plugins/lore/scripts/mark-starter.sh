#!/bin/sh
# mark-starter.sh — record docs/intro.md as the setup commands' starter page.
#
# WHY THIS EXISTS. /lore:init rewrites the sample home page in the documentation
# language, and /lore:config rewrites it from the product description. Both are edits
# under docs/, so record-evidence.sh marks the session as having produced documentation
# and the Stop gate demands a census and a validator run — for a page no source was read
# for. A freshly scaffolded project then could not finish its own setup without a
# documentation run's ceremony.
#
# WHAT IT RECORDS. The sha-256 of the page's CURRENT content, so the exemption is scoped
# by digest exactly like the validation waiver: verify-docs.sh treats the page as starter
# content only while it is byte-for-byte what was marked here. Any later edit — by hand,
# by a skill, by the reviser — changes the digest, and the page is documentation again.
#
# WHY ONLY docs/intro.md. The path is fixed, not an argument: this is the one page the
# setup commands write, and a script that could mark any page would be a way to take
# real documentation out of the gate.
#
# Usage:
#   mark-starter.sh            # project root = $CLAUDE_PROJECT_DIR, else .
#
# Prints one receipt line, e.g.:
#   RECEIPT mark-starter path=docs/intro.md sha256=<64 hex>
#
# Exit codes: 0 ok (INCLUDING "no digest tool" — the page then stays gated, which is the
#             safe direction); 1 no docs/intro.md, or not a Lore project
#
# Manifest: .claude/sources/.starter-baseline  (TAB: sha-256, path)

set -u

case "${1:-}" in
  -h|--help) sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 1 ;;
esac

root="${CLAUDE_PROJECT_DIR:-.}"
page="docs/intro.md"

_lib="$(dirname "$0")/../hooks/lib/common.sh"
# shellcheck disable=SC2034  # read by json_field() in lib/common.sh, per its contract
input=""
# shellcheck source=../hooks/lib/common.sh
. "$_lib" || { echo "mark-starter: missing $_lib" >&2; exit 1; }

lore_is_project "$root" || { echo "mark-starter: $root is not a Lore project" >&2; exit 1; }
[ -f "$root/$page" ] || { echo "mark-starter: no $page under $root" >&2; exit 1; }

sha=$(lore_sha256 "$root/$page")
if [ -z "$sha" ]; then
  echo "RECEIPT mark-starter path=$page sha256=none (no digest tool — the page stays gated)"
  exit 0
fi

lore_ensure_sources_dir "$root" || exit 1
manifest="$root/.claude/sources/.starter-baseline"
tab=$(printf '\t')
# One line per path: drop any earlier mark of this page, then record the current one.
{
  [ -f "$manifest" ] && grep -v "${tab}${page}\$" "$manifest" 2>/dev/null
  printf '%s\t%s\n' "$sha" "$page"
} >"$manifest.tmp" && mv "$manifest.tmp" "$manifest"

echo "RECEIPT mark-starter path=$page sha256=$sha"
