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
  printf '{"hook_event_name":"Stop","stop_hook_active":%s,"cwd":"%s"}' "$2" "$1" |
    CLAUDE_PROJECT_DIR="$1" sh "$HOOKS/verify-docs.sh" 2>"$ERRF"
  RC=$?
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

printf 'no frontmatter\n' >"$P/.claude/CLAUDE.md"
posttool "$HOOKS/check-frontmatter.sh" "$P" "$P/.claude/CLAUDE.md"; check_exit 0 "$RC" "carve-out: .claude/ ignored"

printf 'no frontmatter\n' >"$P/templates/docs-layer/docs/intro.md"
posttool "$HOOKS/check-frontmatter.sh" "$P" "$P/templates/docs-layer/docs/intro.md"; check_exit 0 "$RC" "carve-out: templates/ ignored"

printf 'no frontmatter\n' >"$P/docs/page.mdx"
posttool "$HOOKS/check-frontmatter.sh" "$P" "$P/docs/page.mdx"; check_exit 2 "$RC" ".mdx in scope blocks"

# Issue 1 regression: project root path itself contains a /docs/ segment.
PD=$(mktemp -d)/docs/proj
mkdir -p "$PD"
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
V=$(mktemp -d); mkdir -p "$V/docs" "$V/static/img/s"
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

echo
echo "==== $PASS passed, $FAIL failed ===="
rm -f "$ERRF"
[ "$FAIL" -eq 0 ]
