#!/bin/sh
# Stop hook — integrity checks before a turn ends.
#
# Output checks 1 and 2 (image files under docs/, /static/img/ references, and
# markdown-embedded /mobile/ shots) are BLOCKING (exit 2): on Stop this prevents
# Claude from stopping and feeds stderr back so it fixes the violation.
#
# Process gates 3 and 4 are also BLOCKING, and are the reason a skipped step can no
# longer reach delivery: an unsatisfied run-contract row (DoD §0.4) or documentation
# that changed without a fresh, green lore:doc-validator run.
#
# SCOPE — read this before changing it. Both gates fire only when .claude/sources/
# exists AND this session actually produced documentation. "Produced documentation"
# means the session id appears in .claude/sources/.docs-touched, which record-evidence.sh
# writes on a docs/ write. That file is git-ignored, so a freshly cloned project has a
# committed census and no marker: absence of the marker therefore means "no session here
# has produced docs yet", NOT "unknown, so block". Reading it the other way blocked every
# session in every clone of a Lore repo, including ones that touched nothing.
#
# Check 5 (orphan images) stays a non-fatal WARNING — it is heuristic and a full
# `npm run build` is the authoritative check (run it in CI).
#
# Loop guard: when this Stop is itself the result of a previous Stop-hook block
# (stop_hook_active = true), exit 0 immediately so an unfixable violation cannot
# loop forever.

input=$(cat)

# --- detect the loop-guard flag (jq → python3 → grep) ---
stop_active=""
if command -v jq >/dev/null 2>&1; then
  stop_active=$(printf '%s' "$input" | jq -r '.stop_hook_active // empty' 2>/dev/null)
elif command -v python3 >/dev/null 2>&1; then
  stop_active=$(printf '%s' "$input" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("stop_hook_active",""))
except Exception: pass' 2>/dev/null)
else
  printf '%s' "$input" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && stop_active="true"
fi
[ "$stop_active" = "true" ] && exit 0

# --- which session is stopping (scopes the process gates below) ---
session_id=""
if command -v jq >/dev/null 2>&1; then
  session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
elif command -v python3 >/dev/null 2>&1; then
  session_id=$(printf '%s' "$input" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("session_id",""))
except Exception: pass' 2>/dev/null)
else
  session_id=$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
fi

# --- run all checks from the project root ---
root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$root" ]; then
  if command -v jq >/dev/null 2>&1; then
    root=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  elif command -v python3 >/dev/null 2>&1; then
    root=$(printf '%s' "$input" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("cwd",""))
except Exception: pass' 2>/dev/null)
  fi
fi
[ -n "$root" ] && cd "$root" 2>/dev/null || true

# Nothing to check without a docs/ tree.
[ -d docs ] || exit 0

# --- guard: a scaffolded Lore docs project only -------------------------------------
# The output checks below are Lore's Definition of Done, not universal truth, and this
# hook runs in whatever repo the session is in. Plenty of projects keep an image under
# docs/ — which used to block every turn there, for a rule their author never adopted.
# Same marker every evidence hook uses.
[ -f .claude/CLAUDE.md ] || exit 0
grep -q '@lore-methodology.md' .claude/CLAUDE.md 2>/dev/null || exit 0

blocked=0

# 1) No image files committed under docs/ (BLOCKING) — extension set matches the
#    write-time hook (check-image-path.sh Rule A).
bad_imgs=$(find docs -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \
  -o -name '*.gif' -o -name '*.webp' -o -name '*.svg' -o -name '*.ico' \) 2>/dev/null)
if [ -n "$bad_imgs" ]; then
  echo "BLOCKED: image files found under docs/ (must live in static/img/):" >&2
  echo "$bad_imgs" >&2
  blocked=1
fi

# 2) No markdown/MDX image refs using /static/img/ (BLOCKING)
bad_refs=$(grep -rnE '\]\(/static/img/|src="/static/img/' docs/ 2>/dev/null)
if [ -n "$bad_refs" ]; then
  echo "BLOCKED: docs reference images via /static/img/ (use /img/):" >&2
  echo "$bad_refs" >&2
  blocked=1
fi

# 2b) Mobile-view screenshots must use the raw <img> embed, not markdown syntax
#     (BLOCKING) — matches the write-time hook (check-image-path.sh Rule C):
#     markdown-embedded images lose the /mobile/ path at build time, so the
#     half-width mobile styling never applies (CLAUDE.md Section 6).
bad_mobile=$(grep -rnE '!\[[^]]*\]\([^)]*/mobile/' docs/ 2>/dev/null)
if [ -n "$bad_mobile" ]; then
  echo 'BLOCKED: /mobile/ screenshots embedded with markdown syntax (use a raw <img src="..." alt="..." /> tag so the /mobile/ path survives the build):' >&2
  echo "$bad_mobile" >&2
  blocked=1
fi

# --- Process gates (DoD §0.4 + Auto-Validation) -----------------------------------
# These only apply once a Lore producing run has left evidence behind: no
# .claude/sources/ means this is not a Lore-authored docs tree, and nothing below
# should ever fire. That keeps hand-maintained repos completely untouched.
if [ -d .claude/sources ]; then

  # Did THIS session produce documentation? Only then do the gates apply. Without
  # this scoping, anything that touches docs/ outside Claude — a `git pull`, a
  # rebase, an editor save — would block the next turn of an unrelated session,
  # punishing someone who did nothing wrong. And a missing marker file means no
  # session has produced docs here at all (the marker is git-ignored, so every
  # fresh clone starts without one), which must skip, never block.
  produced=0
  if [ -f .claude/sources/.docs-touched ]; then
    if [ -z "$session_id" ] ||
       grep -qxF "$session_id" .claude/sources/.docs-touched 2>/dev/null; then
      # Session id present in the marker, or unparseable — gate conservatively.
      produced=1
    fi
  fi

  if [ "$produced" -eq 1 ]; then

  # 3a) A session that produced documentation must have produced a census (§0).
  #     Everything else in the evidence layer — receipts, zeros, the run contract, the
  #     §1 coverage block, the Figma manifest — is reachable only THROUGH this file:
  #     check-census.sh fires on a census write, so a run that never writes one skips
  #     every §0 rule at once. Requiring the artifact is what makes the rest reachable.
  census_list=$(find .claude/sources -maxdepth 1 -name '*-census.md' 2>/dev/null)
  if [ -z "$census_list" ]; then
    echo "BLOCKED: this session wrote documentation but left no source census under .claude/sources/ (DoD §0). The census is the record of what was actually read — every §0 rule is checked against it, so a run without one has proved nothing. Write .claude/sources/{input}-{slug}-census.md with the Run contract, the receipted Trusted Sources (§1) coverage block, and this input type's source manifest." >&2
    blocked=1
  else
    # 3b) …and it must be COMPLETE. check-census.sh owns every census rule; at write
    #     time it validates shape (a pre-flight census is legitimately half-written),
    #     here it validates that the run actually covered what its manifest names.
    for c in $census_list; do
      complete_err=$("$(dirname "$0")/check-census.sh" --complete "$c" 2>&1) || {
        echo "$complete_err" >&2
        blocked=1
      }
    done
  fi

  # 3) Every explicit user instruction must be discharged (§0.4). A [u#] row that is
  #    still open at delivery is exactly how "also check the signed-in state" gets lost.
  #
  #    The status is read as a WHOLE FIELD, never as a substring: `grep -v satisfied`
  #    filtered out "not satisfied" and "unsatisfied" — the exact words §0.4's own
  #    wording ("not marked `satisfied`") primes the model to write — so the gate
  #    passed the very failure it was built to catch. Anything that is not literally
  #    `satisfied` or `waived` is open. §0.4 also requires satisfied rows to carry
  #    evidence, so an empty evidence column is an open row too.
  open_u=$(awk -F'|' '
    index($0, "`") { next }                       # a fenced/inline example, not a row
    /^\|[[:space:]]*[uU][0-9]+[[:space:]]*\|/ {
      st = $4; ev = $5
      gsub(/^[[:space:]]+/, "", st); gsub(/[[:space:]]+$/, "", st)
      gsub(/^[[:space:]]+/, "", ev); gsub(/[[:space:]]+$/, "", ev)
      lc = tolower(st)
      if (lc == "satisfied") {
        # No alphanumerics means no evidence: an empty cell, or any of the dashes
        # ("-", "--", "—", "–") a model reaches for when it has nothing to cite.
        if (ev !~ /[A-Za-z0-9]/) {
          printf "%s: %s\n      ^ status is satisfied but the evidence column is empty\n", FILENAME, $0
        }
        next
      }
      if (lc ~ /^waived([[:space:]]*\(.*\))?$/) next
      printf "%s: %s\n      ^ status %s is not satisfied/waived\n", FILENAME, $0, (st == "" ? "(empty)" : "\"" st "\"")
    }
  ' .claude/sources/*-census.md 2>/dev/null || true)
  if [ -n "$open_u" ]; then
    echo "BLOCKED: run-contract rows are still open (DoD §0.4). Every explicit instruction the user gave must end the run as 'satisfied' WITH evidence in the last column, or 'waived (user approved)'. Those are the only two accepted values — 'not satisfied', 'pending', 'partial' and an empty status all count as open:" >&2
    echo "$open_u" >&2
    blocked=1
  fi

  # 4) Documentation changed but no fresh, green validator run (Auto-Validation).
  #    The receipt is written by the SubagentStop hook from the subagent's own
  #    verdict — so it is not something the model produces in the ordinary course of
  #    writing documentation. It is a plain file, and an agent with shell access can
  #    write one; the gate is here to stop a step from being skipped by accident, not
  #    to withstand a deliberate forgery (see DoD §0 and the plugin's threat model).
  receipt=.claude/sources/.validator-receipt
  if [ ! -f "$receipt" ]; then
    echo "BLOCKED: documentation exists under docs/ but lore:doc-validator has never run in this project. Run it (Task tool) and fix anything it reports before delivering." >&2
    blocked=1
  elif changed=$(find docs -type f \( -name '*.md' -o -name '*.mdx' \) \
        -newer "$receipt" 2>/dev/null | head -n 5) && [ -n "$changed" ]; then
    echo "BLOCKED: these docs changed after the last lore:doc-validator run — re-run it before delivering:" >&2
    echo "$changed" >&2
    blocked=1
  else
    verdict=$(cut -f2 "$receipt" 2>/dev/null)
    case "$verdict" in
      "APPROVED"|"APPROVED WITH WARNINGS") : ;;
      *)
        echo "BLOCKED: the last lore:doc-validator run returned '${verdict:-UNKNOWN}'. Fix the reported failures and re-run until it returns APPROVED." >&2
        blocked=1
        ;;
    esac
  fi

  fi
fi

[ "$blocked" -eq 1 ] && exit 2

# 5) Orphan images (WARNING only): files in static/img/ referenced by no doc,
#    config, or source file. References come from docs/ (as /img/...) and from
#    site config/source (as img/...). Both forms are matched as the substring
#    "img/<relative path>". Handles paths with spaces (no word-splitting) and
#    both .ts and .js config variants.
if [ -d static/img ]; then
  haystack=$(
    find docs -type f \( -name '*.md' -o -name '*.mdx' \) -exec cat {} + 2>/dev/null
    [ -d src ] && find src -type f -exec cat {} + 2>/dev/null
    for cfg in docusaurus.config.ts docusaurus.config.js sidebars.ts sidebars.js; do
      [ -f "$cfg" ] && cat "$cfg"
    done
  )
  find static/img -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \
    -o -name '*.gif' -o -name '*.webp' -o -name '*.svg' -o -name '*.ico' \) 2>/dev/null |
  while IFS= read -r f; do
    rel="img/${f#static/img/}"
    printf '%s' "$haystack" | grep -qF "$rel" || echo "WARNING: orphan image not referenced anywhere: $f" >&2
  done
fi

exit 0
