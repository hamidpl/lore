#!/bin/sh
# Stop hook — fast integrity checks before a turn ends.
# Non-fatal by design: prints warnings so the model notices, but does not hard-block
# the Stop (a full `npm run build` is too slow to run on every Stop; run it manually
# or in CI). To make a check blocking, change its `echo` branch to `exit 2`.

# 1) No image files committed under docs/
bad_imgs=$(find docs -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.gif' -o -name '*.webp' \) 2>/dev/null)
if [ -n "$bad_imgs" ]; then
  echo "WARNING: image files found under docs/ (should be in static/img/):" >&2
  echo "$bad_imgs" >&2
fi

# 2) No markdown image refs using /static/img/
bad_refs=$(grep -rn '](/static/img/' docs/ 2>/dev/null)
if [ -n "$bad_refs" ]; then
  echo "WARNING: markdown references using /static/img/ (use /img/):" >&2
  echo "$bad_refs" >&2
fi

# 3) Orphan images: files in static/img/ referenced by no doc, config, or source file.
#    References come from docs/ (markdown, as /img/...) AND from site config/source
#    (docusaurus.config.ts, sidebars.ts, src/) where assets are written as img/...
#    (no leading slash) — e.g. navbar logo, favicon, social card. Both forms are
#    matched by searching for the substring "img/<relative path>".
if [ -d static/img ]; then
  haystack=$(cat \
    $(find docs -type f -name '*.md' -o -name '*.mdx' 2>/dev/null) \
    docusaurus.config.ts sidebars.ts \
    $(find src -type f 2>/dev/null) \
    2>/dev/null)
  find static/img -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.gif' -o -name '*.webp' -o -name '*.svg' -o -name '*.ico' \) 2>/dev/null | while read -r f; do
    rel="img/${f#static/img/}"
    printf '%s' "$haystack" | grep -qF "$rel" || echo "WARNING: orphan image not referenced anywhere: $f" >&2
  done
fi
