# The Molecular Dream — web version

This repository contains the LaTeX source for **The Molecular Dream** and an automated GitHub Pages build that converts the manuscript to ar5iv-style HTML with [ar5ivist](https://github.com/dginev/ar5ivist) / LaTeXML.

## Publish on GitHub Pages

1. Create a GitHub repository (for example, `molecular-dream`).
2. Put these files on the repository's `main` branch.
3. In GitHub, open **Settings → Pages**.
4. Under **Build and deployment → Source**, select **GitHub Actions**.
5. Push to `main` (or run the workflow manually from the Actions tab).

The workflow builds `_site/index.html` with the current ar5ivist Docker image pinned in `.github/workflows/pages.yml` and deploys `_site` to GitHub Pages.

For a repository named `molecular-dream` under the `Ignophi` account, the expected URL is:

`https://ignophi.github.io/molecular-dream/`

## Build locally

Docker is the only requirement:

```bash
./scripts/build-ar5iv.sh
```

Then serve `_site` with any local HTTP server, for example:

```bash
python3 -m http.server 8000 -d _site
```

and open `http://localhost:8000/`.

## Source layout

- `main.tex` — manuscript
- `references.bib` — BibTeX database
- `main.bbl` — pre-generated bibliography used as a robust fallback
- `figures/` — manuscript figures
- `.github/workflows/pages.yml` — automatic HTML build and GitHub Pages deployment
- `scripts/build-ar5iv.sh` — equivalent local ar5ivist build

## Notes specific to this manuscript

The source uses the standard `article` class and common scientific packages. The HTML conversion should preserve the manuscript structure, figures, citations, footnotes, hyperlinks, and mathematics. PDF-only styling such as page geometry, two-column layout, headers, fonts, and some `titlesec`/`tocloft` details are intentionally not expected to map one-for-one to HTML; the ar5iv stylesheet supplies the web presentation instead.

The custom `tcolorbox` summary and `\qitem` reference-quotation macro are the two manuscript-specific features worth checking after the first ar5ivist build. A local TeX4ht test converted both successfully, so they are not expected to be fundamental blockers.
