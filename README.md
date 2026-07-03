# optimize-pdf

Shrink an image-heavy PDF for fast loading on phones.

It recompresses every image to **standard JPEG (DCTEncode)** — which phones
decode in hardware — instead of JPEG2000, then **linearizes** the file for
"Fast Web View" so the first page renders before the whole file downloads.

## Requirements

```sh
brew install ghostscript qpdf
```

## Usage

```sh
./optimize-pdf.sh input.pdf                 # → input-compressed.pdf
./optimize-pdf.sh input.pdf output.pdf      # custom output name
```

## Options (environment variables)

| Variable        | Default | Purpose                                                        |
|-----------------|---------|----------------------------------------------------------------|
| `DPI`           | `150`   | Image resolution. Lower = smaller file, higher = more detail.  |
| `QUALITY`       | `ebook` | Ghostscript preset: `screen`, `ebook`, `printer`, `prepress`.  |
| `EDIT_PASSWORD` | *(off)* | Owner password: locks **editing**, viewing/printing stay open. |

```sh
DPI=120 ./optimize-pdf.sh big.pdf small.pdf        # smaller / more compression
DPI=200 QUALITY=printer ./optimize-pdf.sh in.pdf   # higher quality / larger
EDIT_PASSWORD='s3cret' ./optimize-pdf.sh in.pdf    # lock editing, open viewing
```

### About `EDIT_PASSWORD`

This is an **owner** password (AES-256), **not** a viewing password:

- Anyone can open, view, and print the PDF with **no password**.
- Editing, modifying, or reassembling it requires the password.

## Notes

- Defaults (`DPI=150 QUALITY=ebook`) gave a ~78% size reduction on the
  Mallorca guide (334 MB → 73 MB) with no visible quality loss.
- The original file is never modified; output is always a separate file.
- To run it from anywhere, move `optimize-pdf.sh` onto your `PATH`
  (e.g. `~/bin` or `/usr/local/bin`).
