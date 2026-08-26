# shellcheck shell=sh
# lib/common.sh — the prologue every Lore hook shares. SOURCED, never executed.
#
# WHY THIS EXISTS. The same ~35 lines (a jq→python3→sed extraction ladder, project-root
# resolution, the Lore-marker guard, the carve-out) were copy-pasted into seven of the
# nine hooks — roughly a third of the whole hook layer. That is not just noise: the
# greedy-`sed` bug below lived in all seven copies at once, so a single defect needed
# seven identical fixes and any one of them could be missed.
#
# SOURCING CONVENTION — always `. "$(dirname "$0")/lib/common.sh"`, never
# `${CLAUDE_PLUGIN_ROOT}`. hooks.json interpolates that variable into the *command
# string*; nothing guarantees it is also exported into the hook's environment, so a hook
# that resolved its own library through it would break in exactly the situation where it
# is hardest to notice. `$0` is always the real path to the running hook.
#
# CONTRACT
#   $input                      must already hold the raw payload (caller does `input=$(cat)`)
#   json_field <key path>       → the value at that path, or empty
#   lore_root <payload cwd>     → project root, no trailing slash
#   lore_is_project <root>      → 0 when the root is a scaffolded Lore docs project
#   lore_rel <file path> <root> → the project-relative path
#   lore_carved_out <rel>       → 0 for intentional example trees
#   lore_env_marker_ok          → cheap pre-parse bail; use as `lore_env_marker_ok || exit 0`
#   $_json_tool                 → "jq" | "python3" | "" (empty = degraded, warn loudly)
#   lore_sha256 <file>          → 64-hex sha-256 of the file's content, or nothing
#   $_sha_tool                  → "sha256sum" | "shasum" | "openssl" | "" (empty = callers
#                                 degrade to their pre-digest behaviour, never crash)
#   lore_ensure_sources_dir <root>   → creates .claude/sources + its .gitignore; 1 on failure
#   lore_live_lines <file>           → every non-fenced line (a quoted example is not a claim)
#   lore_append_evidence <root> <tool> <detail> <tier> [agent] [sha]
#                               → appends ONE sanitised line to .claude/sources/.evidence-log
#
# shellcheck disable=SC2154   # $input is the caller's, by contract (see above)

# --- pick a JSON extraction backend once (jq → python3 → sed last resort) ---
_json_tool=""
if command -v jq >/dev/null 2>&1; then
  _json_tool="jq"
elif command -v python3 >/dev/null 2>&1; then
  _json_tool="python3"
fi

# json_field <space-separated key path>    e.g. json_field 'tool_input file_path'
#
# ONE argument, deliberately. This used to take three — a jq filter, a python key path
# and a bare sed key — which meant every call site restated the same path in three
# dialects and could get them out of step. The path is now written once and each backend
# derives its own form from it.
json_field() {
  case "$_json_tool" in
    jq)
      _jq=""
      for _k in $1; do _jq="$_jq.$_k"; done
      printf '%s' "$input" | jq -r "$_jq // empty" 2>/dev/null
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
if isinstance(cur, bool):
    print("true" if cur else "false")
elif isinstance(cur, str):
    print(cur)
elif isinstance(cur, (int, float)):
    print(cur)
' $1
      ;;
    *)
      _json_sed_field "$1"
      ;;
  esac
}

# Last-resort text scan, used only when neither jq nor python3 exists. Two properties
# matter here and both were wrong in every copy of the old version:
#
#   1. It must honour the PATH, not just the leaf name. A Write payload carries
#      tool_input.file_path *and* a tool_response echoing a path, and `s/.*"file_path".../`
#      is greedy — so it returned the LAST occurrence in the payload, i.e. the wrong file,
#      and the `head -n 1` that followed was decoration. Anchoring to the parent key first
#      and then taking the FIRST match fixes both halves.
#   2. It must read unquoted scalars. `stop_hook_active` is a JSON boolean; a string-only
#      scan returns empty for it, which would silently disable the Stop hook's loop guard
#      on a machine with no JSON parser — the one failure mode that can trap a user.
_json_sed_field() { # $1 = space-separated key path
  _rest=$input
  _leaf=""
  for _k in $1; do
    if [ -n "$_leaf" ]; then
      _pat="*\"$_leaf\""
      _rest=${_rest#$_pat}
    fi
    _leaf="$_k"
  done

  _v=$(printf '%s' "$_rest" |
    grep -o "\"$_leaf\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" 2>/dev/null | head -n 1)
  if [ -n "$_v" ]; then
    printf '%s' "$_v" | sed "s/^\"$_leaf\"[[:space:]]*:[[:space:]]*\"//; s/\"\$//"
    return 0
  fi

  printf '%s' "$_rest" |
    grep -o "\"$_leaf\"[[:space:]]*:[[:space:]]*[^,}\"[:space:]]*" 2>/dev/null |
    head -n 1 | sed "s/^\"$_leaf\"[[:space:]]*:[[:space:]]*//"
}

# --- pick a digest backend once (sha256sum → shasum → openssl) ---
# macOS ships `shasum -a 256`, most Linuxes `sha256sum`; openssl is the long tail.
_sha_tool=""
if command -v sha256sum >/dev/null 2>&1; then
  _sha_tool="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
  _sha_tool="shasum"
elif command -v openssl >/dev/null 2>&1; then
  _sha_tool="openssl"
fi

# lore_sha256 <file> — 64-hex digest on stdout, or nothing on any failure.
# The file is fed via STDIN, not as an argument: GNU coreutils prefixes the output line
# with `\` when the filename needs escaping, and the stdin form makes all three
# backends' output shapes uniform (digest first, no filename column to strip).
lore_sha256() {
  case "$_sha_tool" in
    sha256sum) sha256sum <"$1" 2>/dev/null | awk '{print $1}' ;;
    shasum)    shasum -a 256 <"$1" 2>/dev/null | awk '{print $1}' ;;
    openssl)   openssl dgst -sha256 <"$1" 2>/dev/null | awk '{print $NF}' ;;
  esac
}

# lore_root <payload cwd> — CLAUDE_PROJECT_DIR wins; trailing slash stripped so every
# "$root/..." concatenation below is stable.
lore_root() {
  _r="${CLAUDE_PROJECT_DIR:-$1}"
  printf '%s' "${_r%/}"
}

# lore_is_project <root>
#
# These rules are Lore's Definition of Done, not universal truth. The plugin is installed
# per user, so every hook also runs in repos that have nothing to do with documentation —
# and plenty of projects keep plain markdown and images under docs/. Blocking those writes
# enforced a DoD their author never opted into. The marker is a .claude/CLAUDE.md that
# imports the methodology file, i.e. a project that was actually scaffolded by Lore.
lore_is_project() {
  [ -n "$1" ] || return 1
  [ -f "$1/.claude/CLAUDE.md" ] || return 1
  grep -q '@lore-methodology.md' "$1/.claude/CLAUDE.md" 2>/dev/null
}

# lore_env_marker_ok — the pre-parse fast path, for hooks on high-frequency matchers.
# Returns 1 only when we can already prove this is not a Lore project; "unknown" returns
# 0 so the caller carries on and decides after parsing. Use as: lore_env_marker_ok || exit 0
lore_env_marker_ok() {
  [ -n "${CLAUDE_PROJECT_DIR:-}" ] || return 0
  lore_is_project "${CLAUDE_PROJECT_DIR%/}"
}

# lore_rel <file path> <root> — an absolute path that does not live under root keeps its
# leading '/', so the docs/ tests in every caller simply do not match and the hook exits 0.
lore_rel() {
  case "$1" in
    /*) if [ -n "$2" ]; then printf '%s' "${1#"$2"/}"; else printf '%s' "$1"; fi ;;
    *)  printf '%s' "$1" ;;
  esac
}

# lore_carved_out <rel> — intentional example/placeholder trees are never checked.
# check-census.sh is the single deliberate exception: its whole subject lives in .claude/.
lore_carved_out() {
  case "$1" in
    .claude/*|templates/*|_templates/*) return 0 ;;
  esac
  return 1
}

# lore_ensure_sources_dir <root> — create the evidence dir and keep its run artifacts
# out of git; the census itself stays committed. Used to be private to
# record-evidence.sh; figma-probe.sh and every later recorder need the same thing.
lore_ensure_sources_dir() {
  mkdir -p "$1/.claude/sources" 2>/dev/null || return 1
  _gi="$1/.claude/sources/.gitignore"
  if [ -f "$_gi" ]; then
    # A project scaffolded before the waiver/history artifacts existed has a .gitignore
    # without them — append the missing entries once, then leave the file alone.
    if ! grep -qF '.validation-waiver' "$_gi" 2>/dev/null; then
      {
        echo ".validation-waiver"
        echo ".validator-history"
        echo ".image-optim"
      } >>"$_gi" 2>/dev/null || true
    fi
    grep -qF '.reviser-active' "$_gi" 2>/dev/null || echo ".reviser-active" >>"$_gi" 2>/dev/null || true
    return 0
  fi
  {
    echo "# Run artifacts backing the census receipts (DoD 0.1). Not committed."
    echo ".evidence-log"
    echo ".validator-receipt"
    echo ".validator-history"
    echo ".validation-waiver"
    echo ".docs-touched"
    echo ".image-optim"
    echo ".reviser-active"
    echo "raw/"
  } >"$_gi" 2>/dev/null || true
  return 0
}

# lore_live_lines <file> — every non-fenced line, so a row check never judges a quoted
# example. Shared by check-census.sh and check-citation-loss.sh.
lore_live_lines() {
  awk '/^```/ { fence = !fence; next } !fence { print }' "$1" 2>/dev/null
}

# lore_append_evidence <root> <tool> <detail> <tier> [agent] [sha]
#
# THE ONE WRITER of .claude/sources/.evidence-log. Three private copies of this printf
# used to exist (record-evidence.sh, figma-probe.sh, …) and each had to remember the
# same sanitisation. Line shape, TAB-separated:
#
#   iso8601  tool  detail  tier  [agent]  [sha]
#
# Fields 5–6 are optional and only written when a caller has them: `agent` is the
# subagent id the runtime put on the hook payload (who fetched), `sha` the sha-256 of
# the raw payload saved on disk (what was fetched). Every reader uses `NF >= 4`, so a
# 4-, 5- or 6-field line is read the same way; a 3-field line predates tiering.
#
# Sanitisation is here, not at the call sites: only the FIRST line of `detail` is kept
# (an embedded newline once appended a second, forged entry), and every control
# character is stripped from every field (an embedded tab forged the tier column).
lore_append_evidence() {
  _root=$1
  _d=$(printf '%s' "$3" | head -n 1 | tr -d '\000-\037')
  [ -n "$_d" ] || return 0
  _t=$(printf '%s' "$2" | tr -d '\000-\037')
  _tier=$(printf '%s' "$4" | tr -d '\000-\037')
  _a=$(printf '%s' "${5:-}" | tr -d '\000-\037')
  _s=$(printf '%s' "${6:-}" | tr -d '\000-\037')
  _ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo 'unknown')
  _line=$(printf '%s\t%s\t%s\t%s' "$_ts" "$_t" "$_d" "$_tier")
  if [ -n "$_s" ]; then
    _line=$(printf '%s\t%s\t%s' "$_line" "$_a" "$_s")
  elif [ -n "$_a" ]; then
    _line=$(printf '%s\t%s' "$_line" "$_a")
  fi
  printf '%s\n' "$_line" >>"$_root/.claude/sources/.evidence-log" 2>/dev/null || true
}

true
