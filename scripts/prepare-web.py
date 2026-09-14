#!/usr/bin/env python3
from pathlib import Path
import re
import sys

src_path = Path(sys.argv[1] if len(sys.argv) > 1 else 'main.tex')
out_path = Path(sys.argv[2] if len(sys.argv) > 2 else 'web.tex')
text = src_path.read_text(encoding='utf-8')
original = text

def require_replace(old: str, new: str, label: str):
    global text
    if old not in text:
        raise SystemExit(f'prepare-web.py: expected {label} not found; source layout may have changed')
    text = text.replace(old, new, 1)

# Web pages should be continuous-flow. The print document's twocolumn option is
# the main cause of LaTeXML trying to preserve page/column geometry in HTML.
require_replace(
    r'\documentclass[twocolumn]{article}',
    '\\documentclass{article}\n\\usepackage{latexml}',
    'two-column documentclass',
)

# Let LaTeXML use its native footnote and TOC handling. These packages are useful
# for the PDF, but their low-level layout redefinitions are counterproductive in HTML.
text = text.replace(r'\usepackage[hang, multiple]{footmisc}', '% web build: footmisc omitted')
text = text.replace(r'\usepackage{tocloft}', '% web build: tocloft omitted')

# Strip the PDF-only footnote rule/size/number formatting block.
text, n = re.subn(
    r'% Redefine the footnote rule.*?% Customize the reference to figures',
    '% web build: native LaTeXML footnotes\n\n% Customize the reference to figures',
    text,
    count=1,
    flags=re.S,
)
if n != 1:
    raise SystemExit('prepare-web.py: footnote customization block not found')

# Strip tocloft-specific TOC formatting; we build a clickable HTML outline in web.js.
text, n = re.subn(
    r'% Customizing the Table of Contents.*?% Redefine autoref name format for tables',
    '% web build: TOC generated from HTML headings\n\n% Redefine autoref name format for tables',
    text,
    count=1,
    flags=re.S,
)
if n != 1:
    raise SystemExit('prepare-web.py: TOC customization block not found')

# Replace the print-oriented qitem definition (hangindent + makebox + tiny font)
# with a semantic LaTeXML class. This keeps the [a], [b], ... annotations attached
# to their quotes and lets CSS handle indentation and typography.
text, n = re.subn(
    r'\\makeatletter\s*\\newcommand\{\\qitem\}\[2\]\{%.*?\\makeatother',
    lambda m: '''\\newcommand{\\qitem}[2]{%
  \\par\\noindent
  \\lxWithClass{web-ref-annotation}{\\textbf{[#1]}\\ \\textit{#2}}%
  \\par
}''',
    text,
    count=1,
    flags=re.S,
)
if n != 1:
    raise SystemExit('prepare-web.py: qitem definition not found')

# The tcolorbox conversion preserves print box geometry too literally and can create
# a huge empty region. For web output use a normal quote block with a semantic class.
text, n = re.subn(
    r'\\tcbset\{.*?\}\s*\n\s*\\begin\{tcolorbox\}',
    lambda m: '''\\begin{quote}
\\lxAddClass{web-abstract}''',
    text,
    count=1,
    flags=re.S,
)
if n != 1:
    raise SystemExit('prepare-web.py: abstract tcolorbox start not found')
require_replace(r'\end{tcolorbox}', r'\end{quote}', 'abstract tcolorbox end')

# In HTML, a clickable outline is more useful than PDF page numbers. web.js fills this marker.
require_replace(
    r'\tableofcontents',
    r'\par\medskip\noindent\lxWithClass{web-toc-placeholder}{\textbf{Contents}}\par\medskip',
    'table of contents',
)

# Page-clearing instructions have no semantic value in continuous HTML and can leave gaps.
text = text.replace(r'\clearpage', '% web build: clearpage omitted')
text = text.replace(r'\newpage', '% web build: newpage omitted')
text = text.replace(r'\FloatBarrier', '% web build: FloatBarrier omitted')

out_path.write_text(text, encoding='utf-8')
print(f'Prepared {out_path} from {src_path} ({len(original):,} -> {len(text):,} chars)')
