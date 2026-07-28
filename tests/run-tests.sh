#!/bin/sh
# Lore test harness — POSIX sh, no external test framework.
# Feeds canned hook payloads to the hook scripts and asserts exit codes/stderr,
# and exercises detect-project.sh / scaffold.sh against temp directories.
#
# Usage: sh tests/run-tests.sh   (exits non-zero if any assertion fails)
set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
HOOKS="$SCRIPT_DIR/../plugins/lore/hooks"
SCRIPTS="$SCRIPT_DIR/../plugins/lore/scripts"

PASS=0
FAIL=0
ERRF=$(mktemp)
RC=0

pass() { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
fail() {
  FAIL=$((FAIL + 1))
  printf '  FAIL %s\n' "$1"
  [ -s "$ERRF" ] && sed 's/^/         stderr: /' "$ERRF"
}
check_exit() { # expected actual name
  if [ "$1" = "$2" ]; then pass "$3 (exit $2)"; else fail "$3 (expected $1, got $2)"; fi
}
check_stderr() { # pattern name
  if grep -q "$1" "$ERRF" 2>/dev/null; then pass "$2"; else fail "$2 (stderr missing /$1/)"; fi
}

# Run a PostToolUse hook: $1 hook, $2 project root, $3 absolute file_path
posttool() {
  printf '{"cwd":"%s","tool_name":"Write","tool_input":{"file_path":"%s"}}' "$2" "$3" |
    CLAUDE_PROJECT_DIR="$2" sh "$1" 2>"$ERRF"
  RC=$?
}
# Run the Stop hook: $1 project root, $2 stop_hook_active (true|false)
stophook() {
  printf '{"hook_event_name":"Stop","stop_hook_active":%s,"cwd":"%s","session_id":"%s"}' \
    "$2" "$1" "${3:-}" |
    CLAUDE_PROJECT_DIR="$1" sh "$HOOKS/verify-docs.sh" 2>"$ERRF"
  RC=$?
}
# Run a PreToolUse hook: $1 hook, $2 project root, $3 absolute file_path. Captures stdout.
pretool() {
  OUT=$(printf '{"hook_event_name":"PreToolUse","cwd":"%s","tool_name":"Write","tool_input":{"file_path":"%s"}}' "$2" "$3" |
    CLAUDE_PROJECT_DIR="$2" sh "$1" 2>"$ERRF")
  RC=$?
}
# Run a PostToolUse hook with an arbitrary tool: $1 hook, $2 root, $3 tool, $4 inner JSON
posttool_tool() {
  printf '{"cwd":"%s","tool_name":"%s","tool_input":%s}' "$2" "$3" "$4" |
    CLAUDE_PROJECT_DIR="$2" sh "$1" 2>"$ERRF"
  RC=$?
}
# Run the SubagentStop hook: $1 project root, $2 last_assistant_message
subagentstop() {
  printf '{"hook_event_name":"SubagentStop","cwd":"%s","last_assistant_message":"%s"}' "$1" "$2" |
    CLAUDE_PROJECT_DIR="$1" sh "$HOOKS/record-validator-run.sh" 2>"$ERRF"
  RC=$?
}
# Mark a directory as a scaffolded Lore project (the guard every evidence hook uses)
make_lore_project() {
  mkdir -p "$1/.claude"
  printf 'x\n@lore-methodology.md\n' >"$1/.claude/CLAUDE.md"
}
check_file_has() { # file pattern name
  if grep -q "$2" "$1" 2>/dev/null; then pass "$3"; else fail "$3 ($1 missing /$2/)"; fi
}

fm_good='---
sidebar_position: 1
title: T
description: D
tags: [a, b]
---

Body
'

echo "== check-frontmatter.sh =="
P=$(mktemp -d)
mkdir -p "$P/docs" "$P/.claude" "$P/templates/docs-layer/docs"
# The output hooks enforce Lore's DoD, so they act only in a scaffolded Lore project —
# otherwise installing the plugin would impose that DoD on every unrelated repo that
# happens to keep markdown or images under docs/.
make_lore_project "$P"

printf '%s' "$fm_good" >"$P/docs/good.md"
posttool "$HOOKS/check-frontmatter.sh" "$P" "$P/docs/good.md"; check_exit 0 "$RC" "valid frontmatter passes"

printf 'no frontmatter here\n' >"$P/docs/nofm.md"
posttool "$HOOKS/check-frontmatter.sh" "$P" "$P/docs/nofm.md"; check_exit 2 "$RC" "missing frontmatter blocks"

printf -- '---\nsidebar_position: 1\ntitle: T\ndescription: D\n---\nx\n' >"$P/docs/partial.md"
posttool "$HOOKS/check-frontmatter.sh" "$P" "$P/docs/partial.md"; check_exit 2 "$RC" "missing one key blocks"
check_stderr "tags" "missing-key message names the key"

printf -- '---\r\nsidebar_position: 1\r\ntitle: T\r\ndescription: D\r\ntags: [a]\r\n---\r\nx\r\n' >"$P/docs/crlf.md"
posttool "$HOOKS/check-frontmatter.sh" "$P" "$P/docs/crlf.md"; check_exit 0 "$RC" "CRLF frontmatter passes"

printf -- '---\nsidebar_position: 1\ntitle: T\ndescription: D\ntags: [a]\nNeverClosed\n' >"$P/docs/unclosed.md"
posttool "$HOOKS/check-frontmatter.sh" "$P" "$P/docs/unclosed.md"; check_exit 2 "$RC" "unclosed fence blocks"
check_stderr "unclosed" "unclosed message is distinct"

# Use a file other than CLAUDE.md: that one is the Lore-project marker every hook
# guards on, and overwriting it here silently disabled the rest of the suite.
printf 'no frontmatter\n' >"$P/.claude/notes.md"
posttool "$HOOKS/check-frontmatter.sh" "$P" "$P/.claude/notes.md"; check_exit 0 "$RC" "carve-out: .claude/ ignored"

printf 'no frontmatter\n' >"$P/templates/docs-layer/docs/intro.md"
posttool "$HOOKS/check-frontmatter.sh" "$P" "$P/templates/docs-layer/docs/intro.md"; check_exit 0 "$RC" "carve-out: templates/ ignored"

printf 'no frontmatter\n' >"$P/docs/page.mdx"
posttool "$HOOKS/check-frontmatter.sh" "$P" "$P/docs/page.mdx"; check_exit 2 "$RC" ".mdx in scope blocks"

# Issue 1 regression: project root path itself contains a /docs/ segment.
PD=$(mktemp -d)/docs/proj
mkdir -p "$PD"
make_lore_project "$PD"
printf 'plain readme, no frontmatter\n' >"$PD/README.md"
posttool "$HOOKS/check-frontmatter.sh" "$PD" "$PD/README.md"; check_exit 0 "$RC" "root containing /docs/ does not false-block outside docs/"

echo "== check-image-path.sh =="
printf 'PNG\n' >"$P/docs/shot.png"
posttool "$HOOKS/check-image-path.sh" "$P" "$P/docs/shot.png"; check_exit 2 "$RC" "image under docs/ blocks"

printf -- '---\nx\n---\n![a](/static/img/s/a.png)\n' >"$P/docs/badref.mdx"
posttool "$HOOKS/check-image-path.sh" "$P" "$P/docs/badref.mdx"; check_exit 2 "$RC" ".mdx /static/img ref blocks"

printf '<img src="/static/img/s/a.png">\n' >"$P/docs/htmlref.md"
posttool "$HOOKS/check-image-path.sh" "$P" "$P/docs/htmlref.md"; check_exit 2 "$RC" "html src=/static/img blocks"

printf '![a](/img/s/a.png)\n' >"$P/docs/okref.md"
posttool "$HOOKS/check-image-path.sh" "$P" "$P/docs/okref.md"; check_exit 0 "$RC" "/img/ ref passes"

printf '![m](/img/s/mobile/a.png)\n' >"$P/docs/mdmobile.md"
posttool "$HOOKS/check-image-path.sh" "$P" "$P/docs/mdmobile.md"; check_exit 2 "$RC" "markdown /mobile/ ref blocks"
check_stderr "raw HTML" "mobile message suggests the raw <img> tag"

printf '<img src="/img/s/mobile/a.png" alt="m" />\n' >"$P/docs/htmlmobile.md"
posttool "$HOOKS/check-image-path.sh" "$P" "$P/docs/htmlmobile.md"; check_exit 0 "$RC" "raw <img> /mobile/ ref passes"

printf '![shown on mobile](/img/s/a.png)\n' >"$P/docs/mobilealt.md"
posttool "$HOOKS/check-image-path.sh" "$P" "$P/docs/mobilealt.md"; check_exit 0 "$RC" "'mobile' in alt text only is not a false positive"

mkdir -p "$P/static/img/s"
printf 'PNG\n' >"$P/static/img/s/a.png"
posttool "$HOOKS/check-image-path.sh" "$P" "$P/static/img/s/a.png"; check_exit 0 "$RC" "image under static/img passes"

echo "== check-no-tooling-refs.sh =="
printf -- '---\nx\n---\nAll users see the same behavior.\n' >"$P/docs/clean.md"
posttool "$HOOKS/check-no-tooling-refs.sh" "$P" "$P/docs/clean.md"; check_exit 0 "$RC" "clean doc passes"

printf 'Scenario script: .claude/scenarios/search.yaml\n' >"$P/docs/leak-path.md"
posttool "$HOOKS/check-no-tooling-refs.sh" "$P" "$P/docs/leak-path.md"; check_exit 2 "$RC" ".claude/ path blocks"
check_stderr "Rule 5" "tooling-ref message cites Rule 5"

printf 'See .claude/CLAUDE.md (§3) for roles.\n' >"$P/docs/leak-claudemd.md"
posttool "$HOOKS/check-no-tooling-refs.sh" "$P" "$P/docs/leak-claudemd.md"; check_exit 2 "$RC" "CLAUDE.md citation blocks"

printf 'Generated with the lore:site-to-doc skill.\n' >"$P/docs/leak-ns.md"
posttool "$HOOKS/check-no-tooling-refs.sh" "$P" "$P/docs/leak-ns.md"; check_exit 2 "$RC" "lore: namespace blocks"

printf 'Folklore: a study of stories and traditions.\n' >"$P/docs/folklore.md"
posttool "$HOOKS/check-no-tooling-refs.sh" "$P" "$P/docs/folklore.md"; check_exit 0 "$RC" "folklore: is not a false positive"

printf 'See .claude/CLAUDE.md and lore:doc-reviewer.\n' >"$P/.claude/leak.md"
posttool "$HOOKS/check-no-tooling-refs.sh" "$P" "$P/.claude/leak.md"; check_exit 0 "$RC" "carve-out: .claude/ ignored"

printf 'Uses .claude/scenarios and lore:site-to-doc.\n' >"$P/templates/docs-layer/docs/leak.md"
posttool "$HOOKS/check-no-tooling-refs.sh" "$P" "$P/templates/docs-layer/docs/leak.md"; check_exit 0 "$RC" "carve-out: templates/ ignored"

echo "== jq/python3 fallback =="
FB=$(mktemp -d)
for t in sh sed grep awk head cat tr find ls wc dirname sort; do
  p=$(command -v "$t" 2>/dev/null) && ln -s "$p" "$FB/$t" 2>/dev/null
done
# sed last-resort still extracts file_path → still blocks a missing-fm file.
printf '{"cwd":"%s","tool_input":{"file_path":"%s"}}' "$P" "$P/docs/nofm.md" |
  PATH="$FB" CLAUDE_PROJECT_DIR="$P" sh "$HOOKS/check-frontmatter.sh" 2>"$ERRF"
check_exit 2 "$?" "sed fallback still enforces"
# No parser + payload lacking file_path → loud warning, non-blocking.
printf '{"cwd":"%s","tool_input":{}}' "$P" |
  PATH="$FB" CLAUDE_PROJECT_DIR="$P" sh "$HOOKS/check-frontmatter.sh" 2>"$ERRF"
check_exit 0 "$?" "unparseable payload is non-blocking"
check_stderr "NOT enforced" "unparseable payload warns loudly"

echo "== verify-docs.sh (Stop) =="
V=$(mktemp -d); make_lore_project "$V"; mkdir -p "$V/docs" "$V/static/img/s"
printf '![a](/img/s/used.png)\n' >"$V/docs/ok.md"
printf 'PNG\n' >"$V/static/img/s/used.png"
stophook "$V" false; check_exit 0 "$RC" "clean project passes"

printf 'PNG\n' >"$V/docs/bad.png"
stophook "$V" false; check_exit 2 "$RC" "image under docs/ blocks on Stop"
rm -f "$V/docs/bad.png"

printf '![a](/static/img/s/a.png)\n' >"$V/docs/badref.md"
stophook "$V" false; check_exit 2 "$RC" "/static/img ref blocks on Stop"
rm -f "$V/docs/badref.md"

printf '![m](/img/s/mobile/a.png)\n' >"$V/docs/mdmobile.md"
stophook "$V" false; check_exit 2 "$RC" "markdown /mobile/ ref blocks on Stop"
rm -f "$V/docs/mdmobile.md"

printf '<img src="/img/s/mobile/a.png" alt="m" />\n' >"$V/docs/htmlmobile.md"
stophook "$V" false; check_exit 0 "$RC" "raw <img> /mobile/ ref passes on Stop"
rm -f "$V/docs/htmlmobile.md"

printf 'PNG\n' >"$V/static/img/s/orphan.png"
stophook "$V" false; check_exit 0 "$RC" "orphan image is non-blocking"
check_stderr "orphan" "orphan image warns"
rm -f "$V/static/img/s/orphan.png"

# loop guard: a live violation must not block when stop_hook_active=true
printf 'PNG\n' >"$V/docs/bad.png"
stophook "$V" true; check_exit 0 "$RC" "stop_hook_active short-circuits"
rm -f "$V/docs/bad.png"

# filename with a space must not break the orphan haystack
printf '![a](/img/s/used.png)\n' >"$V/docs/with space.md"
stophook "$V" false; check_exit 0 "$RC" "doc filename with space is handled"

echo "== record-evidence.sh (PostToolUse) =="
E=$(mktemp -d); make_lore_project "$E"
LOG="$E/.claude/sources/.evidence-log"

posttool_tool "$HOOKS/record-evidence.sh" "$E" "WebFetch" '{"url":"https://help.example.org/a"}'
check_exit 0 "$RC" "WebFetch never blocks"
check_file_has "$LOG" "help.example.org" "WebFetch URL is logged"

posttool_tool "$HOOKS/record-evidence.sh" "$E" "Bash" '{"command":"curl -sI https://blog.example.org/x"}'
check_file_has "$LOG" "blog.example.org" "URL inside a Bash command is logged"

posttool_tool "$HOOKS/record-evidence.sh" "$E" "Task" '{"subagent_type":"lore:site-explorer"}'
check_file_has "$LOG" "subagent:lore:site-explorer" "subagent invocation is logged"

check_file_has "$E/.claude/sources/.gitignore" "evidence-log" "run artifacts are git-ignored"

# Tiering: a fetching tool vouches for the fetch; a URL sitting in a shell command does not.
if awk -F'\t' '$3 ~ /help\.example\.org/ && $4 == "verified" { f=1 } END { exit !f }' "$LOG"; then
  pass "a WebFetch is tiered verified"; else fail "a WebFetch is tiered verified"; fi
if awk -F'\t' '$3 ~ /blog\.example\.org/ && $4 == "mentioned" { f=1 } END { exit !f }' "$LOG"; then
  pass "a URL seen in a Bash command is tiered mentioned"; else fail "a URL seen in a Bash command is tiered mentioned"; fi

# The log is TAB-separated and one line per fetch, and the value comes from tool input.
# An embedded newline used to append a second, forged entry for a host never contacted —
# in the one record the census is checked against. A tab would forge the tier column.
FG=$(mktemp -d); make_lore_project "$FG"
posttool_tool "$HOOKS/record-evidence.sh" "$FG" "WebFetch" \
  '{"url":"https://real.example.org/a\n2026-01-01T00:00:00Z\tWebFetch\thttps://forged.internal/x\tverified"}'
if grep -q 'forged.internal' "$FG/.claude/sources/.evidence-log" 2>/dev/null; then
  fail "a newline in a URL cannot forge a log entry"
else
  pass "a newline in a URL cannot forge a log entry"
fi
if [ "$(wc -l <"$FG/.claude/sources/.evidence-log")" -eq 1 ]; then
  pass "one fetch produces exactly one log line"
else
  fail "one fetch produces exactly one log line"
fi
posttool_tool "$HOOKS/record-evidence.sh" "$FG" "WebFetch" '{"url":"https://t.example.org/a\tverified\tx"}'
if awk -F'\t' 'NF > 4 { f=1 } END { exit !f }' "$FG/.claude/sources/.evidence-log"; then
  fail "an embedded tab cannot add log fields"
else
  pass "an embedded tab cannot add log fields"
fi
# A Bash command touching several URLs still yields one line each.
posttool_tool "$HOOKS/record-evidence.sh" "$FG" "Bash" \
  '{"command":"curl -s https://m1.example.net/x && curl -s https://m2.example.net/y"}'
if grep -c 'm[12].example.net' "$FG/.claude/sources/.evidence-log" | grep -q '^2$'; then
  pass "a multi-URL Bash command still logs one line per URL"
else
  fail "a multi-URL Bash command still logs one line per URL"
fi

# A repo that is not a Lore project must never be written to.
NL=$(mktemp -d); mkdir -p "$NL/.claude"; printf 'no import here\n' >"$NL/.claude/CLAUDE.md"
posttool_tool "$HOOKS/record-evidence.sh" "$NL" "WebFetch" '{"url":"https://nope.example.org/"}'
check_exit 0 "$RC" "non-Lore repo: exits 0"
[ ! -e "$NL/.claude/sources" ] && pass "non-Lore repo: nothing written" || fail "non-Lore repo: nothing written"

echo "== record-validator-run.sh (SubagentStop) =="
subagentstop "$E" "Recommendation: APPROVED"
check_exit 0 "$RC" "never blocks"
check_file_has "$E/.claude/sources/.validator-receipt" "APPROVED" "APPROVED verdict recorded"
subagentstop "$E" "Recommendation: BLOCKED - DO NOT DELIVER"
check_file_has "$E/.claude/sources/.validator-receipt" "BLOCKED" "BLOCKED verdict recorded"
subagentstop "$E" "some unrelated text"
check_file_has "$E/.claude/sources/.validator-receipt" "UNKNOWN" "unparseable verdict is UNKNOWN, not a pass"

# The verdict must OPEN a line. A bare substring search read it out of ordinary prose,
# which is the same defect the run-contract gate had: a report saying "nothing was
# BLOCKED" became a BLOCKED verdict, and any passing mention of APPROVED became a pass.
check_verdict() { # message expected name
  subagentstop "$E" "$1"
  if [ "$(cut -f2 "$E/.claude/sources/.validator-receipt")" = "$2" ]; then
    pass "$3"
  else
    fail "$3 (got '$(cut -f2 "$E/.claude/sources/.validator-receipt")', want '$2')"
  fi
}
check_verdict '## Findings\n\nNothing was BLOCKED by this review.\n\n## Recommendation\n\nAPPROVED' \
  "APPROVED" "a mid-report mention of BLOCKED does not set the verdict"
check_verdict '## Recommendation\n\nBLOCKED - DO NOT DELIVER' \
  "BLOCKED" "a BLOCKED recommendation line still wins"
check_verdict 'Reviewed 4 files. No APPROVED baseline exists yet.\n\nRecommendation: BLOCKED' \
  "BLOCKED" "a mid-report mention of APPROVED does not set the verdict"
check_verdict '## Recommendation\n\nAPPROVED WITH WARNINGS' \
  "APPROVED WITH WARNINGS" "the qualified pass is distinguished from a clean pass"
check_verdict 'Verdict: APPROVED' \
  "APPROVED" "a labelled verdict line resolves"
check_verdict '## Recommendation\n\nOK, looks good to me' \
  "UNKNOWN" "a report with no recognisable verdict is UNKNOWN, not a pass"

echo "== check-census.sh (PostToolUse) =="
C=$(mktemp -d); make_lore_project "$C"
mkdir -p "$C/.claude/sources/raw" "$C/static/img/s" "$C/docs"
printf 'body bytes\n' >"$C/.claude/sources/raw/t1-help.md"
printf 'PNG\n' >"$C/static/img/s/s-01.png"
printf '2026-01-01T00:00:00Z\tWebFetch\thttps://help.example.org/a\n' >"$C/.claude/sources/.evidence-log"
CEN="$C/.claude/sources/site-x-census.md"

# A well-formed, fully receipted census passes.
{
  echo '## Run contract'
  echo '| ref | instruction | status | evidence |'
  echo '| u1 | cover signed-in | satisfied | o1 |'
  echo '## Trusted Sources (1) coverage'
  echo '| t1 | Help → https://help.example.org | WebFetch | 200 | 812 | .claude/sources/raw/t1-help.md | "x" | nothing relevant — confirmed searched |'
  echo '## Observation coverage'
  echo '| o1 | signed-in | admin | / | 1280x720 | static/img/s/s-01.png |'
} >"$CEN"
posttool "$HOOKS/check-census.sh" "$C" "$CEN"; check_exit 0 "$RC" "receipted census passes"

# A file under .claude/ that is not a census is out of scope.
printf 'whatever\n' >"$C/.claude/sources/notes.md"
posttool "$HOOKS/check-census.sh" "$C" "$C/.claude/sources/notes.md"
check_exit 0 "$RC" "non-census file under .claude/ is ignored"

# This hook is on Write|Edit, so it runs in every repo where the plugin is installed.
# It must not act — or spend a JSON parser — in one that is not a Lore project.
NLC=$(mktemp -d); mkdir -p "$NLC/.claude/sources"
printf 'no import here\n' >"$NLC/.claude/CLAUDE.md"
printf 'not a real census\n' >"$NLC/.claude/sources/site-x-census.md"
posttool "$HOOKS/check-census.sh" "$NLC" "$NLC/.claude/sources/site-x-census.md"
check_exit 0 "$RC" "non-Lore repo: census rules do not apply"

# The exact failure that shipped: a zero-case asserted with no probe behind it.
sed 's#| WebFetch | 200 | 812 | .claude/sources/raw/t1-help.md |#| assumed | — | — | — |#' "$CEN" >"$CEN.tmp" && mv "$CEN.tmp" "$CEN"
posttool "$HOOKS/check-census.sh" "$C" "$CEN"; check_exit 2 "$RC" "zero-case with no receipt blocks"
check_stderr "no receipt" "receiptless zero-case names the rule"

# A receipt pointing at a payload that does not exist is not a receipt.
{
  echo '## Run contract'
  echo '| u1 | x | satisfied | docs/a.md |'
  echo '## Trusted Sources (1) coverage'
  echo '| t1 | Help → https://help.example.org | WebFetch | 200 | 812 | .claude/sources/raw/ghost.md | "x" | nothing relevant — confirmed searched |'
  echo '## Observation coverage'
  echo '| o1 | guest | — | / | 1280x720 | static/img/s/s-01.png |'
} >"$CEN"
posttool "$HOOKS/check-census.sh" "$C" "$CEN"; check_exit 2 "$RC" "missing raw payload blocks"

# A source claimed but never fetched — the hook-written log is the arbiter.
{
  echo '## Run contract'
  echo '| u1 | x | satisfied | docs/a.md |'
  echo '## Trusted Sources (1) coverage'
  echo '| t1 | Portal → https://never-fetched.example.org | WebFetch | 200 | 812 | .claude/sources/raw/t1-help.md | "x" | nothing relevant — confirmed searched |'
  echo '## Observation coverage'
  echo '| o1 | guest | — | / | 1280x720 | static/img/s/s-01.png |'
} >"$CEN"
posttool "$HOOKS/check-census.sh" "$C" "$CEN"; check_exit 2 "$RC" "source never fetched blocks"
check_stderr "never" "unfetched source is named"

# A missing Run contract loses whatever the user asked for.
printf '## Trusted Sources (1) coverage\n- Zero case: no trusted sources configured\n## Observation coverage\n| o1 | guest | — | / | 1280x720 | static/img/s/s-01.png |\n' >"$CEN"
posttool "$HOOKS/check-census.sh" "$C" "$CEN"; check_exit 2 "$RC" "missing Run contract blocks"

# §0.1 applies to EVERY row, not only the ones stating a zero. A row claiming a
# positive finding used to be skipped before the receipt check ever ran — and positive
# rows are the majority of rows.
{
  echo '## Run contract'
  echo '| u1 | x | satisfied | docs/a.md |'
  echo '## Trusted Sources (1) coverage'
  echo '| t1 | Help → https://help.example.org | fetched and reviewed | 3 rules about upload limits |'
} >"$CEN"
posttool "$HOOKS/check-census.sh" "$C" "$CEN"; check_exit 2 "$RC" "positive-finding row with no receipt blocks"
check_stderr "no receipt" "the receiptless positive row is named"

# §0.2: the probe contradicting its own zero is a parser failure, not an absence —
# the bug that laundered a code defect into a certified 'no annotations here'.
{
  echo '## Run contract'
  echo '| u1 | x | satisfied | docs/a.md |'
  echo '- annotations: 0 — corroboration=RAW-HAS-ANNOTATION-DATA'
} >"$CEN"
posttool "$HOOKS/check-census.sh" "$C" "$CEN"; check_exit 2 "$RC" "a zero the raw payload contradicts blocks"
check_stderr "parser failure" "names it as a parser failure"

# A quoted example of the format is not a claim about this run.
{
  echo '## Run contract'
  echo '| u1 | x | satisfied | docs/a.md |'
  echo 'Format to follow:'
  echo '```markdown'
  echo '| t1 | Example → https://never-fetched.example.org | WebFetch | 200 | 1 | .claude/sources/raw/ghost.md | "x" | nothing relevant |'
  echo '```'
} >"$CEN"
posttool "$HOOKS/check-census.sh" "$C" "$CEN"; check_exit 0 "$RC" "a fenced format example is not judged as a row"

echo "== check-census.sh trust tiers (2B) =="
# A URL that merely appears in a Bash command was never fetched: `grep -rn "https://x"`
# contacted nothing. Accepting it manufactured a receipt during ordinary work.
TT=$(mktemp -d); make_lore_project "$TT"; mkdir -p "$TT/.claude/sources/raw"
printf 'payload\n' >"$TT/.claude/sources/raw/t1.md"
TCEN="$TT/.claude/sources/brief-x-census.md"
tcen() { { echo '## Run contract'; echo '| u1 | x | satisfied | docs/a.md |';
  echo '## Trusted Sources (1) coverage'
  echo "| t1 | Portal → https://tiered.example.org | WebFetch | 200 | 9 | .claude/sources/raw/t1.md | \"x\" | nothing relevant — confirmed searched |"; } >"$TCEN"; }

tcen
printf '2026-01-01T00:00:00Z\tBash\thttps://tiered.example.org/x\tmentioned\n' >"$TT/.claude/sources/.evidence-log"
posttool "$HOOKS/check-census.sh" "$TT" "$TCEN"; check_exit 2 "$RC" "a 'mentioned' URL is not proof the source was read"
check_stderr "verified fetch" "explains that a shell mention is not a fetch"

printf '2026-01-01T00:00:00Z\tWebFetch\thttps://tiered.example.org/x\tverified\n' >>"$TT/.claude/sources/.evidence-log"
posttool "$HOOKS/check-census.sh" "$TT" "$TCEN"; check_exit 0 "$RC" "a 'verified' fetch of the same host satisfies the row"

# Logs written before tiering have three fields and must keep working.
printf '2026-01-01T00:00:00Z\tWebFetch\thttps://tiered.example.org/x\n' >"$TT/.claude/sources/.evidence-log"
posttool "$HOOKS/check-census.sh" "$TT" "$TCEN"; check_exit 0 "$RC" "a pre-tiering 3-field log line still counts as verified"

echo "== verify-docs.sh process gates =="
G=$(mktemp -d); make_lore_project "$G"; mkdir -p "$G/docs" "$G/.claude/sources"
printf 'page\n' >"$G/docs/a.md"
# The gates apply to sessions that produced documentation; record-evidence.sh writes
# this marker on a docs/ write, so a producing run always has one by the time Stop fires.
printf 'sess-g\n' >"$G/.claude/sources/.docs-touched"
# A complete census, so these assertions isolate the validator gate. (A brief census has
# no input-specific manifest, so nothing here depends on the Figma/site completeness rules.)
printf '## Run contract\n| u1 | x | satisfied | docs/a.md |\n' >"$G/.claude/sources/brief-g-census.md"

stophook "$G" false; check_exit 2 "$RC" "docs with no validator run blocks"
check_stderr "doc-validator" "names the validator"

subagentstop "$G" "Recommendation: APPROVED"
stophook "$G" false; check_exit 0 "$RC" "fresh APPROVED receipt passes"

subagentstop "$G" "Recommendation: BLOCKED"
stophook "$G" false; check_exit 2 "$RC" "BLOCKED verdict blocks the turn"

subagentstop "$G" "Recommendation: APPROVED"
sleep 1; printf 'edited\n' >"$G/docs/a.md"
stophook "$G" false; check_exit 2 "$RC" "docs edited after validation blocks"

subagentstop "$G" "Recommendation: APPROVED"
printf '## Run contract\n| u1 | cover mobile | pending | — |\n' >"$G/.claude/sources/brief-g-census.md"
stophook "$G" false; check_exit 2 "$RC" "open run-contract row blocks"
check_stderr "run-contract" "names the open instruction"

printf '## Run contract\n| u1 | cover mobile | satisfied | img/x.png |\n' >"$G/.claude/sources/brief-g-census.md"
subagentstop "$G" "Recommendation: APPROVED"
stophook "$G" false; check_exit 0 "$RC" "satisfied run-contract row passes"

# The critical no-false-block case: a docs tree with no Lore evidence is untouched.
NG=$(mktemp -d); mkdir -p "$NG/docs"; printf 'page\n' >"$NG/docs/a.md"
stophook "$NG" false; check_exit 0 "$RC" "non-Lore docs tree is never process-gated"

echo "== verify-docs.sh session scoping (no false blocks) =="
# Something outside Claude (a git pull, an editor save) leaves docs newer than the
# receipt. A session that never wrote documentation must not be punished for it.
SS=$(mktemp -d); make_lore_project "$SS"; mkdir -p "$SS/docs" "$SS/.claude/sources"
printf 'page\n' >"$SS/docs/a.md"
subagentstop "$SS" "Recommendation: APPROVED"
printf 'sess-writer\n' >"$SS/.claude/sources/.docs-touched"
sleep 1; printf 'changed outside claude\n' >"$SS/docs/a.md"

stophook "$SS" false "sess-reader"
check_exit 0 "$RC" "session that wrote no docs is not gated by someone else's edit"

stophook "$SS" false "sess-writer"
check_exit 2 "$RC" "session that DID write docs is still gated"

# A project with NO .docs-touched marker at all means no session here has produced
# documentation. The marker is git-ignored, so this is the state of every fresh clone:
# a committed census, no receipts. Reading the absence as "unknown, therefore block"
# blocked every session in every clone — including ones that touched nothing — and the
# only escape was the stop_hook_active bypass. Absence must skip.
SS2=$(mktemp -d); make_lore_project "$SS2"; mkdir -p "$SS2/docs" "$SS2/.claude/sources"
printf 'page\n' >"$SS2/docs/a.md"
printf '## Run contract\n| u1 | x | satisfied | ok |\n' >"$SS2/.claude/sources/site-c-census.md"
stophook "$SS2" false "sess-x"
check_exit 0 "$RC" "fresh clone (no .docs-touched) does not block a session that produced nothing"

# ...and the moment that session does write documentation, it is gated again.
printf 'sess-x\n' >"$SS2/.claude/sources/.docs-touched"
stophook "$SS2" false "sess-x"
check_exit 2 "$RC" "same project, once the session has written docs → gated"

# An open [u#] row in a committed census must not block a non-producing session either.
SS3=$(mktemp -d); make_lore_project "$SS3"; mkdir -p "$SS3/docs" "$SS3/.claude/sources"
printf 'page\n' >"$SS3/docs/a.md"
printf '## Run contract\n| u1 | cover mobile | pending | — |\n' >"$SS3/.claude/sources/site-c-census.md"
stophook "$SS3" false "sess-reader"
check_exit 0 "$RC" "open run-contract row does not block a session that produced nothing"

echo "== the census must EXIST, and be complete by Stop (2A) =="
# Every §0 rule is checked against the census, and check-census.sh only fires when one
# is written — so a run that never writes one skips all of them at once. Requiring the
# artifact is what makes the rest of the evidence layer reachable at all.
N2=$(mktemp -d); make_lore_project "$N2"; mkdir -p "$N2/docs" "$N2/.claude/sources" "$N2/static/img/s"
printf 'page\n' >"$N2/docs/a.md"
printf 'sess-n2\n' >"$N2/.claude/sources/.docs-touched"
subagentstop "$N2" "Recommendation: APPROVED"
stophook "$N2" false "sess-n2"
check_exit 2 "$RC" "a producing session with NO census at all blocks"
check_stderr "no source census" "names the missing artifact"

# The pre-flight write the skills actually prescribe — Run contract only, before any
# fetching — must PASS at write time. Blocking it is what taught the model to write a
# placeholder that then satisfied the check for the rest of the run.
echo "== the census the skills prescribe at pre-flight is writable (H4) =="
PF=$(mktemp -d); make_lore_project "$PF"; mkdir -p "$PF/.claude/sources"
for kind in site figma brief; do
  PFC="$PF/.claude/sources/$kind-x-census.md"
  printf '## Run contract   (0.4)\n| ref | instruction | status | evidence |\n|-----|---|---|---|\n| u1 | cover the signed-in state | pending | |\n' >"$PFC"
  posttool "$HOOKS/check-census.sh" "$PF" "$PFC"
  check_exit 0 "$RC" "$kind: the step-0 Run-contract-only census is accepted at write time"
done

# …and the same half-written census must NOT survive to delivery.
echo "== a placeholder census does not survive Stop (H4) =="
PH=$(mktemp -d); make_lore_project "$PH"; mkdir -p "$PH/docs" "$PH/.claude/sources"
printf 'page\n' >"$PH/docs/a.md"
printf 'sess-ph\n' >"$PH/.claude/sources/.docs-touched"
printf '## Run contract\n| u1 | x | satisfied | ok |\n\n## Observation coverage\n_TBD_\n' \
  >"$PH/.claude/sources/site-x-census.md"
subagentstop "$PH" "Recommendation: APPROVED"
stophook "$PH" false "sess-ph"
check_exit 2 "$RC" "an Observation coverage heading with no rows blocks at Stop"
check_stderr "no observed states" "names the empty matrix"

printf '## Run contract\n| u1 | x | satisfied | ok |\n\n## Observation coverage\n| ref | auth | role | route | viewport | screenshot |\n|---|---|---|---|---|---|\n| o1 | guest | — | / | 1280x720 | static/img/s/a.png |\n' \
  >"$PH/.claude/sources/site-x-census.md"
subagentstop "$PH" "Recommendation: APPROVED"
stophook "$PH" false "sess-ph"
check_exit 0 "$RC" "a real observed state passes Stop"

# The Figma equivalent: six source types named in one prose line used to satisfy the
# manifest check, because it was a whole-file substring grep.
rm -f "$PH/.claude/sources/site-x-census.md"
printf '## Run contract\n| u1 | x | satisfied | ok |\n\n## Counts\nCounts pending for: Comment threads, annotations, flowStartingPoints, interactions, variants, variables.\n' \
  >"$PH/.claude/sources/figma-y-census.md"
subagentstop "$PH" "Recommendation: APPROVED"
stophook "$PH" false "sess-ph"
check_exit 2 "$RC" "naming the six Figma source types in prose does not count as coverage"

{
  echo '## Run contract'
  echo '| u1 | x | satisfied | ok |'
  echo
  echo '## Counts'
  echo '| source type | count | probe | status | bytes | scanned | raw payload |'
  echo '|---|---|---|---|---|---|---|'
  echo '| Comment threads | 0 | GET /comments | 200 | 12 | — | .claude/sources/raw/c.json |'
  echo '| Dev-Mode annotations (`annotations` property) | 17 | GET /nodes | 200 | 99 | 400 | .claude/sources/raw/n.json |'
  echo '| Prototype flows (`flowStartingPoints`) | 2 | (same) | 200 | 99 | 400 | (same) |'
  echo '| Interaction edges (`interactions[]`) | 31 | (same) | 200 | 99 | 400 | (same) |'
  echo '| Differentiating component variants/properties | 4 | (same) | 200 | 99 | 400 | (same) |'
  echo '| Constraint-bearing variables | 0 | get_variable_defs | 200 | 12 | — | .claude/sources/raw/v.json |'
} >"$PH/.claude/sources/figma-y-census.md"
subagentstop "$PH" "Recommendation: APPROVED"
stophook "$PH" false "sess-ph"
check_exit 0 "$RC" "a counted row per Figma source type passes Stop"

# A source type present but never counted is the same miss with better manners.
sed 's/| Constraint-bearing variables | 0 |/| Constraint-bearing variables | — |/' \
  "$PH/.claude/sources/figma-y-census.md" >"$PH/.claude/sources/tmp" &&
  mv "$PH/.claude/sources/tmp" "$PH/.claude/sources/figma-y-census.md"
subagentstop "$PH" "Recommendation: APPROVED"
stophook "$PH" false "sess-ph"
check_exit 2 "$RC" "a Figma source type with no number blocks"

echo "== verify-docs.sh run-contract status is a whole field, not a substring =="
# `grep -v satisfied` filtered out "not satisfied" and "unsatisfied" — the exact
# wording §0.4's own text ("not marked satisfied") primes the model to write — so the
# gate passed the failure it was built to catch.
U=$(mktemp -d); make_lore_project "$U"; mkdir -p "$U/docs" "$U/.claude/sources"
printf 'page\n' >"$U/docs/a.md"
printf 'sess-u\n' >"$U/.claude/sources/.docs-touched"
u_row() { printf '## Run contract\n| ref | instruction | status | evidence |\n|-----|---|---|---|\n| u1 | cover the signed-in state | %s | %s |\n' "$1" "$2" >"$U/.claude/sources/brief-u-census.md"; }
u_check() { # status evidence expected-exit name
  u_row "$1" "$2"
  subagentstop "$U" "Recommendation: APPROVED"
  stophook "$U" false "sess-u"
  check_exit "$3" "$RC" "$4"
}
u_check "not satisfied"     "o2"  2 "'not satisfied' is an open row"
u_check "unsatisfied"       "o2"  2 "'unsatisfied' is an open row"
u_check "not yet satisfied" "o2"  2 "'not yet satisfied' is an open row"
u_check "pending"           "o2"  2 "'pending' is an open row"
u_check "partial"           "o2"  2 "'partial' is an open row"
u_check ""                  "o2"  2 "an empty status is an open row"
u_check "satisfied"         ""    2 "'satisfied' with no evidence is an open row (§0.4)"
u_check "satisfied"         "—"   2 "'satisfied' with a dash for evidence is an open row"
u_check "satisfied"         "o2"  0 "'satisfied' with evidence closes the row"
u_check "Satisfied"         "o2"  0 "status matching is case-insensitive"
u_check "waived"            ""    0 "'waived' closes the row without evidence"
u_check "waived (user approved)" "" 0 "'waived (user approved)' closes the row"

echo "== record-evidence.sh session marker =="
posttool_tool "$HOOKS/record-evidence.sh" "$E" "Write" '{"file_path":"'"$E"'/docs/new.md"}'
check_exit 0 "$RC" "docs write never blocks"
check_file_has "$E/.claude/sources/.docs-touched" "." "docs write records the session"
posttool_tool "$HOOKS/record-evidence.sh" "$E" "Write" '{"file_path":"'"$E"'/src/code.ts"}'
if [ "$(wc -l <"$E/.claude/sources/.docs-touched")" -eq 1 ]; then
  pass "a non-docs write is not recorded"
else
  fail "a non-docs write is not recorded"
fi

echo "== remind-census.sh (PreToolUse) =="
R=$(mktemp -d); make_lore_project "$R"; mkdir -p "$R/docs"
pretool "$HOOKS/remind-census.sh" "$R" "$R/docs/new.md"
check_exit 0 "$RC" "never blocks a write"
if printf '%s' "$OUT" | grep -q 'additionalContext'; then pass "reminds when no census exists"; else fail "reminds when no census exists"; fi

mkdir -p "$R/.claude/sources"; printf 'x\n' >"$R/.claude/sources/brief-y-census.md"
pretool "$HOOKS/remind-census.sh" "$R" "$R/docs/new2.md"
if [ -z "$OUT" ]; then pass "silent once a census exists"; else fail "silent once a census exists (got $OUT)"; fi

printf 'existing\n' >"$R/docs/old.md"
rm -rf "$R/.claude/sources"
pretool "$HOOKS/remind-census.sh" "$R" "$R/docs/old.md"
if [ -z "$OUT" ]; then pass "silent when editing an existing page"; else fail "silent when editing an existing page"; fi

echo "== figma-probe.sh =="
FP="$SCRIPTS/figma-probe.sh"
Q=$(mktemp -d)

# The regression that shipped: the annotation text field was renamed, so a probe
# keyed on one field name reported a confident zero. Both shapes must be found.
printf '{"nodes":{"a":{"document":{"id":"1:3","name":"Box","annotations":[{"label":"Max 6GB","labelMarkdown":"**6GB**"}]}}}}\n' >"$Q/label.json"
printf '{"nodes":{"a":{"document":{"id":"1:4","name":"Box","annotations":[{"notes":"legacy","pinned":true}]}}}}\n' >"$Q/notes.json"
printf '{"nodes":{"a":{"document":{"id":"1:5","annotations":[]}}}}\n' >"$Q/empty.json"
printf '{"nodes":{"a":{"document":{"id":"1:6","annotations":[{"label":"Max 6GB"}]},"x":\n' >"$Q/truncated.json"

if command -v jq >/dev/null 2>&1; then
  OUT=$(sh "$FP" parse "$Q/label.json" 2>"$ERRF"); RC=$?
  check_exit 0 "$RC" "annotations found via label field"
  if printf '%s' "$OUT" | grep -q 'annotations=1'; then pass "label-shaped annotation counted"; else fail "label-shaped annotation counted"; fi

  OUT=$(sh "$FP" parse "$Q/notes.json" 2>"$ERRF"); RC=$?
  if printf '%s' "$OUT" | grep -q 'annotations=1'; then pass "notes-shaped annotation counted (field name is irrelevant)"; else fail "notes-shaped annotation counted"; fi

  OUT=$(sh "$FP" parse "$Q/empty.json" 2>"$ERRF"); RC=$?
  check_exit 0 "$RC" "genuine empty array is a valid zero"
  if printf '%s' "$OUT" | grep -q 'corroboration=raw-confirms-none'; then pass "genuine zero is corroborated"; else fail "genuine zero is corroborated"; fi

  # A truncated response is a FAILED READ, not an absence.
  OUT=$(sh "$FP" parse "$Q/truncated.json" 2>"$ERRF"); RC=$?
  check_exit 4 "$RC" "unparseable payload with annotation data is a parser failure, not a zero"
  check_stderr "PARSER FAILURE" "parser failure is named loudly"
else
  pass "figma-probe parse tests skipped (jq unavailable)"
fi

OUT=$(sh "$FP" parse "$Q/missing.json" 2>"$ERRF"); RC=$?
check_exit 3 "$RC" "missing payload is a failed read"

# `$key` is interpolated into the raw-payload filename AND the request path, so it
# must be constrained the way `$ids` already is. `parse` takes a PATH in the same
# position, so the check has to sit after the parse branch — not at argument parsing.
FIGMA_TOKEN=x sh "$FP" comments '../../escape' "$Q" >/dev/null 2>"$ERRF"; RC=$?
check_exit 1 "$RC" "a traversing file key is rejected"
[ -e "$Q/../../figma-../../escape-comments.json" ] && fail "traversal wrote outside outdir" || pass "traversal writes nothing outside outdir"
FIGMA_TOKEN=x sh "$FP" comments 'abc/../../x' "$Q" >/dev/null 2>"$ERRF"
check_exit 1 "$?" "a file key containing a path separator is rejected"
# The legitimate shape must still pass this check (it fails later, on the network).
FIGMA_TOKEN=x sh "$FP" comments 'aBc123_-XYZ' "$Q" >/dev/null 2>"$ERRF"
[ "$?" -eq 1 ] && fail "a valid file key was rejected as malformed" || pass "a valid file key passes the shape check"

echo "== skills invoke the probe through CLAUDE_PLUGIN_ROOT =="
# The probe ships with the plugin, not the consumer repo, so a bare relative path
# resolves to nothing there — and a model that cannot run it falls back to the
# hand-parsing this script exists to replace.
if grep -rn '[^{/]scripts/figma-probe\.sh' "$SCRIPT_DIR/../plugins/lore/skills" >/dev/null 2>&1; then
  fail "a skill still invokes figma-probe.sh by a bare relative path"
  grep -rn '[^{/]scripts/figma-probe\.sh' "$SCRIPT_DIR/../plugins/lore/skills" >&2
else
  pass "no skill invokes figma-probe.sh by a bare relative path"
fi

echo "== no document claims a guarantee the code does not provide =="
# The evidence artifacts are plain files; an agent with shell access can write one.
# They guard against a step being skipped, not against deliberate forgery. Claiming
# otherwise is what made the last release believe it had closed this class of bug.
if grep -rn 'cannot be faked\|cannot be fabricated\|the turn cannot end' \
     "$SCRIPT_DIR/../plugins/lore" "$SCRIPT_DIR/../CLAUDE.md" "$SCRIPT_DIR/../CHANGELOG.md" >/dev/null 2>&1; then
  fail "an overclaim about unforgeability survives"
  grep -rn 'cannot be faked\|cannot be fabricated\|the turn cannot end' \
    "$SCRIPT_DIR/../plugins/lore" "$SCRIPT_DIR/../CLAUDE.md" "$SCRIPT_DIR/../CHANGELOG.md" >&2
else
  pass "no unforgeability overclaim remains"
fi

echo "== detect-project.sh =="
det() { sh "$SCRIPTS/detect-project.sh" "$1"; }
D=$(mktemp -d);                                   check_exit "empty"          "$(det "$D")" "empty dir" 2>/dev/null
D=$(mktemp -d); printf x >"$D/random.txt";        [ "$(det "$D")" = "non-empty" ] && pass "loose file → non-empty" || fail "loose file → non-empty (got $(det "$D"))"
D=$(mktemp -d); mkdir -p "$D/.claude"; printf '{}' >"$D/.claude/settings.json"
  [ "$(det "$D")" = "non-empty" ] && pass "bare .claude/ → non-empty" || fail "bare .claude/ → non-empty (got $(det "$D"))"
D=$(mktemp -d); mkdir -p "$D/.claude"; printf '{}' >"$D/.claude/lore.json"
  [ "$(det "$D")" = "docs-only" ] && pass "lore.json marker → docs-only" || fail "marker → docs-only (got $(det "$D"))"
D=$(mktemp -d); mkdir -p "$D/docs" "$D/.claude"; printf '#' >"$D/.claude/CLAUDE.md"
  [ "$(det "$D")" = "docs-only" ] && pass "legacy docs+CLAUDE.md → docs-only" || fail "legacy → docs-only (got $(det "$D"))"
D=$(mktemp -d); printf 'x' >"$D/docusaurus.config.ts"
  [ "$(det "$D")" = "has-docusaurus" ] && pass "config → has-docusaurus" || fail "config → has-docusaurus (got $(det "$D"))"

echo "== scaffold.sh =="
S=$(mktemp -d)
sh "$SCRIPTS/scaffold.sh" --target "$S" --layer docs >/dev/null 2>"$ERRF"
check_exit 0 "$?" "scaffold exits 0 on success"
[ -f "$S/.claude/CLAUDE.md" ] && [ -f "$S/docs/intro.md" ] && [ -f "$S/README.md" ] && pass "docs layer scaffolds key files" || fail "docs layer scaffolds key files"
[ -f "$S/.claude/lore-methodology.md" ] && pass "scaffold includes lore-methodology.md" || fail "scaffold includes lore-methodology.md"
grep -q '@lore-methodology.md' "$S/.claude/CLAUDE.md" && pass "scaffolded CLAUDE.md imports methodology" || fail "scaffolded CLAUDE.md imports methodology"
out=$(sh "$SCRIPTS/scaffold.sh" --target "$S" --layer docs 2>"$ERRF"); rc=$?
check_exit 0 "$rc" "scaffold re-run exits 0"
printf '%s' "$out" | grep -q "skip (exists)" && pass "re-run skips existing files" || fail "re-run skips existing files"

# A docs-only project must protect the exported browser session on its own. Before
# this, .claude/.auth/ was ignored only by the OPTIONAL docusaurus layer, so a
# docs-only repo could commit a session token — permanently, into git history.
check_file_has "$S/.gitignore" '^\.claude/\.auth/$' "docs layer ships a .gitignore ignoring the auth state"
check_file_has "$S/.gitignore" '^\.claude/sources/raw/$' ".gitignore covers the raw payloads"
check_file_has "$S/.gitignore" '^\.claude/sources/\.evidence-log$' ".gitignore covers the evidence log"

# .gitignore is the one file scaffold MERGES rather than skips: a docs-only project
# that later gains Docusaurus must end up with both layers' entries, not just the first.
sh "$SCRIPTS/scaffold.sh" --target "$S" --layer docusaurus >/dev/null 2>"$ERRF"
check_file_has "$S/.gitignore" '^\.claude/\.auth/$' "adding docusaurus keeps the docs-layer entries"
check_file_has "$S/.gitignore" 'node_modules' "adding docusaurus merges in its own entries"
before=$(wc -l <"$S/.gitignore")
sh "$SCRIPTS/scaffold.sh" --target "$S" --layer docusaurus >/dev/null 2>"$ERRF"
if [ "$(wc -l <"$S/.gitignore")" -eq "$before" ]; then
  pass ".gitignore merge is idempotent"
else
  fail ".gitignore merge is idempotent (grew from $before to $(wc -l <"$S/.gitignore"))"
fi

echo "== sync-lore-files.sh (SessionStart) =="
PLUGIN_ROOT="$SCRIPT_DIR/../plugins/lore"
METH_SRC="$PLUGIN_ROOT/templates/docs-layer/.claude/lore-methodology.md"
synchook() { # $1 project root
  OUT=$(printf '{"hook_event_name":"SessionStart","cwd":"%s"}' "$1" |
    CLAUDE_PROJECT_DIR="$1" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" sh "$HOOKS/sync-lore-files.sh" 2>"$ERRF")
  RC=$?
}
# A real Lore project: CLAUDE.md that imports the methodology file, no methodology file yet.
Y=$(mktemp -d); mkdir -p "$Y/.claude"; printf 'x\n@lore-methodology.md\n' >"$Y/.claude/CLAUDE.md"
synchook "$Y"
[ -f "$Y/.claude/lore-methodology.md" ] && pass "missing → created" || fail "missing → created"
cmp -s "$METH_SRC" "$Y/.claude/lore-methodology.md" && pass "created copy matches plugin source" || fail "created copy matches plugin source"
printf '%s' "$OUT" | grep -q 'systemMessage' && pass "emits update notice" || fail "emits update notice"
printf '%s' "$OUT" | (command -v jq >/dev/null 2>&1 && jq . >/dev/null 2>&1 && exit 0 || command -v python3 >/dev/null 2>&1 && python3 -c 'import sys,json;json.load(sys.stdin)' >/dev/null 2>&1) && pass "notice is valid JSON" || fail "notice is valid JSON"
synchook "$Y"
[ -z "$OUT" ] && pass "in-sync → silent no-op" || fail "in-sync → silent no-op (got output)"
printf 'stale\n' >"$Y/.claude/lore-methodology.md"
synchook "$Y"
cmp -s "$METH_SRC" "$Y/.claude/lore-methodology.md" && pass "stale → overwritten with plugin version" || fail "stale → overwritten"
# Guard: CLAUDE.md present but does NOT import the methodology file → hook must do nothing.
N=$(mktemp -d); mkdir -p "$N/.claude"; printf 'no import here\n' >"$N/.claude/CLAUDE.md"
synchook "$N"
[ ! -f "$N/.claude/lore-methodology.md" ] && [ -z "$OUT" ] && pass "no-import project → untouched" || fail "no-import project → untouched"
# Guard: no CLAUDE.md at all (not a Lore project) → silent, nothing created.
Z=$(mktemp -d)
synchook "$Z"
[ ! -f "$Z/.claude/lore-methodology.md" ] && [ -z "$OUT" ] && pass "non-Lore project → untouched" || fail "non-Lore project → untouched"

echo "== the plugin never imposes its DoD on an unrelated repo =="
# The plugin is installed per user, so every hook also runs in repos that have nothing
# to do with Lore — and plenty of projects keep plain markdown and images under docs/.
# Without a project guard, installing Lore blocked writes there, and blocked every turn
# at Stop, enforcing a Definition of Done their author never adopted.
UR=$(mktemp -d); mkdir -p "$UR/docs"
printf '# Notes\n\nPlain markdown, no frontmatter.\n' >"$UR/docs/notes.md"
printf 'PNG\n' >"$UR/docs/diagram.png"
printf 'We use .claude/ and lore:site-to-doc internally.\n' >"$UR/docs/tooling.md"

posttool "$HOOKS/check-frontmatter.sh" "$UR" "$UR/docs/notes.md"
check_exit 0 "$RC" "unrelated repo: frontmatter rules do not apply"
posttool "$HOOKS/check-image-path.sh" "$UR" "$UR/docs/diagram.png"
check_exit 0 "$RC" "unrelated repo: image-placement rules do not apply"
posttool "$HOOKS/check-no-tooling-refs.sh" "$UR" "$UR/docs/tooling.md"
check_exit 0 "$RC" "unrelated repo: reader-facing rules do not apply"
stophook "$UR" false "sess-ur"
check_exit 0 "$RC" "unrelated repo: Stop is never blocked"

# …and a repo with a .claude/ dir that is simply not a Lore project is equally untouched.
UR2=$(mktemp -d); mkdir -p "$UR2/docs/" "$UR2/.claude"
printf 'my own project instructions\n' >"$UR2/.claude/CLAUDE.md"
printf 'PNG\n' >"$UR2/docs/x.png"
stophook "$UR2" false "sess-ur2"
check_exit 0 "$RC" "a .claude/ dir alone is not a Lore project"

echo "== hooks.json wiring (mirrors the CI check) =="
# git tracks the exec bit, and the suite invokes hooks as `sh <file>` — which does not
# need it. So a chmod-less commit could ship a hook the harness never runs, with the
# whole suite green. Derived from the manifest so a new hook is covered the day it lands.
HJ="$SCRIPT_DIR/../plugins/lore/hooks/hooks.json"
if command -v jq >/dev/null 2>&1; then
  wired=$(jq -r '.hooks | to_entries[] | .value[] | .hooks[] | .command' "$HJ" |
    sed 's#^\${CLAUDE_PLUGIN_ROOT}/hooks/##' | sort -u)
  miss=""
  for h in $wired; do
    [ -f "$HOOKS/$h" ] || miss="$miss $h(missing)"
    [ -x "$HOOKS/$h" ] || miss="$miss $h(not-executable)"
  done
  [ -z "$miss" ] && pass "every hook hooks.json wires up exists and is executable" ||
    fail "every hook hooks.json wires up exists and is executable —$miss"

  n=$(printf '%s\n' "$wired" | grep -c .)
  [ "$n" -ge 9 ] && pass "the wiring check covers all $n wired hooks" ||
    fail "the wiring check covers all wired hooks (found only $n)"
else
  pass "hooks.json wiring check skipped (jq unavailable)"
fi

miss=""
for p in "$HOOKS"/*.sh "$SCRIPTS"/*.sh; do
  [ -x "$p" ] || miss="$miss ${p##*/}"
done
[ -z "$miss" ] && pass "every shipped hook/script is executable" ||
  fail "every shipped hook/script is executable —$miss"

echo
echo "==== $PASS passed, $FAIL failed ===="
rm -f "$ERRF"
[ "$FAIL" -eq 0 ]
