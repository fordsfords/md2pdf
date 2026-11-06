#!/bin/bash
# md2html.sh - convert a markdown file to HTML.
# Uses python's "markdown_it" module (CommonMark plus GitHub extensions).
# Also used by md2pdf.sh to make its intermediate HTML.
# See https://github.com/fordsfords/md2pdf

usage() {
  cat <<__EOF__ 1>&2
Usage: md2html.sh [-h] [-l] [-c css_file] [-o out.html] in.md
Where:
  -h : print help.
  -l : rewrite relative links to .md files to .html (see README).
  -c css_file : use css_file instead of the built-in style sheet.
  -o out.html : output file (default: in.md with .md replaced by .html).
  in.md : input markdown file.
__EOF__
  exit 1
}

OUT_FILE=""
CSS_FILE=""
LINK_REWRITE=0
while getopts "hlc:o:" OPTION; do
  case $OPTION in
    h) usage ;;
    l) LINK_REWRITE=1 ;;
    c) CSS_FILE="$OPTARG" ;;
    o) OUT_FILE="$OPTARG" ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

if [ $# -ne 1 ]; then usage; fi
IN_FILE="$1"
if [ ! -r "$IN_FILE" ]; then echo "md2html.sh: cannot read '$IN_FILE'" 1>&2; exit 1; fi
if [ -n "$CSS_FILE" -a ! -r "$CSS_FILE" ]; then echo "md2html.sh: cannot read '$CSS_FILE'" 1>&2; exit 1; fi
if [ -z "$OUT_FILE" ]; then OUT_FILE="${IN_FILE%.md}.html"; fi

python3 - "$IN_FILE" "$OUT_FILE" "$CSS_FILE" "$LINK_REWRITE" <<'__EOF__'
import sys, html
from urllib.parse import urlsplit, urlunsplit
try:
    from markdown_it import MarkdownIt
    from mdit_py_plugins.anchors import anchors_plugin
    from mdit_py_plugins.footnote import footnote_plugin
    from mdit_py_plugins.tasklists import tasklists_plugin
except ImportError:
    sys.exit("md2html.sh: python 'markdown_it' or 'mdit_py_plugins' module not found; "
             "try 'sudo apt install python3-markdown-it python3-mdit-py-plugins'")

in_file, html_file, css_file, link_rewrite = sys.argv[1:5]

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
.contains-task-list { list-style: none; padding-left: 1.2em; }
.footnotes { font-size: 90%; }
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

# Approximate GitHub: CommonMark + tables, strikethrough, task lists,
# footnotes, and GitHub-style heading anchors.
md = (MarkdownIt("commonmark")
      .enable(["table", "strikethrough"])
      .use(anchors_plugin, max_level=6)
      .use(footnote_plugin)
      .use(tasklists_plugin))
env = {}
tokens = md.parse(md_text, env)

# -l: rewrite relative markdown links to .md files so they point to .html
# (keeping any #fragment or ?query). Absolute URLs and raw HTML <a> tags
# are left alone; authors use those to keep a link to a .md file as-is.
def rewrite_links(tokens):
    for tok in tokens:
        if tok.type == "link_open":
            href = tok.attrGet("href")
            if href:
                u = urlsplit(href)
                if not u.scheme and not u.netloc and u.path.lower().endswith(".md"):
                    tok.attrSet("href", urlunsplit(u._replace(path=u.path[:-3] + ".html")))
        if tok.children:
            rewrite_links(tok.children)
if link_rewrite == "1":
    rewrite_links(tokens)

body = md.renderer.render(tokens, md.options, env)
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
