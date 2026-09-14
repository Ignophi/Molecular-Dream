# Molecular Dream web fixes — v2

The PDF source remains `main.tex`. The web build now creates `web.tex` automatically and only changes presentation constructs that are problematic for LaTeXML/ar5iv.

## Fixes in this version

- removes the print `twocolumn` class option for HTML only;
- replaces the `tcolorbox` abstract with a normal flow block;
- replaces the PDF `tocloft` table of contents with a clickable HTML outline;
- uses native LaTeXML footnotes and adds hover/click popovers;
- replaces the print-only `qitem` hanging-box bibliography annotations with web blocks;
- copies `main.bbl` to `web.bbl` so the web-only job name keeps your annotated bibliography reliably;
- removes `clearpage`/page-break remnants from the web build;
- layers `assets/web.css` and `assets/web.js` on top of ar5iv's CSS.

## Files to add/update in the repository

Add:
- `assets/web.css`
- `assets/web.js`
- `scripts/prepare-web.py`
- `scripts/inject-web-assets.py`

Replace:
- `scripts/build-ar5iv.sh`
- `.github/workflows/pages.yml`

You do **not** need to edit `main.tex` for these fixes.
