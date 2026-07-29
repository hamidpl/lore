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
  -e "s#{{SITE_URL}}#http://localhost:3000#g" \
  -e "s#{{LORE_ATTRIBUTION}}#Built with <a href=\"https://lorekit.net\">Lore</a>#g" \
  "$cfg"
sed -i.bak "s#customCss: \['./src/css/custom.css'\]#customCss: ['./src/css/custom.css', './src/css/custom-rtl.css']#" "$cfg"
rm -f "$cfg.bak"

# Assert the substitutions actually happened. `sed` that matches nothing exits 0, so
# a renamed placeholder used to sail through and the build still went green — after
# which "OK" was untrue: the site shipped a raw {{TOKEN}} in its footer or title.
leftover=$(grep -o '{{[A-Z_]*}}' "$cfg" | grep -v '{{PLACEHOLDER}}' | sort -u || true)
if [ -n "$leftover" ]; then
  echo "smoke-build: FAILED — unsubstituted placeholders survive in $cfg:" >&2
  echo "$leftover" >&2
  echo "(a placeholder was renamed in the template and this test's sed list did not follow)" >&2
  exit 1
fi
grep -q "custom-rtl.css" "$cfg" || {
  echo "smoke-build: FAILED — the RTL stylesheet was never wired into customCss" >&2
  exit 1
}

# Guard: docs/ must never contain {{...}} — MDX would evaluate it as JS and fail.
# (Comment-only {{...}} guidance in config/sidebars/custom.css is intentional and
# harmless; the npm build below is the authoritative check for the active config.)
if grep -RIl '{{' docs 2>/dev/null | grep -q .; then
  echo "smoke-build: FAILED — {{...}} found under docs/ (breaks MDX)" >&2
  exit 1
fi

# 6. Install and build — running the command file's OWN block, not a copy of it.
#
# This test used to hardcode its own `npm install … && npm run build`. That is the
# same restatement pattern Rule 4 forbids, and it drifted exactly as predicted: the
# command file learned that @docusaurus/theme-mermaid must be installed (the Lore
# config declares that theme, so the build fails without it) while copies elsewhere
# still said plain `npm install`. Extracting the block means the test breaks the day
# the documented command changes, which is the only way a smoke test can honestly
# claim it replays the real consumer path.
CMD_FILE="$PLUGIN_ROOT/commands/add-docusaurus.md"
install_cmd=$(awk '
  /^## Step 6/      { step6 = 1 }
  step6 && /^```bash/ { grab = 1; next }
  grab && /^```/    { exit }
  grab              { print }
' "$CMD_FILE")

if [ -z "$install_cmd" ]; then
  echo "smoke-build: FAILED — could not extract the install command from $CMD_FILE" >&2
  echo "(its Step 6 bash block moved or was renamed; this test must follow it)" >&2
  exit 1
fi
case "$install_cmd" in
  *"npm run build"*) : ;;
  *) echo "smoke-build: FAILED — the extracted block does not build: $install_cmd" >&2; exit 1 ;;
esac

echo "smoke-build: running the documented command: $install_cmd"
eval "$install_cmd"

echo "smoke-build: OK (green production build, RTL fonts resolved, no unsubstituted placeholders)"
