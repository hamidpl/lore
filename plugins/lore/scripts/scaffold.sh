#!/bin/sh
# scaffold.sh — copy Lore template layers into a target project directory.
# Self-locating: finds its own plugin root via the script path, so it does NOT
# depend on ${CLAUDE_PLUGIN_ROOT} being present in the shell environment.
#
# Usage:
#   scaffold.sh --target <dir> --layer docs [--layer docusaurus] [--layer rtl]
#
# Layers:
#   docs        templates/docs-layer/      → .claude/, docs/, docs-template/
#   docusaurus  templates/docusaurus-base/ → overlay only: docusaurus.config.ts,
#               sidebars.ts, src/css/custom.css, .gitignore. The Docusaurus
#               framework itself is fetched fresh via create-docusaurus@latest
#               by /lore:add-docusaurus — it is NOT bundled here.
#   rtl         templates/rtl-assets/      → fonts + custom-rtl.css (RTL languages)
#
# Never overwrites existing files (cp without -f, guarded). Placeholder filling
# is the command's job (the model), not this script. Prints the files it creates.

set -e

# Report which layer was in flight if we die mid-copy. Already-copied files are
# kept (copies never overwrite), so re-running is always safe. The trap captures
# and re-exits with the real status — otherwise the last command in the trap
# would silently become the script's exit code.
current_layer=""
on_exit() {
  status=$?
  [ "$status" -ne 0 ] && [ -n "$current_layer" ] &&
    echo "scaffold.sh: FAILED while applying layer '$current_layer' — already-copied files were kept; safe to re-run." >&2
  exit "$status"
}
trap on_exit EXIT

# --- locate plugin root (two levels up from scripts/) ---
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PLUGIN_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
TEMPLATES="$PLUGIN_ROOT/templates"

target="."
layers=""
while [ $# -gt 0 ]; do
  case "$1" in
    --target) target="$2"; shift 2 ;;
    --layer)  layers="$layers $2"; shift 2 ;;
    *) echo "scaffold.sh: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[ -d "$TEMPLATES" ] || { echo "error: templates dir not found at $TEMPLATES" >&2; exit 1; }
mkdir -p "$target"
target=$(cd "$target" && pwd)

# Copy one layer's tree into target without overwriting existing files.
copy_layer() {
  src="$1"
  [ -d "$src" ] || { echo "error: layer source missing: $src" >&2; exit 1; }
  # Walk files; create dirs; copy only if destination doesn't exist.
  find "$src" -type f | while IFS= read -r f; do
    rel="${f#"$src"/}"
    dest="$target/$rel"
    if [ -e "$dest" ]; then
      echo "skip (exists): $rel"
    else
      mkdir -p "$(dirname "$dest")"
      cp "$f" "$dest"
      echo "created: $rel"
    fi
  done
}

for layer in $layers; do
  current_layer="$layer"
  case "$layer" in
    docs)       copy_layer "$TEMPLATES/docs-layer" ;;
    docusaurus) copy_layer "$TEMPLATES/docusaurus-base" ;;
    rtl)        copy_layer "$TEMPLATES/rtl-assets" ;;
    *) echo "scaffold.sh: unknown layer '$layer'" >&2; exit 2 ;;
  esac
done
current_layer=""   # past the copy phase; the EXIT trap must stay quiet now

# Ensure static/img exists when a Docusaurus layer was added.
case " $layers " in
  *" docusaurus "*)
    mkdir -p "$target/static/img"
    [ -e "$target/static/img/.gitkeep" ] || { : > "$target/static/img/.gitkeep"; echo "created: static/img/.gitkeep"; }
    ;;
esac

echo "scaffold.sh: done (layers:$layers)"
