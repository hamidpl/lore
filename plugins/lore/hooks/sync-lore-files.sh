#!/bin/sh
# sync-lore-files.sh — keep plugin-owned files in a consumer project up to date.
#
# Runs on SessionStart. For each manifest entry it compares the plugin's copy with the
# project's copy and acts by MODE:
#   owned       → plugin-owned file (e.g. lore-methodology.md): silently overwrite when it
#                 differs (create if missing). The user never edits these.
#   notify-only → user-editable file (e.g. a doc template): NEVER copy; only report that a
#                 newer version exists, so the user can merge by hand.
#
# Silent when everything is already in sync (exit 0, no output). On change it emits JSON:
#   systemMessage      → shown to the USER (a one-line "updated" notice)
#   additionalContext  → shown to the MODEL (so it re-reads a just-synced rules file)
#
# Guard: only touches a project that is a scaffolded Lore docs project — i.e. one whose
# .claude/CLAUDE.md imports lore-methodology.md. In any other repo the hook does nothing.
#
# Path resolution mirrors the other Lore hooks: project root from $CLAUDE_PROJECT_DIR
# (else the payload's cwd); plugin root from $CLAUDE_PLUGIN_ROOT. JSON parsing degrades
# jq → python3 and warns to stderr if neither is present.

PAYLOAD=$(cat 2>/dev/null || true)

# --- resolve project root ---
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$PROJECT_ROOT" ]; then
  if command -v jq >/dev/null 2>&1; then
    PROJECT_ROOT=$(printf '%s' "$PAYLOAD" | jq -r '.cwd // empty' 2>/dev/null)
  elif command -v python3 >/dev/null 2>&1; then
    PROJECT_ROOT=$(printf '%s' "$PAYLOAD" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("cwd",""))' 2>/dev/null)
  else
    echo "sync-lore-files.sh: no jq or python3 to parse the hook payload; skipping sync." >&2
  fi
fi
[ -z "$PROJECT_ROOT" ] && PROJECT_ROOT=$(pwd)

# --- resolve plugin root ---
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -z "$PLUGIN_ROOT" ] && PLUGIN_ROOT=$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)
[ -z "$PLUGIN_ROOT" ] && exit 0

# --- guard: only manage a real Lore project (CLAUDE.md that imports the methodology file) ---
CLAUDE_MD="$PROJECT_ROOT/.claude/CLAUDE.md"
[ -f "$CLAUDE_MD" ] || exit 0
grep -q '@lore-methodology.md' "$CLAUDE_MD" 2>/dev/null || exit 0

# --- manifest: SOURCE_REL|DEST_REL|MODE (extend with more lines; no spaces in paths) ---
MANIFEST="templates/docs-layer/.claude/lore-methodology.md|.claude/lore-methodology.md|owned"

# plugin version (cosmetic, for the user notice); best-effort parse of plugin.json
PLUGIN_JSON="$PLUGIN_ROOT/.claude-plugin/plugin.json"
VER=""
if [ -f "$PLUGIN_JSON" ]; then
  if command -v jq >/dev/null 2>&1; then
    VER=$(jq -r '.version // empty' "$PLUGIN_JSON" 2>/dev/null)
  else
    VER=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PLUGIN_JSON" | head -1)
  fi
fi

UPDATED=""
DRIFT=""

for entry in $MANIFEST; do
  src_rel=${entry%%|*}
  rest=${entry#*|}
  dst_rel=${rest%%|*}
  mode=${rest#*|}
  src="$PLUGIN_ROOT/$src_rel"
  dst="$PROJECT_ROOT/$dst_rel"
  [ -f "$src" ] || continue

  case "$mode" in
    owned)
      if [ ! -f "$dst" ] || ! cmp -s "$src" "$dst"; then
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst" && UPDATED="${UPDATED}${UPDATED:+, }${dst_rel}"
      fi
      ;;
    notify-only)
      if [ -f "$dst" ] && ! cmp -s "$src" "$dst"; then
        DRIFT="${DRIFT}${DRIFT:+, }${dst_rel}"
      fi
      ;;
  esac
done

[ -z "$UPDATED" ] && [ -z "$DRIFT" ] && exit 0

MSG=""
if [ -n "$UPDATED" ]; then
  MSG="Lore: methodology rules synced${VER:+ (plugin v$VER)} → ${UPDATED}. If a rule seems stale in this session, re-read .claude/lore-methodology.md."
fi
if [ -n "$DRIFT" ]; then
  MSG="${MSG}${MSG:+ }Lore: a newer version of ${DRIFT} is available (not auto-applied — you may have edited it); review and merge manually."
fi

# Our messages contain no double-quotes, backslashes, or newlines, so this is JSON-safe.
printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$MSG" "$MSG"
exit 0
