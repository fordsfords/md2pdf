#!/bin/bash
# tst.sh - self-test for md2html.sh and md2pdf.sh.
# Run from anywhere; exits non-zero if any test fails.
# Optional: pdftotext (apt package poppler-utils) to check PDF text.
# See https://github.com/fordsfords/md2pdf

TOOL_DIR=$(dirname "$(readlink -f "$0")")
MD2HTML="$TOOL_DIR/md2html.sh"
MD2PDF="$TOOL_DIR/md2pdf.sh"

TST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/md2pdf_tst.XXXXXX") || exit 1
trap 'rm -rf "$TST_DIR"' EXIT

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok:   $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL: $1" 1>&2; }
# check "description" command...  (passes if command succeeds)
check() {
  local DESC="$1"; shift
  if "$@"; then ok "$DESC"; else bad "$DESC"; fi
}
# Passes if the file contains the fixed string.
has() { grep -qF -- "$2" "$1"; }
lacks() { ! has "$@"; }
# Passes if no .md2pdf.* temp files are in the directory.
no_temps() { [ -z "$(ls -A "$1" | grep '^\.md2pdf\.')" ]; }
# Passes if the file is a non-empty PDF.
is_pdf() { [ -s "$1" ] && [ "$(head -c 5 "$1")" = "%PDF-" ]; }

# Test input, in a subdirectory (so -o and relative paths get exercised).
mkdir "$TST_DIR/in"
cat >"$TST_DIR/in/t.md" <<'__EOF__'
# Test Document

## Hello, World!

## Dup Heading

## Dup Heading

Some *emphasis*, **strong**, `code`, and ~~strike~~ text.
A footnote[^1] and a [link](#hello-world).

| Col A | Col B |
|-------|-------|
| a1    | b1    |

- [x] done task
- [ ] open task

```
code block line
```

> quoted text

![alt text](img.png)

[^1]: The footnote text.
__EOF__
printf 'body { color: #123456; }\n' >"$TST_DIR/in/my.css"

echo "=== md2html.sh"

"$MD2HTML" "$TST_DIR/in/t.md"; RC=$?
check "md2html default output exits 0" [ $RC -eq 0 ]
H="$TST_DIR/in/t.html"
check "md2html writes in.html" [ -s "$H" ]
check "html: h1" has "$H" '<h1 id="test-document">Test Document</h1>'
check "html: GitHub-style id" has "$H" '<h2 id="hello-world">Hello, World!</h2>'
check "html: duplicate heading id" has "$H" '<h2 id="dup-heading">'
check "html: duplicate heading id -1" has "$H" '<h2 id="dup-heading-1">'
check "html: emphasis" has "$H" '<em>emphasis</em>'
check "html: strong" has "$H" '<strong>strong</strong>'
check "html: inline code" has "$H" '<code>code</code>'
check "html: strikethrough" has "$H" '<s>strike</s>'
check "html: table" has "$H" '<th>Col A</th>'
check "html: task list" has "$H" 'task-list-item'
check "html: checked task" has "$H" 'checked'
check "html: footnote" has "$H" 'The footnote text.'
check "html: code block" has "$H" 'code block line'
check "html: blockquote" has "$H" '<blockquote>'
check "html: image" has "$H" '<img src="img.png" alt="alt text"'
check "html: internal link" has "$H" '<a href="#hello-world">link</a>'
check "html: built-in css" has "$H" 'border-collapse'
check "html: default title" has "$H" "<title>$TST_DIR/in/t.md</title>"

"$MD2HTML" -t 'My <Doc> & "Co"' -o "$TST_DIR/t.html" "$TST_DIR/in/t.md"; RC=$?
check "md2html -t exits 0" [ $RC -eq 0 ]
check "md2html -t sets escaped title" has "$TST_DIR/t.html" '<title>My &lt;Doc&gt; &amp; &quot;Co&quot;</title>'

"$MD2HTML" -c "$TST_DIR/in/my.css" -o "$TST_DIR/c.html" "$TST_DIR/in/t.md"; RC=$?
check "md2html -c -o exits 0" [ $RC -eq 0 ]
check "md2html -o writes named file" [ -s "$TST_DIR/c.html" ]
check "md2html -c uses css file" has "$TST_DIR/c.html" '#123456'
check "md2html -c replaces built-in css" lacks "$TST_DIR/c.html" 'border-collapse'

cat >"$TST_DIR/in/l.md" <<'__EOF__'
[a](other.md) [b](../d/other.md#setup) [c](other.MD?x=1)
[d](https://example.com/other.md) <a href="raw.md">e</a>
[f](other.txt) [g][ref] [h](#local)

[ref]: refd.md
__EOF__
"$MD2HTML" "$TST_DIR/in/l.md"; RC=$?
check "md2html without -l exits 0" [ $RC -eq 0 ]
check "no -l: .md link unchanged" has "$TST_DIR/in/l.html" '<a href="other.md">a</a>'
"$MD2HTML" -l "$TST_DIR/in/l.md"; RC=$?
L="$TST_DIR/in/l.html"
check "md2html -l exits 0" [ $RC -eq 0 ]
check "-l: rewrites .md link" has "$L" '<a href="other.html">a</a>'
check "-l: keeps path and fragment" has "$L" '<a href="../d/other.html#setup">b</a>'
check "-l: .MD and query" has "$L" '<a href="other.html?x=1">c</a>'
check "-l: absolute URL unchanged" has "$L" '<a href="https://example.com/other.md">d</a>'
check "-l: raw html unchanged" has "$L" '<a href="raw.md">e</a>'
check "-l: non-.md link unchanged" has "$L" '<a href="other.txt">f</a>'
check "-l: reference link" has "$L" '<a href="refd.html">g</a>'
check "-l: local anchor unchanged" has "$L" '<a href="#local">h</a>'

"$MD2HTML" "$TST_DIR/nonexistent.md" 2>"$TST_DIR/err"; RC=$?
check "md2html missing input exits 1" [ $RC -eq 1 ]
check "md2html missing input message" has "$TST_DIR/err" "md2html.sh: cannot read"
"$MD2HTML" -c "$TST_DIR/none.css" "$TST_DIR/in/t.md" 2>"$TST_DIR/err"; RC=$?
check "md2html missing css exits 1" [ $RC -eq 1 ]
check "md2html missing css message" has "$TST_DIR/err" "md2html.sh: cannot read"
"$MD2HTML" 2>/dev/null; RC=$?
check "md2html no args exits 1" [ $RC -eq 1 ]

echo "=== md2pdf.sh"

rm -f "$TST_DIR/in/t.html"
"$MD2PDF" -k "$TST_DIR/in/t.md"; RC=$?
check "md2pdf -k exits 0" [ $RC -eq 0 ]
check "md2pdf writes in.pdf" is_pdf "$TST_DIR/in/t.pdf"
check "md2pdf -k keeps in.html" [ -s "$TST_DIR/in/t.html" ]
check "md2pdf leaves no temp files" no_temps "$TST_DIR/in"
if command -v pdftotext >/dev/null 2>&1; then
  pdftotext "$TST_DIR/in/t.pdf" "$TST_DIR/t.txt"
  check "pdf: heading text" has "$TST_DIR/t.txt" "Hello, World!"
  check "pdf: table text" has "$TST_DIR/t.txt" "Col A"
  check "pdf: footnote text" has "$TST_DIR/t.txt" "The footnote text."
  # The browser's header/footer would show the title (in.md) and URL.
  check "pdf: no browser header" lacks "$TST_DIR/t.txt" "t.md"
  check "pdf: no browser footer" lacks "$TST_DIR/t.txt" ".md2pdf."
else
  echo "skip: pdf text checks (pdftotext not installed)"
fi

# Run from the input directory with a relative name (as most users do).
rm -f "$TST_DIR/in/t.pdf" "$TST_DIR/in/t.html"
(cd "$TST_DIR/in" && "$MD2PDF" t.md); RC=$?
check "md2pdf relative input exits 0" [ $RC -eq 0 ]
check "md2pdf relative input writes pdf" is_pdf "$TST_DIR/in/t.pdf"
check "md2pdf without -k removes html" [ ! -e "$TST_DIR/in/t.html" ]
check "md2pdf leaves no temp files (relative)" no_temps "$TST_DIR/in"

mkdir "$TST_DIR/out"
"$MD2PDF" -c "$TST_DIR/in/my.css" -k -o "$TST_DIR/out/x.pdf" "$TST_DIR/in/t.md"; RC=$?
check "md2pdf -c -k -o exits 0" [ $RC -eq 0 ]
check "md2pdf -o writes named file" is_pdf "$TST_DIR/out/x.pdf"
check "md2pdf -k -o keeps html next to pdf" [ -s "$TST_DIR/out/x.html" ]
check "md2pdf -c uses css file" has "$TST_DIR/out/x.html" '#123456'
check "md2pdf default title" has "$TST_DIR/out/x.html" "<title>$TST_DIR/in/t.md</title>"
check "md2pdf leaves no temp files (-o)" no_temps "$TST_DIR/in"

"$MD2PDF" -k -t "PDF Title Test" -o "$TST_DIR/out/y.pdf" "$TST_DIR/in/t.md"; RC=$?
check "md2pdf -t exits 0" [ $RC -eq 0 ]
check "md2pdf -t sets html title" has "$TST_DIR/out/y.html" '<title>PDF Title Test</title>'
if command -v pdfinfo >/dev/null 2>&1; then
  pdfinfo "$TST_DIR/out/y.pdf" >"$TST_DIR/info"
  check "md2pdf -t sets pdf title" has "$TST_DIR/info" "PDF Title Test"
else
  echo "skip: pdf title check (pdfinfo not installed)"
fi

"$MD2PDF" "$TST_DIR/nonexistent.md" 2>"$TST_DIR/err"; RC=$?
check "md2pdf missing input exits 1" [ $RC -eq 1 ]
check "md2pdf missing input message" has "$TST_DIR/err" "md2pdf.sh: cannot read"
"$MD2PDF" -c "$TST_DIR/none.css" "$TST_DIR/in/t.md" 2>"$TST_DIR/err"; RC=$?
check "md2pdf missing css exits 1" [ $RC -eq 1 ]
check "md2pdf missing css message" has "$TST_DIR/err" "md2pdf.sh: cannot read"
"$MD2PDF" 2>/dev/null; RC=$?
check "md2pdf no args exits 1" [ $RC -eq 1 ]

rm -f "$TST_DIR/in/t.pdf"
MD2PDF_BROWSER="$TST_DIR/no_such_browser" "$MD2PDF" "$TST_DIR/in/t.md" 2>"$TST_DIR/err"; RC=$?
check "md2pdf bad browser exits 1" [ $RC -eq 1 ]
check "md2pdf bad browser message" has "$TST_DIR/err" "md2pdf.sh: browser"
check "md2pdf bad browser writes no pdf" [ ! -e "$TST_DIR/in/t.pdf" ]
check "md2pdf bad browser leaves no temp files" no_temps "$TST_DIR/in"

echo "=== documentation"

# The usage() text must appear verbatim in README.md.
readme_has_usage() {
  "$1" -h 2>"$TST_DIR/usage"
  python3 - "$TST_DIR/usage" "$TOOL_DIR/README.md" <<'__EOF__'
import sys
usage = open(sys.argv[1]).read()
readme = open(sys.argv[2]).read()
sys.exit(0 if "```\n" + usage + "```\n" in readme else 1)
__EOF__
}
check "README has md2html.sh usage" readme_has_usage "$MD2HTML"
check "README has md2pdf.sh usage" readme_has_usage "$MD2PDF"

echo "=== $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
