#!/bin/bash
# md2pdf.sh - convert a markdown file to PDF.
# Uses python's "markdown" module to make HTML, then headless chromium
# (or Chrome/Edge) to print the HTML to PDF.
# See https://github.com/fordsfords/md2pdf

usage() {
  cat <<__EOF__ 1>&2
Usage: md2pdf.sh [-h] [-k] [-c css_file] [-o out.pdf] in.md
Where:
  -h : print help.
  -k : keep the intermediate HTML file (written next to the PDF).
  -c css_file : use css_file instead of the built-in style sheet.
  -o out.pdf : output file (default: in.md with .md replaced by .pdf).
  in.md : input markdown file.
Environment:
  MD2PDF_BROWSER : path to chromium-compatible browser (overrides search).
__EOF__
  exit 1
}

OUT_FILE=""
CSS_FILE=""
KEEP_HTML=0
while getopts "hkc:o:" OPTION; do
  case $OPTION in
    h) usage ;;
    k) KEEP_HTML=1 ;;
    c) CSS_FILE="$OPTARG" ;;
    o) OUT_FILE="$OPTARG" ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

if [ $# -ne 1 ]; then usage; fi
IN_FILE="$1"
if [ ! -r "$IN_FILE" ]; then echo "md2pdf.sh: cannot read '$IN_FILE'" 1>&2; exit 1; fi
if [ -n "$CSS_FILE" -a ! -r "$CSS_FILE" ]; then echo "md2pdf.sh: cannot read '$CSS_FILE'" 1>&2; exit 1; fi
if [ -z "$OUT_FILE" ]; then OUT_FILE="${IN_FILE%.md}.pdf"; fi

# Find a browser.
BROWSER="$MD2PDF_BROWSER"
if [ -z "$BROWSER" ]; then
  for B in chromium chromium-browser google-chrome google-chrome-stable \
      "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe" \
      "/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe" \
      "/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"; do
    if command -v "$B" >/dev/null 2>&1; then BROWSER="$B"; break; fi
  done
fi
if [ -z "$BROWSER" ]; then
  echo "md2pdf.sh: no chromium-compatible browser found; set MD2PDF_BROWSER" 1>&2
  exit 1
fi

# A Windows browser (under WSL) needs Windows-style paths.
winpath() {
  case "$BROWSER" in
    *.exe) wslpath -w "$1" ;;
    *) echo "$1" ;;
  esac
}

# Write the HTML in the input file's directory so that relative image
# links resolve.
IN_DIR=$(dirname "$IN_FILE")
HTML_FILE="$IN_DIR/.md2pdf.$$.html"
if [ "$KEEP_HTML" -eq 0 ]; then trap 'rm -f "$HTML_FILE"' EXIT; fi

python3 - "$IN_FILE" "$HTML_FILE" "$CSS_FILE" <<'__EOF__'
import sys, html
try:
    import markdown
except ImportError:
    sys.exit("md2pdf.sh: python 'markdown' module not found; try 'pip install markdown'")

in_file, html_file, css_file = sys.argv[1:4]

DEFAULT_CSS = """
body { font-family: -apple-system, "Segoe UI", Helvetica, Arial, sans-serif;
  font-size: 11pt; line-height: 1.5; color: #24292f; max-width: 50em; margin: auto; }
h1, h2 { border-bottom: 1px solid #d0d7de; padding-bottom: .3em; }
code, pre { font-family: Consolas, "DejaVu Sans Mono", monospace; font-size: 90%; }
code { background: #f0f0f0; padding: .1em .3em; border-radius: 3px; }
pre { background: #f6f8fa; padding: .8em; border-radius: 4px;
  white-space: pre-wrap; word-wrap: break-word; }
pre code { background: none; padding: 0; }
table { border-collapse: collapse; }
th, td { border: 1px solid #d0d7de; padding: .3em .7em; }
th { background: #f6f8fa; }
blockquote { color: #57606a; border-left: .25em solid #d0d7de; margin-left: 0; padding-left: 1em; }
img { max-width: 100%; }
pre, table, img, blockquote { page-break-inside: avoid; }
h1, h2, h3, h4 { page-break-after: avoid; }
"""

with open(in_file, encoding="utf-8") as f:
    md_text = f.read()
if css_file:
    with open(css_file, encoding="utf-8") as f:
        css = f.read()
else:
    css = DEFAULT_CSS

body = markdown.markdown(md_text, extensions=["extra", "sane_lists", "toc"])
title = html.escape(in_file)
with open(html_file, "w", encoding="utf-8") as f:
    f.write(f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>{title}</title>
<style>{css}</style></head>
<body>
{body}
</body></html>
""")
__EOF__
if [ $? -ne 0 ]; then exit 1; fi

# Chromium's own path for the HTML must be absolute.
HTML_ABS=$(cd "$IN_DIR" && pwd)/$(basename "$HTML_FILE")
# Write the PDF to a temp name next to the HTML (always reachable by the
# browser), then move it into place.
PDF_TMP="$IN_DIR/.md2pdf.$$.pdf"
rm -f "$PDF_TMP"

"$BROWSER" --headless --disable-gpu --no-pdf-header-footer --print-to-pdf-no-header \
  --print-to-pdf="$(winpath "$(cd "$IN_DIR" && pwd)/$(basename "$PDF_TMP")")" \
  "$(winpath "$HTML_ABS")" >/dev/null 2>&1

if [ ! -s "$PDF_TMP" ]; then
  echo "md2pdf.sh: browser '$BROWSER' failed to create PDF" 1>&2
  rm -f "$PDF_TMP"
  exit 1
fi
mv "$PDF_TMP" "$OUT_FILE" || exit 1

if [ "$KEEP_HTML" -eq 1 ]; then
  mv "$HTML_FILE" "${OUT_FILE%.pdf}.html"
fi
