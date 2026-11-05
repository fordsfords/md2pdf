# CLAUDE.md

Guidance for Claude when maintaining this repository.

## Project

`md2html.sh` converts markdown to HTML: an embedded python3 program
(heredoc) uses the `markdown_it` module (markdown-it-py, plus
`mdit_py_plugins`). `md2pdf.sh` calls `md2html.sh` (found next to itself,
else on PATH) to write a temp HTML file, then a headless
chromium-compatible browser prints it to PDF. The HTML generation code
lives only in `md2html.sh`; don't duplicate it.
Repo: git@github.com:fordsfords/md2pdf.git (branch `main`).

Files:
* `md2pdf.sh` - markdown to PDF.
* `md2html.sh` - markdown to HTML (also used by `md2pdf.sh`).
* `tst.sh` - self-test of both scripts.
* `README.md` - user documentation.
* `LICENSE` - CC0.

## Git permissions

You have full permission to `git add`, `git commit`, and `git push` to
`origin main` in this repo without asking first. Commit after each
coherent, tested change with a clear message. Do not force-push or
rewrite published history.

## Maintenance rules

* Keep each tool a self-contained bash script; avoid new dependencies
beyond bash, python3 + `markdown_it` + `mdit_py_plugins`, and a
chromium-compatible browser. Dependencies must be installable with apt;
the user cannot use pip on WSL/Ubuntu. Code must work with the Ubuntu
22.04 packages (markdown-it-py 1.1.0, mdit-py-plugins 0.3.0).
* Rendering should match GitHub as closely as practical (the user's
markdown lives on GitHub). Heading `id`s must match GitHub's so mdtoc
links resolve.
* Keep the `usage()` text in each script and the Usage section of
`README.md` identical. Update README when options, dependencies, or
behavior change.
* The script must keep working both on native Linux (chromium) and under
WSL with a Windows browser (`*.exe`), which needs Windows paths via
`wslpath -w` (see `winpath()`). The PDF is written to a temp name next
to the HTML and then moved, so the Windows browser never needs to reach
an arbitrary output path.
* The intermediate HTML lives in the input file's directory so that
relative image links resolve; make sure it is cleaned up (trap) unless
`-k` is given.
* Match existing style: 2-space indent, `getopts` option parsing, error
messages prefixed with `md2pdf.sh:` on stderr, non-zero exit on failure.

## Testing

Before committing, run `./tst.sh`; it must report 0 failures. It covers
output files, `-c`/`-k`/`-o`, error exits, temp-file cleanup, GitHub
heading ids, PDF text (if `pdftotext` is installed), and that each
`usage()` text appears in README. Add checks to `tst.sh` when adding
options or behavior.

Visually check the PDF (e.g. `pdftoppm -png -r 50 -f 1 -l 1 x.pdf p` and
view the image) when changing CSS or browser flags. Confirm no stray
`.md2pdf.*` temp files are left behind.
