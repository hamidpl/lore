#!/bin/sh
# check-citation-loss.sh — PreToolUse hook (matcher: Edit|Write), BLOCKING (exit 2)
#
# WHY THIS EXISTS. Of every damage class an iterative fix loop causes, one survived
# every prompt-level mitigation measured in the literature: citations vanish during
# revision (faithfulness fell by up to two-thirds in multi-turn report revision, and a
# dedicated reviser did not restore it). In Lore a citation is a claim's receipt (§0.1),
# and the evidence log that backs it is hook-written — which makes "this edit removes a
# citation whose fetch actually happened" a deterministic question, not a judgement.
# So it is answered here, before the edit lands, rather than discovered a validation
# round later.
#
# WHAT IT CHECKS. For an Edit or Write on a docs/ markdown/MDX file: every http(s) URL
# that is present in the file today and absent after the edit. If that URL's HOST has a
# `verified` entry in .claude/sources/.evidence-log, the edit is denied. A URL the log
# only ever saw as `mentioned` (or never saw) is not a receipt, and removing it is not
# gated here. The message tells the model what to do instead: move the citation, or
# report the removal to the user — a fix is a new claim (§0.1), not a free move.
#
# An Edit is judged against the whole file, not just old_string: the URL survives if it
# still occurs elsewhere in the file (a citation moved between sections is not lost).
# With `replace_all` every occurrence inside old_string goes, so the count is scaled.
#
# Guard: acts only in a scaffolded Lore project (see lib/common.sh) and only on
# docs/**/*.md|mdx; intentional example trees are carved out. Never blocks a repo with
# no evidence log — nothing there can be "backed by a verified fetch".

input=$(cat 2>/dev/null || true)

_lib="$(dirname "$0")/lib/common.sh"
[ -r "$_lib" ] || exit 0
# shellcheck source=lib/common.sh
. "$_lib"

lore_env_marker_ok || exit 0
case "$input" in
  *docs/*) : ;;
  *) exit 0 ;;
esac

tool=$(json_field 'tool_name')
fp=$(json_field 'tool_input file_path')
cwd=$(json_field 'cwd')
[ -n "$fp" ] || exit 0

root=$(lore_root "$cwd")
lore_is_project "$root" || exit 0

rel=$(lore_rel "$fp" "$root")
case "$rel" in
  docs/*.md|docs/*.mdx) : ;;
  *) exit 0 ;;
esac
lore_carved_out "$rel" && exit 0

file="$root/$rel"
log="$root/.claude/sources/.evidence-log"
[ -s "$log" ] || exit 0
[ -f "$file" ] || exit 0   # a new file removes nothing

urls() { grep -oE 'https?://[A-Za-z0-9._~:/?#@!$&*+,;=%-]+' 2>/dev/null | sed 's/[.,)]*$//' | sort -u; }
count_in() { # $1 needle, stdin haystack
  grep -oF -- "$1" 2>/dev/null | wc -l | tr -d ' '
}

case "$tool" in
  Edit)
    old=$(json_field 'tool_input old_string')
    new=$(json_field 'tool_input new_string')
    all=$(json_field 'tool_input replace_all')
    [ -n "$old" ] || exit 0
    candidates=$(printf '%s' "$old" | urls)
    ;;
  Write)
    new=$(json_field 'tool_input content')
    candidates=$(lore_live_lines "$file" | urls)
    ;;
  *) exit 0 ;;
esac
[ -n "$candidates" ] || exit 0

lost=""
for u in $candidates; do
  # Still present after the edit?
  case "$tool" in
    Edit)
      in_file=$(printf '%s' "$(cat "$file")" | count_in "$u")
      in_old=$(printf '%s' "$old" | count_in "$u")
      in_new=$(printf '%s' "$new" | count_in "$u")
      if [ "$all" = "true" ]; then
        # every occurrence of old_string is replaced: what survives is in_new copies
        # per replaced occurrence, plus any occurrences not inside old_string at all
        occ=$(printf '%s' "$(cat "$file")" | count_in "$old")
        [ "$occ" -gt 0 ] || occ=1
        remaining=$(( in_file - in_old * occ + in_new * occ ))
      else
        remaining=$(( in_file - in_old + in_new ))
      fi
      ;;
    Write)
      remaining=$(printf '%s' "$new" | count_in "$u")
      ;;
  esac
  [ "$remaining" -le 0 ] || continue

  host=$(printf '%s' "$u" | sed -E 's#^https?://([^/]+).*#\1#')
  if awk -F'\t' -v h="$host" '
       { tier = (NF >= 4 ? $4 : "verified") }
       tier == "verified" && index($3, h) { found = 1 }
       END { exit(found ? 0 : 1) }
     ' "$log" 2>/dev/null; then
    lost="$lost
  - $u"
  fi
done

[ -n "$lost" ] || exit 0

cat >&2 <<EOF
BLOCKED (§0.1): this edit to $rel removes a citation backed by a verified fetch:$lost
A citation is the receipt for the claim it sits on, and the fetch behind it is in the evidence log. A fix is a new claim, not a free move: keep the citation (move it, do not drop it), or report the removal and its reason to the user before editing. If the claim itself is being removed, remove it as one visible change the user has seen, not as a side effect of another fix.
EOF
exit 2
