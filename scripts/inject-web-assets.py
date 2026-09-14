#!/usr/bin/env python3
from pathlib import Path
import sys

html_path = Path(sys.argv[1] if len(sys.argv) > 1 else '_site/index.html')
html = html_path.read_text(encoding='utf-8')
css = '<link rel="stylesheet" href="web.css">'
js = '<script src="web.js" defer></script>'
if 'href="web.css"' not in html:
    html = html.replace('</head>', f'  {css}\n</head>', 1)
if 'src="web.js"' not in html:
    html = html.replace('</body>', f'  {js}\n</body>', 1)
html_path.write_text(html, encoding='utf-8')
print(f'Injected web.css and web.js into {html_path}')
