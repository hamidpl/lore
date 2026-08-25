#!/bin/sh
# remind-mass-edit.sh — PreToolUse hook (matcher: Edit|Bash). NEVER BLOCKS.
#
# WHY THIS EXISTS. The worst cascade in a real run started the moment a green
# validation ended: one "trivial" tree-wide word replacement (154 hits in 19 files)
# landed inside quoted UI strings and silently falsified five fidelity-promise
# sentences and a table column — and every changed line looked correct in the diff,
# so three more validation rounds were spent finding it. No output check can see this
# class of damage, because nothing is mis-typed; the only useful moment is BEFORE the
# operation runs.
#
# Deliberately advisory, like remind-census.sh: a hook cannot judge whether a given
# bulk edit is risky (that is exactly the judgement the incident got wrong), so it
# injects the incident-derived checklist as additionalContext and exits 0. The real
# gate is verify-docs.sh at Stop, which sees the changed digests.
#
# Triggers: an Edit with replace_all on a docs/ page, or a Bash command running an
# in-place stream edit (sed -i / perl -pi) that names docs/.

# shellcheck disable=SC2034  # read by json_field() in lib/common.sh, per its contract
input=$(cat 2>/dev/null || true)

_lib="$(dirname "$0")/lib/common.sh"
[ -r "$_lib" ] || exit 0
# shellcheck source=lib/common.sh
. "$_lib"

# FAST PATH: this hook sits on Edit|Bash, the highest-frequency matchers there are.
# A payload that names no docs/ path cannot be a bulk docs edit; drop it before
# spawning any JSON parser.
case "$input" in
  *docs/*) : ;;
  *) exit 0 ;;
esac
lore_env_marker_ok || exit 0

tool=$(json_field 'tool_name')
cwd=$(json_field 'cwd')
root=$(lore_root "$cwd")

mass=0
case "$tool" in
  Edit)
    fp=$(json_field 'tool_input file_path')
    rel=$(lore_rel "$fp" "$root")
    case "$rel" in
      docs/*.md|docs/*.mdx)
        [ "$(json_field 'tool_input replace_all')" = "true" ] && mass=1
        ;;
    esac
    ;;
  Bash)
    cmd=$(json_field 'tool_input command')
    if printf '%s' "$cmd" | grep -q 'docs/' &&
       printf '%s' "$cmd" | grep -qE '(^|[;&| ])sed[[:space:]]+(-[A-Za-z]*i|--in-place)|(^|[;&| ])perl[[:space:]]+-[A-Za-z]*i'; then
      mass=1
    fi
    ;;
  *) exit 0 ;;
esac
[ "$mass" -eq 1 ] || exit 0

lore_is_project "$root" || exit 0

msg="You are about to run a bulk identical edit across docs/ (mass replacement). In a real run this exact class of edit — a 'trivial spelling fix' applied tree-wide — landed inside quoted verbatim UI strings and silently falsified 21 pages, while every changed line looked correct in the diff. Before running it, and again right after: (1) grep the affected pages for fidelity-promise wording ('verbatim', 'exact', 'authoritative', 'exactly as shown in the product') — a replacement inside a quoted UI string breaks the promise the surrounding sentence makes; (2) grep for text whose SUBJECT is the replaced word itself (spelling notes, glossaries, search-hint text) — the failure signature is a sentence comparing X to X; (3) check for table columns or list items that become byte-identical after the replacement; (4) remember Unicode look-alikes and presentation forms the replacement will not match; (5) if the edit changes a claim about product behavior, that claim needs a receipt like any other (DoD §0.1) — and a fix is a new claim, not a free move. A green validator verdict earlier in this session does not cover this edit: per the Auto-Validation Rule it is a new claim, to be reported to the user before any re-validation round."

if command -v jq >/dev/null 2>&1; then
  jq -n --arg m "$msg" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse", additionalContext:$m}}'
elif command -v python3 >/dev/null 2>&1; then
  MSG="$msg" python3 -c 'import json,os;print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":os.environ["MSG"]}}))'
else
  echo "$msg" >&2
fi

exit 0
