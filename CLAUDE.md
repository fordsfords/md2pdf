# CLAUDE.md

Guidance for Claude when maintaining this repository.

## Project

`md2pdf.sh` is a single bash script that converts markdown to PDF:
an embedded python3 program (heredoc) uses the `markdown_it` module
(markdown-it-py, plus `mdit_py_plugins`) to write an HTML file, then a headless chromium-compatible browser prints it to PDF.
Repo: git@github.com:fordsfords/md2pdf.git (branch `main`).

Files:
* `md2pdf.sh` - the tool.
* `README.md` - user documentation.
* `LICENSE` - CC0.

## Git permissions

You have full permission to `git add`, `git commit`, and `git push` to
`origin main` in this repo without asking first. Commit after each
coherent, tested change with a clear message. Do not force-push or
rewrite published history.

## Maintenance rules

* Keep it a single self-contained bash script; avoid new dependencies
beyond bash, python3 + `markdown_it` + `mdit_py_plugins`, and a
chromium-compatible browser. Dependencies must be installable with apt;
the user cannot use pip on WSL/Ubuntu. Code must work with the Ubuntu
22.04 packages (markdown-it-py 1.1.0, mdit-py-plugins 0.3.0).
* Rendering should match GitHub as closely as practical (the user's
markdown lives on GitHub). Heading `id`s must match GitHub's so mdtoc
links resolve.
* Keep the `usage()` text in `md2pdf.sh` and the Usage section of
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

There is no automated test suite. Before committing, at minimum:

```
./md2pdf.sh -k some.md        # check some.pdf and some.html are produced
./md2pdf.sh -o /tmp/x.pdf some.md
./md2pdf.sh nonexistent.md    # should print an error and exit 1
```

Visually check the PDF (e.g. `pdftoppm -png -r 50 -f 1 -l 1 x.pdf p` and
view the image) when changing CSS or browser flags. Confirm no stray
`.md2pdf.*` temp files are left behind.
