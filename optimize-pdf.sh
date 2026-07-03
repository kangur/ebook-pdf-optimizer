#!/usr/bin/env bash
#
# optimize-pdf.sh — shrink an image-heavy PDF for fast phone loading.
#
# Recompresses images with standard JPEG (DCTEncode, hardware-decoded on
# phones — NOT JPEG2000) at a chosen DPI, then linearizes the result for
# "Fast Web View" so the first page renders before the whole file downloads.
#
# Requires: ghostscript, qpdf  (brew install ghostscript qpdf)
#
# Usage:
#   ./optimize-pdf.sh input.pdf [output.pdf]
#
# Options (environment variables):
#   DPI=150      target image resolution (150 ≈ crisp on-screen, lossless-ish)
#   QUALITY=ebook   ghostscript preset: screen | ebook | printer | prepress
#   EDIT_PASSWORD=...  set an *owner* password. The PDF stays freely
#                      viewable and printable by anyone, but editing/
#                      modifying it requires this password. (This is NOT
#                      a viewing password — leave it unset for no protection.)
#
# Examples:
#   ./optimize-pdf.sh "Mallorca Travel Guide.pdf"
#   DPI=120 ./optimize-pdf.sh big.pdf small.pdf      # smaller / more compression
#   DPI=200 ./optimize-pdf.sh big.pdf                # higher quality / larger
#   EDIT_PASSWORD='s3cret' ./optimize-pdf.sh in.pdf  # lock editing, open viewing

set -euo pipefail

DPI="${DPI:-150}"
QUALITY="${QUALITY:-ebook}"
EDIT_PASSWORD="${EDIT_PASSWORD:-}"

die() { printf 'Error: %s\n' "$1" >&2; exit 1; }

# --- checks ---------------------------------------------------------------
command -v gs   >/dev/null 2>&1 || die "ghostscript not found. Install: brew install ghostscript"
command -v qpdf >/dev/null 2>&1 || die "qpdf not found. Install: brew install qpdf"

[ "$#" -ge 1 ] || die "no input file. Usage: $0 input.pdf [output.pdf]"
INPUT="$1"
[ -f "$INPUT" ] || die "file not found: $INPUT"

# Default output: "<name>-compressed.pdf" next to the input.
if [ "$#" -ge 2 ]; then
  OUTPUT="$2"
else
  dir="$(dirname "$INPUT")"
  base="$(basename "$INPUT")"
  OUTPUT="${dir}/${base%.*}-compressed.pdf"
fi

[ "$(cd "$(dirname "$INPUT")" && pwd)/$(basename "$INPUT")" != \
  "$(cd "$(dirname "$OUTPUT")" 2>/dev/null && pwd || echo x)/$(basename "$OUTPUT")" ] \
  || die "output would overwrite input; choose a different output name"

TMP="$(mktemp -t optpdf).pdf"
trap 'rm -f "$TMP"' EXIT

orig_bytes=$(stat -f%z "$INPUT" 2>/dev/null || stat -c%s "$INPUT")

printf '→ Optimizing "%s"\n' "$INPUT"
printf '  preset=%s  dpi=%s\n' "$QUALITY" "$DPI"
[ -n "$EDIT_PASSWORD" ] && printf '  edit-protection: on (viewing/printing stay open)\n'

# --- 1. recompress images with Ghostscript (DCT / standard JPEG) ----------
gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.5 -dNOPAUSE -dBATCH -dQUIET \
   -dPDFSETTINGS="/$QUALITY" \
   -sOutputFile="$TMP" \
   -dDownsampleColorImages=true -dColorImageResolution="$DPI" -dColorImageDownsampleType=/Bicubic \
   -dDownsampleGrayImages=true  -dGrayImageResolution="$DPI"  -dGrayImageDownsampleType=/Bicubic \
   -dAutoFilterColorImages=false -dColorImageFilter=/DCTEncode \
   -dAutoFilterGrayImages=false  -dGrayImageFilter=/DCTEncode \
   "$INPUT"

# --- 2. linearize for Fast Web View (streams first page early on phones) ---
#        + optional owner password: empty user password = anyone can open/view,
#          non-empty owner password = editing requires the password.
qpdf_args=(--linearize --compress-streams=y --object-streams=generate)
if [ -n "$EDIT_PASSWORD" ]; then
  qpdf_args+=(--encrypt "" "$EDIT_PASSWORD" 256
              --modify=none --print=full --extract=y --)
fi
qpdf "${qpdf_args[@]}" "$TMP" "$OUTPUT"

# --- report ----------------------------------------------------------------
new_bytes=$(stat -f%z "$OUTPUT" 2>/dev/null || stat -c%s "$OUTPUT")
pct=$(awk "BEGIN{printf \"%.1f\", 100-($new_bytes*100/$orig_bytes)}")
omb=$(awk "BEGIN{printf \"%.1f\", $orig_bytes/1048576}")
nmb=$(awk "BEGIN{printf \"%.1f\", $new_bytes/1048576}")

printf '✓ Done: %s\n' "$OUTPUT"
printf '  %s MB → %s MB  (−%s%%)\n' "$omb" "$nmb" "$pct"
