#!/usr/bin/env bash
set -euo pipefail

mkdir -p _site

docker run --rm \
  -v "$PWD":/docdir \
  -w /docdir \
  --user "$(id -u):$(id -g)" \
  latexml/ar5ivist:2512.17 \
  --source=main.tex \
  --destination=_site/index.html

mkdir -p _site/figures
cp -f figures/* _site/figures/
touch _site/.nojekyll

echo "Built _site/index.html"
