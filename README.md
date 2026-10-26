# md2pdf

Convert a markdown file to PDF.

## Introduction

`md2pdf.sh` is a small bash script that converts markdown to PDF in two steps:

1. Python's [markdown-it-py](https://github.com/executablebooks/markdown-it-py)
module (`markdown_it`) converts the markdown to HTML (with a simple,
GitHub-like built-in style sheet).
2. A headless chromium-compatible browser (Chromium, Chrome, or Edge)
"prints" the HTML to PDF.

The intermediate HTML file is written to the same directory as the input
file so that relative image links work. It is deleted afterward unless
`-k` is given.

I wanted something lighter-weight than pandoc that didn't require installing anything more than I already had.

### Dependencies

* bash
* python3 with the `markdown_it` and `mdit_py_plugins` modules.
On Ubuntu/Debian (including WSL):
```
sudo apt install python3-markdown-it python3-mdit-py-plugins
```
(or `pip install markdown-it-py mdit-py-plugins` where pip is allowed).
* A chromium-compatible browser. The script searches for (in order):
`chromium`, `chromium-browser`, `google-chrome`, `google-chrome-stable`,
and, under WSL, Windows Chrome and Edge in their standard install locations.
Set the `MD2PDF_BROWSER` environment variable to override the search.

## Usage

```
Usage: md2pdf.sh [-h] [-k] [-c css_file] [-o out.pdf] in.md
Where:
  -h : print help.
  -k : keep the intermediate HTML file (written next to the PDF).
  -c css_file : use css_file instead of the built-in style sheet.
  -o out.pdf : output file (default: in.md with .md replaced by .pdf).
  in.md : input markdown file.
Environment:
  MD2PDF_BROWSER : path to chromium-compatible browser (overrides search).
```

### Examples

```
md2pdf.sh README.md                 # creates README.pdf
md2pdf.sh -o /tmp/doc.pdf notes.md  # explicit output file
md2pdf.sh -c my.css -k notes.md     # custom style; keep notes.html
MD2PDF_BROWSER=/usr/bin/chromium md2pdf.sh notes.md
```

## Notes

* The goal is output that matches GitHub's rendering. The parser is
CommonMark (the basis of GitHub Flavored Markdown) plus tables,
strikethrough, task lists, footnotes, and heading anchors whose `id`s
follow GitHub's rules, so in-document links (e.g. a table of contents
from [mdtoc](https://github.com/fordsfords/mdtoc)) work in the PDF.
* Bare URLs (e.g. `http://example.com` without `<...>` or `[...](...)`)
are not turned into links, unlike on GitHub. That needs the
`linkify-it-py` module, which is not packaged for Ubuntu 22.04.
* The browser's default page header and footer (date, title, URL,
page numbers) are suppressed.
* Under WSL, a Windows browser is given Windows-style paths
(via `wslpath -w`).

## License

I want there to be NO barriers to using this code, so I am releasing it to the public domain.  But "public domain" does not have an internationally agreed upon definition, so I use CC0:

This work is dedicated to the public domain under CC0 1.0 Universal:
http://creativecommons.org/publicdomain/zero/1.0/

To the extent possible under law, Steven Ford has waived all copyright
and related or neighboring rights to this work. In other words, you can
use this code for any purpose without any restrictions.
This work is published from: United States.
Project home: https://github.com/fordsfords/md2pdf
