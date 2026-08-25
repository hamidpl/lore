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
  # Line 1 only: the receipt's first line is the v1-compatible ts<TAB>verdict, and the
  # Stop gate reads it with head -n 1 for exactly this reason. Reading the whole file
  # would pick up the format marker and the per-file digest lines below it.
  got=$(head -n 1 "$E/.claude/sources/.validator-receipt" | cut -f2)
  if [ "$got" = "$2" ]; then pass "$3"; else fail "$3 (got '$got', want '$2')"; fi
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

echo "== record-validator-run.sh receipt v2 (scope + digests) =="
# The receipt used to carry only (timestamp, verdict), so a narrow APPROVED — "check
# these two strings" — was indistinguishable from a full one, and the Stop gate could
# only compare mtimes. v2 records WHICH files were judged and the exact content judged.
sha_of() { lore_sha "$1"; }
lore_sha() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum <"$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 <"$1" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then openssl dgst -sha256 <"$1" | awk '{print $NF}'
  fi
}
HAVE_SHA=0
if command -v sha256sum >/dev/null 2>&1 ||
   command -v shasum >/dev/null 2>&1 ||
   command -v openssl >/dev/null 2>&1; then
  HAVE_SHA=1
fi

# Read one receipt field: $1 root, $2 path → "status<TAB>sha", empty when absent.
rcpt_entry() {
  awk -F'\t' -v p="$2" '$1 == "file" && $4 == p { print $2 "\t" $3; exit }' \
    "$1/.claude/sources/.validator-receipt" 2>/dev/null
}
rcpt_status() { rcpt_entry "$1" "$2" | cut -f1; }

if [ "$HAVE_SHA" -eq 1 ]; then
  W=$(mktemp -d); make_lore_project "$W"; mkdir -p "$W/docs" "$W/.claude/sources"
  printf 'page a\n' >"$W/docs/a.md"
  printf 'page b\n' >"$W/docs/b.md"

  subagentstop "$W" '**Files reviewed:** docs/a.md, docs/b.md\n\nRecommendation: APPROVED'
  check_file_has "$W/.claude/sources/.validator-receipt" "format" "receipt carries the v2 format marker"
  [ "$(rcpt_status "$W" docs/a.md)" = "reviewed" ] &&
    pass "a reviewed file is recorded as reviewed" ||
    fail "a reviewed file is recorded as reviewed (got '$(rcpt_status "$W" docs/a.md)')"
  [ "$(rcpt_entry "$W" docs/a.md | cut -f2)" = "$(sha_of "$W/docs/a.md")" ] &&
    pass "the recorded digest is the file's real sha-256" ||
    fail "the recorded digest is the file's real sha-256"

  # The line has to survive the decoration a real report carries around it.
  subagentstop "$W" '# Report\n\n**Files reviewed:** `docs/a.md`, docs/b.md\n\n## Recommendation\n\nAPPROVED'
  [ "$(rcpt_status "$W" docs/b.md)" = "reviewed" ] &&
    pass "a decorated Files reviewed line still parses" ||
    fail "a decorated Files reviewed line still parses (got '$(rcpt_status "$W" docs/b.md)')"

  # A report predating this format asserted a verdict over everything — keep that
  # meaning rather than marking the whole tree uncovered (widen, never block).
  W0=$(mktemp -d); make_lore_project "$W0"; mkdir -p "$W0/docs" "$W0/.claude/sources"
  printf 'page\n' >"$W0/docs/a.md"
  subagentstop "$W0" 'Recommendation: APPROVED'
  [ "$(rcpt_status "$W0" docs/a.md)" = "reviewed" ] &&
    pass "no Files reviewed line → the whole snapshot counts as reviewed (v1 semantics)" ||
    fail "no Files reviewed line → the whole snapshot counts as reviewed"

  # Scoped re-validation: the receipt accumulates, so re-checking one file does not
  # discard the standing coverage of the files that did not change.
  printf 'page b edited\n' >"$W/docs/b.md"
  subagentstop "$W" '**Files reviewed:** docs/b.md\n\nRecommendation: APPROVED'
  [ "$(rcpt_status "$W" docs/b.md)" = "reviewed" ] &&
    pass "scoped round: the re-checked file is reviewed" ||
    fail "scoped round: the re-checked file is reviewed"
  [ "$(rcpt_status "$W" docs/a.md)" = "inherited" ] &&
    pass "scoped round: an unchanged file inherits its green coverage" ||
    fail "scoped round: an unchanged file inherits (got '$(rcpt_status "$W" docs/a.md)')"

  # The hole this closes: a narrow APPROVED must not bless a file it never opened.
  printf 'page a changed behind the review\n' >"$W/docs/a.md"
  subagentstop "$W" '**Files reviewed:** docs/b.md\n\nRecommendation: APPROVED'
  [ "$(rcpt_status "$W" docs/a.md)" = "uncovered" ] &&
    pass "a narrow APPROVED does not bless a file changed outside its scope" ||
    fail "a narrow APPROVED does not bless a file outside its scope (got '$(rcpt_status "$W" docs/a.md)')"

  # A BLOCKED run must not pass coverage forward — inheriting from it would launder it.
  WB=$(mktemp -d); make_lore_project "$WB"; mkdir -p "$WB/docs" "$WB/.claude/sources"
  printf 'page\n' >"$WB/docs/a.md"; printf 'page2\n' >"$WB/docs/b.md"
  subagentstop "$WB" '**Files reviewed:** docs/a.md, docs/b.md\n\nRecommendation: BLOCKED'
  subagentstop "$WB" '**Files reviewed:** docs/b.md\n\nRecommendation: APPROVED'
  [ "$(rcpt_status "$WB" docs/a.md)" = "uncovered" ] &&
    pass "coverage is never inherited from a BLOCKED run" ||
    fail "coverage is never inherited from a BLOCKED run (got '$(rcpt_status "$WB" docs/a.md)')"

  # History is append-only: how many rounds a delivery took is only reconstructible here.
  [ "$(grep -c . "$W/.claude/sources/.validator-history")" -eq 4 ] &&
    pass "every validator run appends one history line" ||
    fail "every validator run appends one history line (got $(grep -c . "$W/.claude/sources/.validator-history"))"
  awk -F'\t' 'NF == 4 { n++ } END { exit(n == NR ? 0 : 1) }' "$W/.claude/sources/.validator-history" &&
    pass "history lines carry ts, verdict and both counts" ||
    fail "history lines carry ts, verdict and both counts"
else
  pass "receipt v2 tests skipped (no sha-256 tool available)"
fi

echo "== verify-docs.sh gate 4 v2 (digest, waiver, scoped rounds) =="
# The complaint this answers: after a green verdict, ANY later touch forced another full
# round — while a genuinely risky bulk edit got exactly the same treatment as a typo fix.
# The gate now compares content, and routes a real change to the user's decision.
gate_project() { # $1 root — a producing session with a complete census and one page
  make_lore_project "$1"; mkdir -p "$1/docs" "$1/.claude/sources"
  printf 'page a\n' >"$1/docs/a.md"
  printf 'sess-w\n' >"$1/.claude/sources/.docs-touched"
  printf '## Run contract\n| u1 | x | satisfied | docs/a.md |\n' >"$1/.claude/sources/brief-w-census.md"
}
waive() { # $1 root, then path… — write a user-approved waiver at each file's CURRENT digest
  r=$1; shift
  { printf '2026-01-01T00:00:00Z\tuser approved: typo fix, no product claim changed\n'
    for p in "$@"; do
      if [ -f "$r/$p" ]; then printf '%s\t%s\n' "$(sha_of "$r/$p")" "$p"
      else printf 'deleted\t%s\n' "$p"; fi
    done
  } >"$r/.claude/sources/.validation-waiver"
}

if [ "$HAVE_SHA" -eq 1 ]; then
  X=$(mktemp -d); gate_project "$X"
  subagentstop "$X" '**Files reviewed:** docs/a.md\n\nRecommendation: APPROVED'
  stophook "$X" false "sess-w"; check_exit 0 "$RC" "a green, unchanged tree passes"

  # THE REGRESSION THIS RELEASE IS ABOUT: a rewrite with identical content bumps the
  # mtime, and the old gate blocked on it — a whole re-validation round for nothing.
  sleep 1; printf 'page a\n' >"$X/docs/a.md"
  stophook "$X" false "sess-w"
  check_exit 0 "$RC" "a rewrite with identical content is not a change (mtime churn)"

  # A one-word edit IS a change, whatever its size — "just a spelling fix" applied
  # tree-wide is what silently falsified 21 pages in the run that produced this rule.
  printf 'page a corrected\n' >"$X/docs/a.md"
  stophook "$X" false "sess-w"; check_exit 2 "$RC" "a content edit after a green run blocks"
  check_stderr "docs/a.md" "the block names the changed file"
  check_stderr "ASK" "…and tells the model to ask the user rather than re-run silently"
  check_stderr "scoped re-validation" "…and offers the scoped round"
  check_stderr "validation-waiver" "…and offers the user-approved waiver"

  # Route 1: the user approves delivering as-is.
  waive "$X" docs/a.md
  stophook "$X" false "sess-w"; check_exit 0 "$RC" "a waiver at the exact current digest passes"

  # …and it covers that content only. A further edit silently invalidates it, which is
  # the whole point: an approval can never extend to a change the user never saw.
  printf 'page a edited again\n' >"$X/docs/a.md"
  stophook "$X" false "sess-w"; check_exit 2 "$RC" "a further edit makes the waiver stale"

  # Route 2: the scoped re-validation closes it instead.
  subagentstop "$X" '**Files reviewed:** docs/a.md\n\nRecommendation: APPROVED'
  stophook "$X" false "sess-w"; check_exit 0 "$RC" "a scoped re-validation closes the change"
  [ ! -f "$X/.claude/sources/.validation-waiver" ] &&
    pass "a validator run consumes the standing waiver" ||
    fail "a validator run consumes the standing waiver"

  # A new page nobody reviewed, and a partial waiver, must both still block.
  printf 'brand new\n' >"$X/docs/new.md"
  stophook "$X" false "sess-w"; check_exit 2 "$RC" "a page created after the run blocks"
  printf 'page a v3\n' >"$X/docs/a.md"
  waive "$X" docs/a.md
  stophook "$X" false "sess-w"; check_exit 2 "$RC" "a waiver covering only one of two changes blocks"

  # A deletion is a change too — the receipt knows a file that is no longer there.
  XD=$(mktemp -d); gate_project "$XD"
  subagentstop "$XD" '**Files reviewed:** docs/a.md\n\nRecommendation: APPROVED'
  rm -f "$XD/docs/a.md"; printf 'other\n' >"$XD/docs/b.md"
  subagentstop "$XD" '**Files reviewed:** docs/b.md\n\nRecommendation: APPROVED'
  rm -f "$XD/docs/b.md"
  stophook "$XD" false "sess-w"; check_exit 2 "$RC" "a file deleted after validation blocks"
  waive "$XD" docs/b.md
  stophook "$XD" false "sess-w"; check_exit 0 "$RC" "a waiver naming the deleted file passes"

  # A waiver can never launder a non-green verdict.
  XR=$(mktemp -d); gate_project "$XR"
  subagentstop "$XR" '**Files reviewed:** docs/a.md\n\nRecommendation: BLOCKED'
  waive "$XR" docs/a.md
  stophook "$XR" false "sess-w"; check_exit 2 "$RC" "a waiver cannot pass a BLOCKED verdict"

  # An `uncovered` file — one a narrow APPROVED never opened — blocks even though its
  # content has not changed since the receipt was written.
  XU=$(mktemp -d); gate_project "$XU"; printf 'page b\n' >"$XU/docs/b.md"
  subagentstop "$XU" '**Files reviewed:** docs/b.md\n\nRecommendation: APPROVED'
  stophook "$XU" false "sess-w"; check_exit 2 "$RC" "a file no run ever reviewed blocks"

  # The circuit-breaker signal: once rounds accumulate, the block says how many.
  XH=$(mktemp -d); gate_project "$XH"
  for _ in 1 2 3; do subagentstop "$XH" '**Files reviewed:** docs/a.md\n\nRecommendation: APPROVED'; done
  printf 'changed\n' >"$XH/docs/a.md"
  stophook "$XH" false "sess-w"
  check_stderr "validator runs recorded" "the block surfaces the round count once rounds pile up"

  # Paths with spaces flow through the digest loop in both directions.
  XS=$(mktemp -d); gate_project "$XS"; printf 'spaced\n' >"$XS/docs/with space.md"
  subagentstop "$XS" 'Recommendation: APPROVED'
  stophook "$XS" false "sess-w"; check_exit 0 "$RC" "a doc filename with a space passes the digest gate"
  printf 'spaced edit\n' >"$XS/docs/with space.md"
  stophook "$XS" false "sess-w"; check_exit 2 "$RC" "…and is caught when it changes"

  # A v1 receipt on disk (written before this upgrade) keeps the mtime behaviour.
  XL=$(mktemp -d); gate_project "$XL"
  printf '2026-01-01T00:00:00Z\tAPPROVED\n' >"$XL/.claude/sources/.validator-receipt"
  stophook "$XL" false "sess-w"; check_exit 0 "$RC" "legacy v1 receipt: unchanged docs pass"
  sleep 1; printf 'edited\n' >"$XL/docs/a.md"
  stophook "$XL" false "sess-w"; check_exit 2 "$RC" "legacy v1 receipt: the mtime path still blocks"
else
  pass "gate 4 v2 tests skipped (no sha-256 tool available)"
fi

# With no digest tool on PATH the recorder must fall back to the v1 receipt and the gate
# to its mtime comparison — degraded, but never crashing and never blocking a clean tree.
XN=$(mktemp -d); gate_project "$XN"
NOSHA=$(mktemp -d)
for t in sh sed grep awk head cut cat tr find ls wc dirname sort date mkdir mv rm printf test; do
  p=$(command -v "$t" 2>/dev/null) && ln -s "$p" "$NOSHA/$t" 2>/dev/null
done
printf '{"hook_event_name":"SubagentStop","cwd":"%s","last_assistant_message":"Recommendation: APPROVED"}' "$XN" |
  PATH="$NOSHA" CLAUDE_PROJECT_DIR="$XN" sh "$HOOKS/record-validator-run.sh" 2>"$ERRF"
check_exit 0 "$?" "no sha tool: the recorder still exits 0"
if grep -q "format" "$XN/.claude/sources/.validator-receipt" 2>/dev/null; then
  fail "no sha tool: falls back to the v1 receipt"
else
  pass "no sha tool: falls back to the v1 receipt"
fi
printf '{"hook_event_name":"Stop","stop_hook_active":false,"cwd":"%s","session_id":"sess-w"}' "$XN" |
  PATH="$NOSHA" CLAUDE_PROJECT_DIR="$XN" sh "$HOOKS/verify-docs.sh" 2>"$ERRF"
check_exit 0 "$?" "no sha tool: the Stop gate degrades to mtime instead of crashing"

echo "== remind-mass-edit.sh (PreToolUse) =="
# The class of damage no output check can see: nothing is mis-typed, every changed line
# is individually correct, and only the sentence around it became false.
M=$(mktemp -d); make_lore_project "$M"; mkdir -p "$M/docs"
printf 'page\n' >"$M/docs/a.md"
mass_edit() { # $1 root, $2 tool, $3 tool_input JSON
  OUT=$(printf '{"hook_event_name":"PreToolUse","cwd":"%s","tool_name":"%s","tool_input":%s}' "$1" "$2" "$3" |
    CLAUDE_PROJECT_DIR="$1" sh "$HOOKS/remind-mass-edit.sh" 2>"$ERRF")
  RC=$?
}
mass_edit "$M" Edit '{"file_path":"'"$M"'/docs/a.md","old_string":"x","new_string":"y","replace_all":true}'
check_exit 0 "$RC" "never blocks a bulk edit"
printf '%s' "$OUT" | grep -q 'additionalContext' &&
  pass "a replace_all on a docs page gets the checklist" ||
  fail "a replace_all on a docs page gets the checklist"
printf '%s' "$OUT" | grep -q 'verbatim' &&
  pass "the checklist names the fidelity-promise check" ||
  fail "the checklist names the fidelity-promise check"

mass_edit "$M" Edit '{"file_path":"'"$M"'/docs/a.md","old_string":"x","new_string":"y"}'
[ -z "$OUT" ] && pass "an ordinary single-occurrence edit is silent" ||
  fail "an ordinary single-occurrence edit is silent"

mass_edit "$M" Bash '{"command":"sed -i \"\" s/x/y/g docs/*.md"}'
printf '%s' "$OUT" | grep -q 'additionalContext' &&
  pass "an in-place sed over docs/ gets the checklist" ||
  fail "an in-place sed over docs/ gets the checklist"
mass_edit "$M" Bash '{"command":"grep -rn video docs/"}'
[ -z "$OUT" ] && pass "a read-only command over docs/ is silent" ||
  fail "a read-only command over docs/ is silent"

# …and it must stay out of repos that never adopted any of this.
MN=$(mktemp -d); mkdir -p "$MN/.claude/../docs"
printf 'not a lore project\n' >"$MN/.claude/CLAUDE.md"
mass_edit "$MN" Edit '{"file_path":"'"$MN"'/docs/a.md","replace_all":true}'
[ -z "$OUT" ] && pass "unrelated repo: no bulk-edit reminder" ||
  fail "unrelated repo: no bulk-edit reminder"

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

# §0.4: a [u#] row is scoped to ONE run and is never re-examined after that run's
# delivery. A standing product decision frozen into one diverges silently the day the
# product owner rules differently — so it must live in the product layer and be
# referenced from the row, not restated in it.
{
  echo '## Run contract'
  echo '| u1 | Standing: the product spells it "video", never "vidéo" | satisfied | docs/a.md |'
} >"$CEN"
posttool "$HOOKS/check-census.sh" "$C" "$CEN"; check_exit 2 "$RC" "a standing decision frozen in a run row blocks"
check_stderr "standing product decision" "…and says where such a decision belongs"

{
  echo '## Run contract'
  echo '| u1 | Standing: product spelling (see CLAUDE.md § Standing decisions, 2026-08-20) | satisfied | docs/a.md |'
} >"$CEN"
posttool "$HOOKS/check-census.sh" "$C" "$CEN"; check_exit 0 "$RC" "a standing row referencing the product layer passes"

{
  echo '## Run contract'
  echo '| u1 | x | satisfied | docs/a.md |'
  echo 'Example of what NOT to write:'
  echo '```markdown'
  echo '| u9 | Standing: some permanent ruling | satisfied | docs/a.md |'
  echo '```'
} >"$CEN"
posttool "$HOOKS/check-census.sh" "$C" "$CEN"; check_exit 0 "$RC" "a fenced standing-row example is not judged as a row"

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

echo "== the edge-case taxonomy is one list, and the skills agree with it =="
# The skills walk the template's taxonomy category by category and name categories in
# their own prose. Nothing checked that those names still exist in the template — which
# is how figma-to-doc came to require a "loading" state the taxonomy did not list.
TPL="$SCRIPT_DIR/../plugins/lore/templates/docs-layer/templates/product-document-template.md"
SK="$SCRIPT_DIR/../plugins/lore/skills"
check_file_has "$TPL" '^## States to Design' "the template carries the canonical States to Design section"
for st in 'specified — needs design' 'unspecified — needs decision + design' 'designed'; do
  check_file_has "$TPL" "$st" "the template defines the '$st' status"
done
# Both producer skills must spell the statuses exactly as the template does — a doc
# whose status column says something else is unparseable by the reviewer's check.
for sk in brief-to-doc figma-to-doc; do
  for st in 'specified — needs design' 'unspecified — needs decision + design'; do
    check_file_has "$SK/$sk/SKILL.md" "$st" "$sk: uses the template's exact '$st' status"
  done
done
# Every taxonomy category a skill names in prose must exist in the template's list.
tax_cats=$(awk '/^\*\*Edge-case coverage taxonomy\*\*/ { inb=1; next }
                inb && /^- \*\*/ { line=$0; sub(/^- \*\*/, "", line); sub(/\*\*.*/, "", line); print tolower(line) }
                inb && /^Mandatory detail/ { exit }' "$TPL")
[ -n "$tax_cats" ] && pass "the taxonomy parses into categories" || fail "the taxonomy parses into categories"
printf '%s\n' "$tax_cats" | grep -q 'loading' &&
  pass "the taxonomy covers loading/latency (the state figma-to-doc requires)" ||
  fail "the taxonomy covers loading/latency — figma-to-doc's missing-states check demands it"
# …and no skill may re-list the taxonomy inline: a local copy is what drifted before.
if grep -qE 'empty, error, loading, and permission-denied' "$SK/figma-to-doc/SKILL.md"; then
  fail "figma-to-doc still carries its own copy of the taxonomy list"
else
  pass "figma-to-doc references the taxonomy instead of copying it"
fi

echo "== optimize-images.sh =="
OI="$SCRIPTS/optimize-images.sh"
[ -f "$OI" ] && pass "optimize-images.sh ships" || fail "optimize-images.sh ships"

# Path guards. This script rewrites files in place, so it must never be steerable out
# of the one tree images are allowed to live in (Rule 1 / §6).
OP=$(mktemp -d); mkdir -p "$OP/static/img/s" "$OP/docs" "$OP/.claude/sources"
( cd "$OP" && sh "$OI" docs >/dev/null 2>"$ERRF" )
check_exit 1 "$?" "a path outside static/img/ is refused"
check_stderr "outside static/img" "…and says why"
( cd "$OP" && sh "$OI" "static/img/../../etc" >/dev/null 2>"$ERRF" )
check_exit 1 "$?" "a traversing path is refused"

# An empty tree still prints a receipt: a zero is a claim like any other (§0.2), and
# "nothing to do" must be visible rather than inferred from silence.
OUT=$( cd "$OP" && sh "$OI" static/img 2>"$ERRF" )
check_exit 0 "$?" "an empty tree exits 0"
printf '%s' "$OUT" | grep -q '^RECEIPT optimize-images ' &&
  pass "an empty tree still prints a receipt" || fail "an empty tree still prints a receipt"

# A non-PNG is counted as skipped and left untouched — never silently ignored.
printf 'not an image\n' >"$OP/static/img/s/notes.txt"
OUT=$( cd "$OP" && sh "$OI" static/img 2>"$ERRF" )
printf '%s' "$OUT" | grep -q 'skipped=1' &&
  pass "a non-PNG is counted as skipped" || fail "a non-PNG is counted as skipped (got: $OUT)"
[ "$(cat "$OP/static/img/s/notes.txt")" = "not an image" ] &&
  pass "…and left untouched" || fail "…and left untouched"

# The receipt must be machine-parsable: the byte fields are plain integers, because the
# skills copy this line into the final report and a human reads the numbers.
printf '%s' "$OUT" | awk '{ for (i=1;i<=NF;i++) if ($i ~ /^(before|after)=/) { split($i,a,"="); if (a[2] !~ /^[0-9]+$/) bad=1 } } END { exit(bad?1:0) }' &&
  pass "receipt byte fields are plain integers" || fail "receipt byte fields are plain integers"

# With no optimizer on PATH the script must say so and change nothing — never claim a
# saving it did not make, and never fail a run over a missing optional binary.
NOOPT=$(mktemp -d)
for t in sh sed grep awk head cut cat tr find ls wc dirname sort mkdir rm printf test mktemp; do
  p=$(command -v "$t" 2>/dev/null) && ln -s "$p" "$NOOPT/$t" 2>/dev/null
done
printf 'PNG-ish bytes\n' >"$OP/static/img/s/a.png"
OUT=$( cd "$OP" && PATH="$NOOPT" sh "$OI" static/img 2>"$ERRF" )
check_exit 0 "$?" "no optimizer installed: still exits 0"
printf '%s' "$OUT" | grep -q 'tool=none' &&
  pass "no optimizer installed: reported as tool=none, not as a saving" ||
  fail "no optimizer installed: reported as tool=none (got: $OUT)"
check_stderr "no image optimizer found" "…and says how to install one"

# The real thing, when a real optimizer exists. Idempotence is the property that
# matters most here: a second lossy pass over the same file degrades it again, so an
# already-optimized file must be skipped, not re-compressed.
if command -v pngquant >/dev/null 2>&1 || command -v oxipng >/dev/null 2>&1 ||
   command -v optipng >/dev/null 2>&1; then
  OUT=$( cd "$OP" && sh "$OI" static/img 2>"$ERRF" )
  printf '%s' "$OUT" | grep -qE 'files=[1-9]' &&
    pass "a real optimizer processes the PNG" || fail "a real optimizer processes the PNG (got: $OUT)"
  OUT2=$( cd "$OP" && sh "$OI" static/img 2>"$ERRF" )
  printf '%s' "$OUT2" | grep -q 'files=0' &&
    pass "re-running skips already-optimized files (no repeated lossy pass)" ||
    fail "re-running skips already-optimized files (got: $OUT2)"
  check_file_has "$OP/.claude/sources/.image-optim" "static/img/s/a.png" "the optimized file is recorded in the manifest"
else
  pass "optimize-images real-run tests skipped (no optimizer installed)"
fi

# The manifest is a run artifact, not something to commit.
check_file_has "$SCRIPT_DIR/../plugins/lore/templates/docs-layer/.gitignore" \
  'image-optim' "the image manifest is git-ignored by the docs layer"

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

# Argument errors must be LOUD. This script exists to have side effects on a directory
# the caller names, so a run that copies nothing and reports success is the worst
# possible outcome: `--target X` with no --layer printed "done (layers:)" and exited 0,
# and `--target` with no value died on `shift 2` with no message at all.
E=$(mktemp -d)
sh "$SCRIPTS/scaffold.sh" --target "$E" >/dev/null 2>"$ERRF"
check_exit 2 "$?" "no --layer is an error, not a silent no-op"
check_stderr "no --layer given" "…and it says which flag is missing"
sh "$SCRIPTS/scaffold.sh" --target >/dev/null 2>"$ERRF"
check_exit 2 "$?" "a dangling --target is rejected"
check_stderr "needs a directory" "…with an actionable message"
sh "$SCRIPTS/scaffold.sh" --target "$E" --layer >/dev/null 2>"$ERRF"
check_exit 2 "$?" "a dangling --layer is rejected"
sh "$SCRIPTS/scaffold.sh" --target "$E" --layer nonsense >/dev/null 2>"$ERRF"
check_exit 2 "$?" "an unknown layer is rejected"

echo "== the generated Docusaurus site is deployable =="
DC="$SCRIPT_DIR/../plugins/lore/templates/docusaurus-base/docusaurus.config.ts"
# `url` is the origin of every canonical link and every sitemap.xml entry. Shipping the
# framework's own example domain meant each generated site advertised a domain nobody
# owns — wrong, and wrong in a way that looks deliberate.
if grep -qE "^[[:space:]]*url:.*your-docusaurus-site" "$DC"; then
  fail "the config template still ships the example deploy URL"
else
  pass "the config template has no placeholder deploy domain"
fi
check_file_has "$DC" '{{SITE_URL}}' "the deploy URL is a filled placeholder"
grep -q "sh#\|{{SITE_URL}}" "$SCRIPT_DIR/smoke-build.sh" &&
  pass "the smoke test substitutes SITE_URL" || fail "the smoke test substitutes SITE_URL"
# DoD §6 names the production build as its authoritative link check; 'warn' gates nothing.
check_file_has "$DC" "onBrokenLinks: 'throw'" "broken links fail the build, as §6 promises"
grep -q "{{SITE_URL}}" "$SCRIPT_DIR/../plugins/lore/commands/add-docusaurus.md" &&
  pass "the wizard is told to fill SITE_URL" || fail "the wizard is told to fill SITE_URL"

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

echo "== each skill's own census skeleton agrees with what the hooks parse =="
# Every assertion in this block reads the SKILL FILE, not a fixture. The defect this
# guards against is the one that shipped (H4): a skill prescribes a census the hooks
# then reject or silently mis-parse. Hand-written fixtures cannot catch it, because they
# are written by whoever wrote the hook — so they agree with it by construction.
SK="$SCRIPT_DIR/../plugins/lore/skills"
# The first fenced block in a skill that contains a Run contract IS its census skeleton.
census_skeleton() { # $1 = SKILL.md
  awk '
    /^```/ {
      if (inb) { if (buf ~ /## Run contract/) { printf "%s", buf; exit } ; inb=0; buf="" }
      else { inb=1; buf="" }
      next
    }
    inb { buf = buf $0 "\n" }
  ' "$1"
}
# Column index of a header cell, counting the way awk -F'|' does (leading pipe → $1="").
col_of() { # $1 = header row, $2 = cell name
  printf '%s\n' "$1" | awk -F'|' -v want="$2" '
    { for (i = 1; i <= NF; i++) { c = $i; gsub(/^[[:space:]]+|[[:space:]]+$/, "", c)
        if (c == want) { print i; exit } } }'
}
for sk in site-to-doc figma-to-doc; do
  sec=$(census_skeleton "$SK/$sk/SKILL.md")
  if [ -z "$sec" ]; then
    fail "$sk: no census skeleton found in the skill"
    continue
  fi
  pass "$sk: the skill carries a census skeleton"

  # §0.4 — check-census.sh greps for this heading at write time.
  printf '%s' "$sec" | grep -q '^##[[:space:]]*Run contract' &&
    pass "$sk: skeleton has the '## Run contract' heading the write-time hook requires" ||
    fail "$sk: skeleton has the '## Run contract' heading the write-time hook requires"

  # verify-docs.sh reads the run-contract status and evidence BY POSITION ($4/$5). A
  # skill that reordered these columns would leave the gate reading the wrong cell — and
  # nothing would look wrong in either file on its own.
  uhdr=$(printf '%s\n' "$sec" | grep -m1 '^|[[:space:]]*ref[[:space:]]*|')
  [ "$(col_of "$uhdr" status)" = "4" ] &&
    pass "$sk: 'status' sits where the Stop gate reads it (\$4)" ||
    fail "$sk: 'status' column moved — Stop gate reads \$4, skeleton has $(col_of "$uhdr" status)"
  [ "$(col_of "$uhdr" evidence)" = "5" ] &&
    pass "$sk: 'evidence' sits where the Stop gate reads it (\$5)" ||
    fail "$sk: 'evidence' column moved — Stop gate reads \$5, skeleton has $(col_of "$uhdr" evidence)"

  # And the ref prefixes the hooks' regexes anchor on.
  printf '%s' "$sec" | grep -qE '^\|[[:space:]]*u[0-9]+[[:space:]]*\|' &&
    pass "$sk: run-contract rows use the [u#] ref the gate matches" ||
    fail "$sk: run-contract rows use the [u#] ref the gate matches"
  printf '%s' "$sec" | grep -qE '^\|[[:space:]]*t[0-9]+[[:space:]]*\|' &&
    pass "$sk: trusted-source rows use the [t#] ref the receipt check matches" ||
    fail "$sk: trusted-source rows use the [t#] ref the receipt check matches"
done

# Per-input-type completeness: check-census.sh --complete looks for these exact blocks.
sec=$(census_skeleton "$SK/site-to-doc/SKILL.md")
printf '%s' "$sec" | grep -q '^##[[:space:]]*Observation coverage' &&
  pass "site-to-doc: skeleton has the '## Observation coverage' block Stop requires" ||
  fail "site-to-doc: skeleton has the '## Observation coverage' block Stop requires"
printf '%s' "$sec" | grep -qE '^\|[[:space:]]*o[0-9]+[[:space:]]*\|' &&
  pass "site-to-doc: observation rows use the [o#] ref Stop matches" ||
  fail "site-to-doc: observation rows use the [o#] ref Stop matches"

sec=$(census_skeleton "$SK/figma-to-doc/SKILL.md")
printf '%s' "$sec" | grep -q '^##[[:space:]]*Counts' &&
  pass "figma-to-doc: skeleton has the '## Counts' block Stop requires" ||
  fail "figma-to-doc: skeleton has the '## Counts' block Stop requires"
chdr=$(printf '%s\n' "$sec" | grep -m1 '^|[[:space:]]*source type[[:space:]]*|')
[ "$(col_of "$chdr" count)" = "3" ] &&
  pass "figma-to-doc: 'count' sits where Stop reads it (\$3)" ||
  fail "figma-to-doc: 'count' column moved — Stop reads \$3, skeleton has $(col_of "$chdr" count)"
# Stop demands a counted row per manifest source type; the skeleton must name them all.
for st in comment annotation flow interaction variant variable; do
  printf '%s' "$sec" | awk -F'|' -v k="$st" 'tolower($2) ~ k { found=1 } END { exit(found?0:1) }' &&
    pass "figma-to-doc: skeleton has a Counts row for '$st'" ||
    fail "figma-to-doc: skeleton has a Counts row for '$st' (Stop blocks without one)"
done

# The zero-case wording is a contract between the skills and check-census.sh's receipt
# check: a phrase the skills teach but the hook does not recognise walks past the gate.
zre='nothing relevant|confirmed searched|confirmed none|inaccessible|requires login|needs login'
for sk in site-to-doc figma-to-doc brief-to-doc; do
  bad=$(grep -oE '(nothing|no) [a-z]+ — confirmed [a-z]+' "$SK/$sk/SKILL.md" | sort -u |
    grep -vE "$zre" || true)
  [ -z "$bad" ] && pass "$sk: every zero-case phrase it teaches is one the hook recognises" ||
    fail "$sk: teaches a zero-case phrase the hook does not recognise — $bad"
done

echo "== a complete, receipted census survives write AND Stop, per input type =="
# The valid half of the corpus: a census with real raw payloads on disk and real
# verified evidence-log entries behind every URL. Everything above this line proves a
# gate BLOCKS; this proves the gates can all be satisfied at once, which is the property
# a user actually needs and the one no single-rule test establishes.
mk_corpus() { # $1 = project root — build the artifacts a receipted census cites
  mkdir -p "$1/.claude/sources/raw" "$1/docs" "$1/static/img/s"
  make_lore_project "$1"
  printf '{"ok":1}\n' >"$1/.claude/sources/raw/t1-help.md"
  printf '{"ok":1}\n' >"$1/.claude/sources/raw/t2-blog.md"
  printf 'x\n'        >"$1/static/img/s/a.png"
  printf 'page\n'     >"$1/docs/a.md"
  printf '%s\tWebFetch\thttps://help.example.test/limits\tverified\n' "2026-01-01T00:00:00Z" \
    >"$1/.claude/sources/.evidence-log"
  printf '%s\tWebFetch\thttps://blog.example.test/posts\tverified\n' "2026-01-01T00:00:01Z" \
    >>"$1/.claude/sources/.evidence-log"
  printf 'sess-corpus\n' >"$1/.claude/sources/.docs-touched"
}
trusted_block() {
  echo '## Trusted Sources (§1) coverage'
  echo '| ref | source → URL | probe | status | bytes | raw payload | terms searched | finding → doc file/section |'
  echo '|---|---|---|---|---|---|---|---|'
  echo '| t1 | Help Center → https://help.example.test/limits | WebFetch | 200 | 4821 | .claude/sources/raw/t1-help.md | "upload limit" | "max 6 GB" → docs/a.md § Business Rules |'
  echo '| t2 | Blog → https://blog.example.test/posts | WebFetch | 200 | 1200 | .claude/sources/raw/t2-blog.md | "upload" | nothing relevant — confirmed searched |'
}
run_contract_block() {
  echo '## Run contract'
  echo '| ref | instruction | status | evidence |'
  echo '|---|---|---|---|'
  echo '| u1 | cover the signed-in state | satisfied | o2 |'
}

CO=$(mktemp -d); mk_corpus "$CO"
{
  run_contract_block; echo
  echo '## Observation coverage'
  echo '| ref | auth state | role | route | viewport | screenshot | snapshot evidence |'
  echo '|---|---|---|---|---|---|---|'
  echo '| o1 | guest | — | /pricing | 1280×720 | static/img/s/a.png | "Sign in" present |'
  echo '| o2 | signed-in | admin | /dash | 1280×720 | static/img/s/a.png | account menu present |'
  echo; trusted_block
} >"$CO/.claude/sources/site-full-census.md"
posttool "$HOOKS/check-census.sh" "$CO" "$CO/.claude/sources/site-full-census.md"
check_exit 0 "$RC" "site: a fully receipted census passes the write-time shape check"
subagentstop "$CO" "Recommendation: APPROVED"
stophook "$CO" false "sess-corpus"
check_exit 0 "$RC" "site: …and passes Stop end to end"

CF=$(mktemp -d); mk_corpus "$CF"
printf '{"ok":1}\n' >"$CF/.claude/sources/raw/figma-nodes.json"
{
  run_contract_block; echo
  echo '## Counts'
  echo '| source type | count | probe | status | bytes | scanned | raw payload |'
  echo '|---|---|---|---|---|---|---|'
  echo '| Comment threads | 3 | GET /comments | 200 | 900 | — | .claude/sources/raw/figma-nodes.json |'
  echo '| Dev-Mode annotations (`annotations` property) | 17 | GET /nodes | 200 | 900 | 400 | .claude/sources/raw/figma-nodes.json |'
  echo '| Prototype flows (`flowStartingPoints`) | 2 | (same) | 200 | 900 | 400 | (same) |'
  echo '| Interaction edges (`interactions[]`) | 31 | (same) | 200 | 900 | 400 | (same) |'
  echo '| Differentiating component variants/properties | 4 | (same) | 200 | 900 | 400 | (same) |'
  echo '| Constraint-bearing variables | 0 | get_variable_defs | 200 | 900 | — | .claude/sources/raw/figma-nodes.json |'
  echo; trusted_block
} >"$CF/.claude/sources/figma-full-census.md"
posttool "$HOOKS/check-census.sh" "$CF" "$CF/.claude/sources/figma-full-census.md"
check_exit 0 "$RC" "figma: a fully receipted census passes the write-time shape check"
subagentstop "$CF" "Recommendation: APPROVED"
stophook "$CF" false "sess-corpus"
check_exit 0 "$RC" "figma: …and passes Stop end to end"

echo "== one defect at a time, against that same valid census =="
# Each variant changes exactly one thing in a census already proven green, so a block
# can only be attributed to the defect introduced. A defect corpus built from separate
# hand-written fixtures cannot make that claim.
defect() { # $1 = sed expression, $2 = name
  D=$(mktemp -d); mk_corpus "$D"
  DC="$D/.claude/sources/site-full-census.md"
  sed "$1" "$CO/.claude/sources/site-full-census.md" >"$DC" 2>"$ERRF"
  # A sed that matched nothing exits 0 and copies the file through — after which the
  # assertion below tests the pristine census and "blocks" would be a lie. Every defect
  # must be proven to have landed before its effect is judged.
  if cmp -s "$DC" "$CO/.claude/sources/site-full-census.md"; then
    fail "$2 (the mutation did not apply — this assertion tested nothing)"
    return
  fi
  posttool "$HOOKS/check-census.sh" "$D" "$DC"
  check_exit 2 "$RC" "$2"
}
defect 's#\.claude/sources/raw/t1-help\.md#.claude/sources/raw/never-saved.md#' \
  "a cited raw payload that was never saved blocks"
defect 's#| WebFetch | 200 | 4821 |#| WebFetch | n/a | 4821 |#' \
  "a trusted-source row with no HTTP status blocks"
defect 's#https://help\.example\.test/limits#https://never-fetched.example.test/x#' \
  "a source with no verified fetch behind it blocks"
defect '/^## Run contract$/d' \
  "a census with no Run contract block blocks"
defect 's#confirmed searched#confirmed searched (corroboration=RAW-HAS-DATA)#' \
  "a zero the raw payload contradicts blocks"

# The control. Same harness, same project, census copied through untouched — if this
# blocked, every assertion above would be meaningless.
D=$(mktemp -d); mk_corpus "$D"
cp "$CO/.claude/sources/site-full-census.md" "$D/.claude/sources/site-full-census.md"
posttool "$HOOKS/check-census.sh" "$D" "$D/.claude/sources/site-full-census.md"
check_exit 0 "$RC" "the unmutated census passes in the same harness (control)"

# The Bash tier, end to end: a URL the model merely greped for is not a fetch.
MT=$(mktemp -d); mk_corpus "$MT"
printf '%s\tBash\thttps://mentioned-only.example.test/x\tmentioned\n' "2026-01-01T00:00:02Z" \
  >>"$MT/.claude/sources/.evidence-log"
sed 's#https://help\.example\.test/limits#https://mentioned-only.example.test/x#' \
  "$CO/.claude/sources/site-full-census.md" >"$MT/.claude/sources/site-full-census.md"
posttool "$HOOKS/check-census.sh" "$MT" "$MT/.claude/sources/site-full-census.md"
check_exit 2 "$RC" "a host logged only as 'mentioned' is not proof the source was read"
printf '%s\tWebFetch\thttps://mentioned-only.example.test/x\tverified\n' "2026-01-01T00:00:03Z" \
  >>"$MT/.claude/sources/.evidence-log"
posttool "$HOOKS/check-census.sh" "$MT" "$MT/.claude/sources/site-full-census.md"
check_exit 0 "$RC" "…and the same census passes once a real fetch is logged"

echo "== lib/common.sh (the shared hook prologue) =="
LIB="$HOOKS/lib/common.sh"
[ -f "$LIB" ] && pass "lib/common.sh ships" || fail "lib/common.sh ships"
# Sourced, never executed — and deliberately outside the hooks/*.sh glob above, so the
# exec-bit rule that applies to runnable hooks must not apply to it.
[ -x "$LIB" ] && fail "lib/common.sh must not be executable (it is sourced)" ||
  pass "lib/common.sh is not executable"

# Every hook must resolve the library through $0, never ${CLAUDE_PLUGIN_ROOT}: hooks.json
# interpolates that variable into the command string, which does not guarantee it reaches
# the hook's environment — so a hook that used it would fail to find its own library.
if grep -l 'CLAUDE_PLUGIN_ROOT.*lib/common\.sh' "$HOOKS"/*.sh >/dev/null 2>&1; then
  fail "a hook resolves lib/common.sh through CLAUDE_PLUGIN_ROOT"
else
  pass "every hook resolves lib/common.sh through \$0"
fi

# A packaging accident that drops the library must degrade, not crash the turn.
NOLIB=$(mktemp -d); cp "$HOOKS/check-frontmatter.sh" "$NOLIB/"
P=$(mktemp -d); make_lore_project "$P"; mkdir -p "$P/docs"
printf 'no frontmatter\n' >"$P/docs/a.md"
printf '{"cwd":"%s","tool_name":"Write","tool_input":{"file_path":"%s"}}' "$P" "$P/docs/a.md" |
  CLAUDE_PROJECT_DIR="$P" sh "$NOLIB/check-frontmatter.sh" 2>"$ERRF"
check_exit 0 "$?" "a hook with no lib/ next to it degrades instead of blocking"
check_stderr "missing" "…and says so on stderr"

# json_field's text fallback — the path taken when neither jq nor python3 exists.
# Exercised directly, because a PATH stripped of both would also strip grep and sed.
jf() { # $1 = key path, $2 = payload
  ( input=$2
    # shellcheck source=/dev/null
    . "$LIB"
    _json_tool=""
    json_field "$1" )
}
dual='{"session_id":"s1","tool_name":"Write","tool_input":{"file_path":"/proj/docs/a.md"},"tool_response":{"file_path":"/proj/OTHER.md"}}'
# The old fallback was `s/.*"file_path"...` — `.*` is greedy, so it returned the LAST
# match in the payload (the tool_response echo) and the `head -n 1` after it was
# decoration. A Write payload carries both, so this returned the wrong file every time.
[ "$(jf 'tool_input file_path' "$dual")" = "/proj/docs/a.md" ] &&
  pass "text fallback honours the key PATH, not the last matching leaf" ||
  fail "text fallback honours the key PATH (got '$(jf 'tool_input file_path' "$dual")')"
[ "$(jf 'session_id' "$dual")" = "s1" ] &&
  pass "text fallback reads a top-level key" || fail "text fallback reads a top-level key"
# stop_hook_active is a JSON boolean. A string-only scan returned empty for it, which
# would have disabled the Stop hook's loop guard on a machine with no JSON parser.
[ "$(jf 'stop_hook_active' '{"stop_hook_active":true,"cwd":"/x"}')" = "true" ] &&
  pass "text fallback reads an unquoted boolean" || fail "text fallback reads an unquoted boolean"
[ -z "$(jf 'tool_input url' "$dual")" ] &&
  pass "text fallback returns empty for an absent key" || fail "text fallback returns empty for an absent key"
# All three backends must agree, or the degraded path is a different program.
jf_with() { # $1 = backend, $2 = key path, $3 = payload
  # shellcheck disable=SC2034  # $input is read by json_field(), per lib/common.sh's contract
  ( input=$3
    # shellcheck source=/dev/null
    . "$LIB"
    _json_tool=$1
    json_field "$2" )
}
if command -v jq >/dev/null 2>&1; then
  agree=$(jf_with jq 'tool_input file_path' "$dual")
  [ "$agree" = "/proj/docs/a.md" ] &&
    pass "the jq backend agrees with the text fallback" ||
    fail "the jq backend agrees with the text fallback (got '$agree')"
fi
if command -v python3 >/dev/null 2>&1; then
  agree=$(jf_with python3 'tool_input file_path' "$dual")
  [ "$agree" = "/proj/docs/a.md" ] &&
    pass "the python3 backend agrees with the text fallback" ||
    fail "the python3 backend agrees with the text fallback (got '$agree')"
  agree=$(jf_with python3 'stop_hook_active' '{"stop_hook_active":true}')
  [ "$agree" = "true" ] && pass "the python3 backend reads a boolean" ||
    fail "the python3 backend reads a boolean (got '$agree')"
fi

echo
echo "==== $PASS passed, $FAIL failed ===="
rm -f "$ERRF"
[ "$FAIL" -eq 0 ]
