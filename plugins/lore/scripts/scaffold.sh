#!/bin/sh
# scaffold.sh — copy Lore template layers into a target project directory.
# Self-locating: finds its own plugin root via the script path, so it does NOT
# depend on ${CLAUDE_PLUGIN_ROOT} being present in the shell environment.
#
# Usage:
#   scaffold.sh --target <dir> --layer docs [--layer docusaurus] [--layer rtl]
#
# Layers:
#   docs        templates/docs-layer/      → .claude/, docs/, templates/
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

# Argument validation is not ceremony here: this script's whole job is side effects on
# a directory the caller names, and both failure modes below used to be SILENT.
# `--target X` with no --layer printed "done (layers:)" and exited 0, so a wizard step
# that dropped its layer flag reported success over an empty project; `--target` with no
# value died on `shift 2` under `set -e`, with no message at all.
target=""
layers=""
while [ $# -gt 0 ]; do
  case "$1" in
    --target)
      [ $# -ge 2 ] || { echo "scaffold.sh: --target needs a directory" >&2; exit 2; }
      target="$2"; shift 2 ;;
    --layer)
      [ $# -ge 2 ] || { echo "scaffold.sh: --layer needs a layer name (docs|docusaurus|rtl)" >&2; exit 2; }
      # Validated HERE, not in the copy loop below: rejecting it there fired the EXIT
      # trap, so a plain typo reported "FAILED while applying layer 'nonsens' —
      # already-copied files were kept", which describes a partial copy that never began.
      case "$2" in
        docs|docusaurus|rtl) : ;;
        *) echo "scaffold.sh: unknown layer '$2' (expected docs, docusaurus, or rtl)" >&2; exit 2 ;;
      esac
      layers="$layers $2"; shift 2 ;;
    *) echo "scaffold.sh: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[ -n "$target" ] || target="."
if [ -z "$layers" ]; then
  echo "scaffold.sh: no --layer given, so nothing would be copied." >&2
  echo "Usage: scaffold.sh --target <dir> --layer docs [--layer docusaurus] [--layer rtl]" >&2
  exit 2
fi

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
      # .gitignore is the one additive file: every layer contributes entries, and a
      # docs-only project that later gains Docusaurus must end up with BOTH sets.
      # Skipping it (the rule for every other file) would silently drop a whole
      # layer's ignores — including node_modules/ and the exported auth state.
      # Merging only appends lines that are not already present, so re-running stays
      # idempotent and a user's own entries are never touched.
      if [ "${rel##*/}" = ".gitignore" ]; then
        added=0
        while IFS= read -r ln || [ -n "$ln" ]; do
          case "$ln" in ''|'#'*) continue ;; esac
          grep -qxF "$ln" "$dest" 2>/dev/null && continue
          if [ "$added" -eq 0 ]; then
            printf '\n# --- added by lore scaffold ---\n' >>"$dest"
            added=1
          fi
          printf '%s\n' "$ln" >>"$dest"
        done <"$f"
        if [ "$added" -eq 1 ]; then
          echo "merged: $rel"
        else
          echo "skip (exists): $rel"
        fi
      else
        echo "skip (exists): $rel"
      fi
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
    *) echo "scaffold.sh: unknown layer '$layer'" >&2; exit 2 ;;   # unreachable; see --layer above
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
