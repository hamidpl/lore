#!/bin/sh
# optimize-images.sh — shrink the PNGs a documentation run produced, in one batch.
#
# WHY THIS EXISTS. Both image sources here are heavy by default: Figma frames are
# exported at `scale=2` (a 1440px frame lands as 2880px), and Playwright screenshots
# are raw PNG. Those files are committed to the documentation repo and served by the
# site, so nothing ever reclaims the weight later.
#
# WHY ONE BATCH, NOT PER IMAGE. Process startup is ~10ms, so per-image spawning costs
# almost nothing in wall-clock. What it does cost is one AGENT TOOL ROUND-TRIP per
# image — 40 images means 40 round-trips instead of one call, which is minutes against
# seconds. Run this once, after every capture in the run has landed.
#
# QUALITY. pngquant is lossy, and the quality FLOOR is the safety property that makes
# that acceptable: given `--quality=min-max`, it exits 99 and leaves the file UNTOUCHED
# when it cannot hold the floor. "Don't damage quality" is therefore enforced by the
# tool, not by anyone's judgement. A lossless pass follows on the result.
#
# IDEMPOTENCE IS CORRECTNESS, NOT SPEED. Repeated lossy passes degrade an image step by
# step. The manifest records the fingerprint of each OPTIMIZED file; a file already in
# it is skipped. A re-captured screenshot has a new fingerprint and is optimized again —
# which is what should happen, since it is a fresh original.
#
# Usage:
#   optimize-images.sh [path …]        # default: static/img
#
# Prints one receipt line for the census / final report, e.g.:
#   RECEIPT optimize-images tool=pngquant+oxipng files=42 skipped=3 before=18874368 after=6291456 saved=67%
#
# Exit codes: 0 ok (INCLUDING "no tool installed" — this never blocks a run)
#             1 usage / refused path
#
# Manifest: .claude/sources/.image-optim  (TAB: fingerprint, path)

set -u

usage() {
  sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 1
}

case "${1:-}" in
  -h|--help) usage ;;
esac

# --- tool ladder, picked once (same shape as the hooks' parser/digest ladders) -------
LOSSY=""
command -v pngquant >/dev/null 2>&1 && LOSSY="pngquant"

LOSSLESS=""
if command -v oxipng >/dev/null 2>&1; then
  LOSSLESS="oxipng"
elif command -v optipng >/dev/null 2>&1; then
  LOSSLESS="optipng"
fi

# The quality floor. Below the minimum pngquant refuses the file rather than degrading
# it; the range is deliberately conservative for UI screenshots (flat colour, sharp
# text), which is what this tool is pointed at.
QUALITY="${LORE_PNG_QUALITY:-65-90}"

tool_label="$LOSSY${LOSSY:+${LOSSLESS:++}}$LOSSLESS"
[ -n "$tool_label" ] || tool_label="none"

# --- fingerprint: sha-256 where available, byte size as the fallback ----------------
_sha=""
if command -v sha256sum >/dev/null 2>&1; then _sha="sha256sum"
elif command -v shasum >/dev/null 2>&1; then _sha="shasum"
elif command -v openssl >/dev/null 2>&1; then _sha="openssl"
fi

bytes_of() { # $1 file → size in bytes, or 0
  wc -c <"$1" 2>/dev/null | tr -d ' ' || echo 0
}

fingerprint() { # $1 file → a stable id for this exact content
  case "$_sha" in
    sha256sum) sha256sum <"$1" 2>/dev/null | awk '{print $1}' ;;
    shasum)    shasum -a 256 <"$1" 2>/dev/null | awk '{print $1}' ;;
    openssl)   openssl dgst -sha256 <"$1" 2>/dev/null | awk '{print $NF}' ;;
    *)         printf 'size:%s' "$(bytes_of "$1")" ;;
  esac
}

# --- targets ------------------------------------------------------------------------
# Default to the one tree images are allowed to live in (Rule 1 / DoD §6).
if [ "$#" -eq 0 ]; then
  set -- static/img
fi

for t in "$@"; do
  # A traversing path is refused outright, like figma-probe.sh's file-key guard: this
  # script rewrites files in place, so it must never be steerable outside its tree.
  case "$t" in
    *..*)
      echo "optimize-images: refusing path containing '..': $t" >&2
      exit 1
      ;;
  esac
  # Images belong under static/img/ and nowhere else, so that is the only tree this
  # touches. A run that points it elsewhere is a mistake worth failing loudly on.
  case "$t" in
    static/img|static/img/*|*/static/img|*/static/img/*) : ;;
    *)
      echo "optimize-images: refusing path outside static/img/: $t" >&2
      echo "  Images live under static/img/ (Rule 1 / DoD §6); nothing else is optimized here." >&2
      exit 1
      ;;
  esac
done

manifest_dir=".claude/sources"
manifest="$manifest_dir/.image-optim"

files=0
skipped=0
before_total=0
after_total=0

tmplist="${TMPDIR:-/tmp}/lore-optim-list.$$"
find "$@" -type f 2>/dev/null >"$tmplist" || true

# Nothing to do at all — still print a receipt, so the caller records a real zero
# rather than assuming (DoD §0.2: a zero is a claim like any other).
if [ ! -s "$tmplist" ]; then
  rm -f "$tmplist" 2>/dev/null
  echo "RECEIPT optimize-images tool=$tool_label files=0 skipped=0 before=0 after=0 saved=0%"
  exit 0
fi

if [ "$tool_label" = "none" ]; then
  # NEVER pretend. A run with no optimizer installed reports exactly that, and says
  # how to fix it — it does not fail, and it does not claim images were optimized.
  n=$(grep -c . "$tmplist" 2>/dev/null || echo 0)
  b=0
  while IFS= read -r f; do
    b=$((b + $(bytes_of "$f")))
  done <"$tmplist"
  rm -f "$tmplist" 2>/dev/null
  echo "RECEIPT optimize-images tool=none files=0 skipped=$n before=$b after=$b saved=0%"
  echo "optimize-images: no image optimizer found — images were left untouched." >&2
  echo "  Install one to enable this step: 'brew install pngquant oxipng' (macOS) or 'apt-get install pngquant' (Debian/Ubuntu)." >&2
  exit 0
fi

while IFS= read -r f; do
  [ -f "$f" ] || continue

  # PNG only. Everything else is counted as skipped and reported, never silently
  # ignored — a JPEG nobody optimized should be visible in the receipt.
  case "$f" in
    *.png|*.PNG) : ;;
    *) skipped=$((skipped + 1)); continue ;;
  esac

  fp=$(fingerprint "$f")
  if [ -n "$fp" ] && [ -f "$manifest" ] &&
     awk -F'\t' -v k="$fp" '$1 == k { found = 1 } END { exit(found ? 0 : 1) }' "$manifest" 2>/dev/null; then
    # Already optimized, byte for byte. Re-running lossy compression here would
    # degrade it a second time, which is why this check is correctness, not a saving.
    skipped=$((skipped + 1))
    continue
  fi

  before=$(bytes_of "$f")
  [ "$before" -gt 0 ] || { skipped=$((skipped + 1)); continue; }

  # Lossy pass. --skip-if-larger and the quality floor both leave the original in
  # place rather than writing something worse; neither is an error here.
  if [ -n "$LOSSY" ]; then
    pngquant --quality="$QUALITY" --skip-if-larger --strip --force \
      --output "$f" -- "$f" >/dev/null 2>&1 || true
  fi

  # Lossless pass, on whatever the previous step left.
  case "$LOSSLESS" in
    oxipng)  oxipng -o 2 --strip safe -q "$f" >/dev/null 2>&1 || true ;;
    optipng) optipng -quiet -strip all -o2 "$f" >/dev/null 2>&1 || true ;;
  esac

  after=$(bytes_of "$f")
  [ "$after" -gt 0 ] || after=$before

  before_total=$((before_total + before))
  after_total=$((after_total + after))
  files=$((files + 1))

  # Record the fingerprint of the RESULT, so the next run skips it.
  newfp=$(fingerprint "$f")
  if [ -n "$newfp" ]; then
    mkdir -p "$manifest_dir" 2>/dev/null &&
      printf '%s\t%s\n' "$newfp" "$f" >>"$manifest" 2>/dev/null || true
  fi
done <"$tmplist"

rm -f "$tmplist" 2>/dev/null

saved=0
if [ "$before_total" -gt 0 ]; then
  saved=$(( (before_total - after_total) * 100 / before_total ))
fi

echo "RECEIPT optimize-images tool=$tool_label files=$files skipped=$skipped before=$before_total after=$after_total saved=$saved%"
exit 0
