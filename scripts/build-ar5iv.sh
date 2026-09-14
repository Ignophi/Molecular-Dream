#!/usr/bin/env bash
set -euo pipefail

rm -rf _site
mkdir -p _site

# Create a web-safe LaTeX view without changing the canonical PDF manuscript.
python3 scripts/prepare-web.py main.tex web.tex
cp -f main.bbl web.bbl

docker run --rm \
  -v "$PWD":/docdir \
  -w /docdir \
  --user "$(id -u):$(id -g)" \
  latexml/ar5ivist:2512.17 \
  --source=web.tex \
  --destination=_site/index.html

mkdir -p _site/figures
cp -f figures/* _site/figures/
cp -f assets/web.css assets/web.js _site/
python3 scripts/inject-web-assets.py _site/index.html
touch _site/.nojekyll

echo "Built _site/index.html from web.tex"
