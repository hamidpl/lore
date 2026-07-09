#!/bin/sh
# Stop hook — integrity checks before a turn ends.
#
# Checks 1 (image files under docs/) and 2 (/static/img/ references) are BLOCKING
# (exit 2): on Stop this prevents Claude from stopping and feeds stderr back so it
# fixes the violation. Check 3 (orphan images) stays a non-fatal WARNING — it is
# heuristic and a full `npm run build` is the authoritative check (run it in CI).
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

[ "$blocked" -eq 1 ] && exit 2

# 3) Orphan images (WARNING only): files in static/img/ referenced by no doc,
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
