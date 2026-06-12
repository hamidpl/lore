#!/bin/sh
# Scaffold smoke test — replays the real consumer path end to end and asserts a
# green Docusaurus build. Builds an RTL project so the relative @font-face URLs
# (Vazirmatn) are exercised through webpack. Needs Node 20+ and network (npm).
#
# Usage: sh tests/smoke-build.sh [target-dir]
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PLUGIN_ROOT=$(cd "$SCRIPT_DIR/../plugins/lore" && pwd)
PROJ="${1:-$(mktemp -d)/proj}"
mkdir -p "$PROJ"
echo "smoke-build: project at $PROJ"

# 1. Docs layer.
sh "$PLUGIN_ROOT/scripts/scaffold.sh" --target "$PROJ" --layer docs >/dev/null

cd "$PROJ"

# 2. Fetch the latest Docusaurus into a temp dir.
rm -rf .lore-tmp
npx --yes create-docusaurus@latest .lore-tmp/site classic --typescript --skip-install

# 3. Discard the samples Lore replaces, then move the framework in (no overwrite).
rm -rf .lore-tmp/site/docs .lore-tmp/site/blog \
       .lore-tmp/site/src/pages .lore-tmp/site/src/components .lore-tmp/site/src/css/custom.css \
       .lore-tmp/site/static/img \
       .lore-tmp/site/sidebars.ts .lore-tmp/site/docusaurus.config.ts \
       .lore-tmp/site/README.md .lore-tmp/site/.gitignore
( cd .lore-tmp/site && find . -type f ) | while IFS= read -r rel; do
  rel="${rel#./}"
  if [ ! -e "./$rel" ]; then
    mkdir -p "$(dirname "./$rel")"
    mv ".lore-tmp/site/$rel" "./$rel"
  fi
done
rm -rf .lore-tmp

# 4. Overlay Lore's config/styling + RTL assets (RTL build exercises the fonts).
sh "$PLUGIN_ROOT/scripts/scaffold.sh" --target "$PROJ" --layer docusaurus --layer rtl >/dev/null

# 5. Fill placeholders (RTL/Persian) and enable the RTL stylesheet.
cfg=docusaurus.config.ts
sed -i.bak \
  -e "s/{{SITE_TITLE}}/Smoke Docs/g" \
  -e "s/{{SITE_TAGLINE}}/Scaffold smoke test/g" \
  -e "s/{{ORG}}/testorg/g" \
  -e "s/{{PROJECT_SLUG}}/smoke-docs/g" \
  -e "s/{{COPYRIGHT}}/Copyright Smoke/g" \
  -e "s/{{LOCALE}}/fa/g" \
  -e "s/{{LANG_LABEL}}/Farsi/g" \
  -e "s/{{DIRECTION}}/rtl/g" \
  -e "s/{{HTML_LANG}}/fa-IR/g" \
  "$cfg"
sed -i.bak "s#customCss: \['./src/css/custom.css'\]#customCss: ['./src/css/custom.css', './src/css/custom-rtl.css']#" "$cfg"
rm -f "$cfg.bak"

# Guard: docs/ must never contain {{...}} — MDX would evaluate it as JS and fail.
# (Comment-only {{...}} guidance in config/sidebars/custom.css is intentional and
# harmless; the npm build below is the authoritative check for the active config.)
if grep -RIl '{{' docs 2>/dev/null | grep -q .; then
  echo "smoke-build: FAILED — {{...}} found under docs/ (breaks MDX)" >&2
  exit 1
fi

# 6. Install and build.
npm install
npm run build

echo "smoke-build: OK (green production build, RTL fonts resolved)"
