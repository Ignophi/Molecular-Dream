document.addEventListener('DOMContentLoaded', () => {
  // Article-level metadata used by the right rail and citation dialog.
  const WEB_LINKS = [
    { label: 'Preprint', href: 'https://www.preprints.org/manuscript/202609.1165' },
    { label: 'GitHub', href: 'https://github.com/Ignophi/Molecular-Dream' }
  ];

  const RELATED_ARTICLES = [
    {
      title: 'House of Clocks: On the Misuse of Ageing Composite Measures',
      date: '28 May 2025',
      venue: 'bioRxiv',
      href: 'https://www.biorxiv.org/content/10.1101/2025.05.24.655934v1'
    }
  ];

  const CITATION = {
    doi: '10.20944/preprints202609.1165.v1',
    official: 'Hu, I. The Molecular Dream. Preprints 2026, 2026091165. https://doi.org/10.20944/preprints202609.1165.v1',
    apa: 'Hu, I. (2026). The Molecular Dream. Preprints. https://doi.org/10.20944/preprints202609.1165.v1',
    bibtex: `@article{Hu2026MolecularDream,
  author  = {Hu, Ignophi},
  title   = {The Molecular Dream},
  journal = {Preprints},
  year    = {2026},
  number  = {2026091165},
  doi     = {10.20944/preprints202609.1165.v1},
  url     = {https://doi.org/10.20944/preprints202609.1165.v1}
}`
  };

  // Optional privacy-friendly traffic statistics. Create a GoatCounter site and
  // put only its short site code here (for example: 'molecular-dream'). Leave
  // blank to disable analytics and hide the public Visits counter.
  const GOATCOUNTER_CODE = '';

  const THEME_KEY = 'molecular-dream-theme';
  const themeButtons = [];

  const currentTheme = () => document.documentElement.dataset.webTheme || 'light';
  const updateThemeButtons = () => {
    const dark = currentTheme() === 'dark';
    themeButtons.forEach(button => {
      button.textContent = dark ? '☀ Light' : '◐ Dark';
      button.setAttribute('aria-label', dark ? 'Switch to light mode' : 'Switch to dark mode');
      button.setAttribute('aria-pressed', String(dark));
    });
  };
  const setTheme = (theme, persist = true) => {
    const normalized = theme === 'dark' ? 'dark' : 'light';
    document.documentElement.dataset.webTheme = normalized;
    document.documentElement.style.colorScheme = normalized;
    if (persist) {
      try { localStorage.setItem(THEME_KEY, normalized); } catch (_) {}
    }
    updateThemeButtons();
  };
  let savedTheme = 'light';
  try { savedTheme = localStorage.getItem(THEME_KEY) || 'light'; } catch (_) {}
  setTheme(savedTheme, false);

  const copyText = async (text, button) => {
    const original = button.textContent;
    try {
      await navigator.clipboard.writeText(text);
      button.textContent = 'Copied';
    } catch (_) {
      const area = document.createElement('textarea');
      area.value = text;
      area.style.position = 'fixed';
      area.style.opacity = '0';
      document.body.appendChild(area);
      area.select();
      document.execCommand('copy');
      area.remove();
      button.textContent = 'Copied';
    }
    window.setTimeout(() => { button.textContent = original; }, 1200);
  };

  let citationModal = null;
  const ensureCitationModal = () => {
    if (citationModal) return citationModal;

    const overlay = document.createElement('div');
    overlay.className = 'web-cite-overlay';
    overlay.hidden = true;

    const modal = document.createElement('section');
    modal.className = 'web-cite-modal';
    modal.setAttribute('role', 'dialog');
    modal.setAttribute('aria-modal', 'true');
    modal.setAttribute('aria-labelledby', 'web-cite-title');

    const head = document.createElement('div');
    head.className = 'web-cite-head';
    const heading = document.createElement('h2');
    heading.id = 'web-cite-title';
    heading.textContent = 'Cite this preprint';
    const close = document.createElement('button');
    close.type = 'button';
    close.className = 'web-cite-close';
    close.setAttribute('aria-label', 'Close citation dialog');
    close.textContent = '×';
    head.append(heading, close);

    const body = document.createElement('div');
    body.className = 'web-cite-body';
    const formats = [
      ['Preprints / ACS', CITATION.official, false],
      ['APA', CITATION.apa, false],
      ['BibTeX', CITATION.bibtex, true]
    ];
    formats.forEach(([label, text, code]) => {
      const card = document.createElement('div');
      card.className = 'web-cite-card';
      const row = document.createElement('div');
      row.className = 'web-cite-card-head';
      const name = document.createElement('strong');
      name.textContent = label;
      const copy = document.createElement('button');
      copy.type = 'button';
      copy.className = 'web-cite-copy';
      copy.textContent = 'Copy';
      copy.addEventListener('click', () => copyText(text, copy));
      row.append(name, copy);
      const value = document.createElement(code ? 'pre' : 'p');
      value.className = code ? 'web-cite-value web-cite-code' : 'web-cite-value';
      value.textContent = text;
      card.append(row, value);
      body.appendChild(card);
    });

    modal.append(head, body);
    overlay.appendChild(modal);
    document.body.appendChild(overlay);

    const hide = () => {
      overlay.hidden = true;
      document.body.classList.remove('web-modal-open');
    };
    const show = () => {
      overlay.hidden = false;
      document.body.classList.add('web-modal-open');
      close.focus();
    };
    close.addEventListener('click', hide);
    overlay.addEventListener('click', ev => { if (ev.target === overlay) hide(); });
    document.addEventListener('keydown', ev => {
      if (ev.key === 'Escape' && !overlay.hidden) hide();
    });

    citationModal = { overlay, show, hide };
    return citationModal;
  };

  const makeRelatedArticles = (extraClass = '') => {
    const section = document.createElement('section');
    section.className = `web-related ${extraClass}`.trim();

    const heading = document.createElement('div');
    heading.className = 'web-related-heading';
    heading.textContent = 'Related Articles';
    section.appendChild(heading);

    RELATED_ARTICLES.forEach(article => {
      const link = document.createElement('a');
      link.className = 'web-related-item';
      link.href = article.href;
      link.target = '_blank';
      link.rel = 'noopener noreferrer';

      const title = document.createElement('span');
      title.className = 'web-related-title';
      title.textContent = article.title;
      const meta = document.createElement('span');
      meta.className = 'web-related-meta';
      meta.textContent = `${article.date} · ${article.venue}`;
      link.append(title, meta);
      section.appendChild(link);
    });
    return section;
  };

  const visitCountTargets = [];
  const setupAnalytics = () => {
    const code = GOATCOUNTER_CODE.trim();
    if (!code) return;

    const script = document.createElement('script');
    script.async = true;
    script.src = 'https://gc.zgo.at/count.js';
    script.dataset.goatcounter = `https://${code}.goatcounter.com/count`;
    document.head.appendChild(script);

    const updateCount = () => {
      const path = location.pathname;
      fetch(`https://${code}.goatcounter.com/counter/${encodeURIComponent(path)}.json`)
        .then(response => response.ok ? response.json() : Promise.reject(response))
        .then(data => {
          visitCountTargets.forEach(el => { el.textContent = data.count || '—'; });
        })
        .catch(() => {
          visitCountTargets.forEach(el => { el.textContent = '—'; });
        });
    };
    script.addEventListener('load', () => window.setTimeout(updateCount, 700));
  };

  const makeTools = (extraClass = '') => {
    const tools = document.createElement('div');
    tools.className = `web-right-tools ${extraClass}`.trim();

    const links = document.createElement('div');
    links.className = 'web-resource-links';
    WEB_LINKS.filter(item => item.href).forEach(item => {
      const a = document.createElement('a');
      a.className = 'web-tool-link';
      a.href = item.href;
      a.target = '_blank';
      a.rel = 'noopener noreferrer';
      a.textContent = `${item.label} ↗`;
      links.appendChild(a);
    });

    const cite = document.createElement('button');
    cite.type = 'button';
    cite.className = 'web-tool-link web-cite-button';
    cite.textContent = 'Cite';
    cite.addEventListener('click', () => ensureCitationModal().show());
    links.appendChild(cite);

    const theme = document.createElement('button');
    theme.type = 'button';
    theme.className = 'web-theme-toggle';
    theme.addEventListener('click', () => {
      setTheme(currentTheme() === 'dark' ? 'light' : 'dark');
    });
    themeButtons.push(theme);

    if (links.childElementCount) tools.appendChild(links);
    tools.appendChild(theme);

    if (GOATCOUNTER_CODE.trim()) {
      const visits = document.createElement('div');
      visits.className = 'web-visit-stat';
      const label = document.createElement('span');
      label.textContent = 'Visits';
      const value = document.createElement('strong');
      value.textContent = '…';
      visitCountTargets.push(value);
      visits.append(label, value);
      tools.appendChild(visits);
    }

    updateThemeButtons();
    return tools;
  };

  const paper = document.querySelector('article.ltx_document, .ltx_document');
  const placeholder = document.querySelector('.web-toc-placeholder');
  let marginNotePanel = null;
  let marginNoteLabel = null;

  if (paper) {
    // The source deliberately has a numbered `\section{References}`, while
    // LaTeXML also emits an internal bibliography title. Keep the numbered
    // section and suppress the redundant internal heading in both the paper
    // and the navigation.
    const explicitReferenceHeading = [...paper.querySelectorAll('section.ltx_section > .ltx_title')]
      .find(h => h.textContent.replace(/\s+/g, ' ').trim().replace(/^\d+(?:\.\d+)*\.?\s*/, '').toLowerCase() === 'references');
    const bibliography = paper.querySelector('.ltx_bibliography');
    const bibliographyTitle = bibliography?.querySelector(':scope > .ltx_title');
    if (explicitReferenceHeading && bibliographyTitle) {
      bibliographyTitle.classList.add('web-bib-internal-title');
      bibliographyTitle.setAttribute('aria-hidden', 'true');
    }

    // Rebuild each bibliography entry into two semantic layers:
    //   [n]  normal bibliographic citation in one flowing paragraph
    //        [a] compact annotated quote
    //        [b] compact annotated quote
    // The source .bbl uses \newblock, which LaTeXML renders as separate
    // blocks; that is useful for parsing but visually too fragmented here.
    if (bibliography) {
      const items = [...bibliography.querySelectorAll('.ltx_bibitem')];
      items.forEach((item, index) => {
        if (item.classList.contains('web-bibitem')) return;
        item.classList.add('web-bibitem');

        let tag = item.querySelector(':scope > .ltx_tag_bibitem, :scope > .ltx_tag');
        if (!tag) {
          tag = document.createElement('span');
          item.insertBefore(tag, item.firstChild);
        }
        tag.classList.add('web-ref-number');
        tag.textContent = `[${index + 1}]`;

        const directBlocks = [...item.children].filter(el => el.classList.contains('ltx_bibblock'));

        if (directBlocks.length) {
          const main = document.createElement('div');
          main.className = 'web-ref-main';
          const notes = document.createElement('div');
          notes.className = 'web-ref-notes';
          let visiblePart = 0;
          let annotationCount = 0;

          directBlocks.forEach(block => {
            const markers = [...block.querySelectorAll('.web-ref-annotation')];

            // LaTeXML's \lxWithClass annotates the first generated node. In this
            // macro that means the class may land on the [a]/[b]/[c] marker only,
            // while the italic quote is a following sibling. Treat any bibblock
            // containing one of those markers as an annotation block, and rebuild
            // each qitem from the DOM range between consecutive markers.
            if (markers.length) {
              markers.forEach((marker, markerIndex) => {
                const nextMarker = markers[markerIndex + 1] || null;
                const range = document.createRange();
                range.setStartAfter(marker);
                if (nextMarker) range.setEndBefore(nextMarker);
                else range.setEnd(block, block.childNodes.length);

                const row = document.createElement('div');
                row.className = 'web-ref-annotation';

                const label = document.createElement('span');
                label.className = 'web-ref-annotation-label';
                const rawLabel = marker.textContent.replace(/\s+/g, ' ').trim();
                const labelMatch = rawLabel.match(/\[[^\]]+\]/);
                label.textContent = labelMatch ? labelMatch[0] : rawLabel;

                const quote = document.createElement('span');
                quote.className = 'web-ref-annotation-text';
                quote.appendChild(range.cloneContents());

                // Remove whitespace/punctuation artifacts that belong to TeX's
                // block separation, while preserving the quotation itself.
                while (quote.firstChild && quote.firstChild.nodeType === Node.TEXT_NODE && !quote.firstChild.textContent.trim()) {
                  quote.firstChild.remove();
                }
                const quoteText = quote.textContent.trim();
                if (quoteText) {
                  row.append(label, quote);
                  notes.appendChild(row);
                  annotationCount += 1;
                }
              });
              return;
            }

            // Normal bibliography metadata: authors, title, journal/year. Keep
            // these in one flowing citation rather than one line per \newblock.
            const clone = block.cloneNode(true);
            const usefulText = clone.textContent.replace(/[\s.,;:]+/g, '');
            if (!usefulText) return;

            visiblePart += 1;
            const part = document.createElement('span');
            part.className = 'web-ref-part';
            if (visiblePart === 1) part.classList.add('web-ref-authors');
            else if (visiblePart === 2) part.classList.add('web-ref-title');
            else part.classList.add('web-ref-details');

            while (clone.firstChild) part.appendChild(clone.firstChild);
            main.appendChild(part);
            main.appendChild(document.createTextNode(' '));
          });

          directBlocks.forEach(block => block.remove());
          item.appendChild(main);
          if (annotationCount) item.appendChild(notes);
        }
      });
    }

    const headings = [...paper.querySelectorAll(
      'section.ltx_section > .ltx_title, ' +
      'section.ltx_subsection > .ltx_title, ' +
      'section.ltx_subsubsection > .ltx_title, ' +
      '.ltx_bibliography > .ltx_title'
    )].filter(heading => !heading.classList.contains('web-bib-internal-title'));

    if (headings.length) {
      // Hide the print-era/in-flow Contents marker. It remains in the source only
      // as a stable insertion signal for the web conversion.
      if (placeholder) {
        const markerBlock = placeholder.closest('p, .ltx_para') || placeholder;
        markerBlock.classList.add('web-toc-source');
      }

      // Remove a TOC created by an older copy of web.js if one exists.
      document.querySelectorAll('.web-toc').forEach(el => el.remove());

      const nav = document.createElement('nav');
      nav.className = 'web-toc web-toc-sidebar';
      nav.id = 'web-toc';
      nav.setAttribute('aria-label', 'Article contents');

      const header = document.createElement('div');
      header.className = 'web-toc-header';

      const title = document.createElement('div');
      title.className = 'web-toc-title';
      title.textContent = 'Contents';

      const close = document.createElement('button');
      close.type = 'button';
      close.className = 'web-toc-close';
      close.setAttribute('aria-label', 'Close contents');
      close.textContent = '×';

      header.append(title, close);
      nav.appendChild(header);

      // On tablet/mobile the desktop right rail disappears, so expose the same
      // article links and theme control inside the Contents drawer.
      nav.appendChild(makeTools('web-mobile-tools'));

      const list = document.createElement('ol');
      list.className = 'web-toc-list';

      const sectionLinks = [];
      const mainItems = [];
      let currentMain = null;
      let currentSubsection = null;

      const makeChildrenList = (owner) => {
        let children = owner.querySelector(':scope > .web-toc-children');
        if (!children) {
          children = document.createElement('ol');
          children.className = 'web-toc-children';
          owner.appendChild(children);
        }
        return children;
      };

      const setExpandedMain = (mainLi, expanded, exclusive = true) => {
        if (!mainLi) return;
        if (expanded && exclusive) {
          mainItems.forEach(other => {
            if (other === mainLi) return;
            other.classList.remove('is-expanded');
            const otherButton = other.querySelector(':scope > .web-toc-main-row > .web-toc-expander');
            if (otherButton) otherButton.setAttribute('aria-expanded', 'false');
          });
        }
        mainLi.classList.toggle('is-expanded', expanded);
        const button = mainLi.querySelector(':scope > .web-toc-main-row > .web-toc-expander');
        if (button) button.setAttribute('aria-expanded', String(expanded));
      };

      headings.forEach((heading, i) => {
        const container = heading.parentElement;
        if (!container) return;
        if (!container.id) container.id = `web-section-${i + 1}`;

        let target = container;
        // The numbered References section is only a heading wrapper in the
        // converted DOM; the actual list lives in .ltx_bibliography. Point the
        // sidebar directly at the bibliography so the jump is reliable.
        if (heading === explicitReferenceHeading && bibliography) {
          if (!bibliography.id) bibliography.id = 'web-references';
          target = bibliography;
        }

        let depth = 1;
        if (container.classList.contains('ltx_subsection')) depth = 2;
        if (container.classList.contains('ltx_subsubsection')) depth = 3;

        const li = document.createElement('li');
        li.className = `web-toc-item depth-${depth}`;

        const a = document.createElement('a');
        a.className = 'web-toc-link';
        a.href = `#${target.id}`;
        a.textContent = heading.textContent.replace(/\s+/g, ' ').trim();
        a.dataset.targetId = target.id;

        let mainLi = currentMain;

        if (depth === 1) {
          const row = document.createElement('div');
          row.className = 'web-toc-main-row';

          const expander = document.createElement('button');
          expander.type = 'button';
          expander.className = 'web-toc-expander';
          expander.setAttribute('aria-label', `Show subsections of ${a.textContent}`);
          expander.setAttribute('aria-expanded', 'false');

          row.append(a, expander);
          li.appendChild(row);
          list.appendChild(li);

          currentMain = li;
          currentSubsection = null;
          mainLi = li;
          mainItems.push(li);
        } else if (depth === 2 && currentMain) {
          currentMain.classList.add('has-children');
          makeChildrenList(currentMain).appendChild(li);
          li.appendChild(a);
          currentSubsection = li;
          mainLi = currentMain;
        } else if (depth === 3 && currentMain) {
          currentMain.classList.add('has-children');
          const parent = currentSubsection || currentMain;
          parent.classList.add('has-children');
          makeChildrenList(parent).appendChild(li);
          li.appendChild(a);
          mainLi = currentMain;
        } else {
          // Defensive fallback for malformed hierarchy: keep the entry visible.
          li.appendChild(a);
          list.appendChild(li);
        }

        sectionLinks.push({ container: target, link: a, mainLi, depth });
      });

      mainItems.forEach(mainLi => {
        const expander = mainLi.querySelector(':scope > .web-toc-main-row > .web-toc-expander');
        if (!expander || !mainLi.classList.contains('has-children')) return;
        expander.addEventListener('click', ev => {
          ev.preventDefault();
          ev.stopPropagation();
          setExpandedMain(mainLi, !mainLi.classList.contains('is-expanded'));
        });
      });

      nav.appendChild(list);
      nav.appendChild(makeRelatedArticles('web-mobile-related'));

      // Put the navigation beside the article without rewriting the article itself.
      // The third, equal-width rail keeps the manuscript truly centred and is
      // used for stable desktop footnotes instead of floating popovers.
      const marginRail = document.createElement('aside');
      marginRail.className = 'web-margin-rail';
      marginRail.setAttribute('aria-label', 'Article tools, footnotes, and related articles');

      // Article-level utilities belong in the right rail: they stay visually
      // separate from the document outline and balance the page without
      // competing with the manuscript title.
      marginRail.appendChild(makeTools('web-desktop-tools'));

      const marginHeader = document.createElement('div');
      marginHeader.className = 'web-margin-header';
      marginHeader.textContent = 'Footnotes';

      marginNotePanel = document.createElement('div');
      marginNotePanel.className = 'web-margin-note is-empty';
      marginNotePanel.setAttribute('aria-live', 'polite');
      marginNotePanel.textContent = 'Hover or click a footnote number to read the note here.';

      marginRail.append(marginHeader, marginNotePanel, makeRelatedArticles('web-desktop-related'));

      const shell = document.createElement('div');
      shell.className = 'web-layout';
      paper.parentNode.insertBefore(shell, paper);
      shell.append(nav, paper, marginRail);
      document.body.classList.add('web-has-margin-notes');

      // On narrower screens the same TOC becomes an off-canvas drawer.
      const toggle = document.createElement('button');
      toggle.type = 'button';
      toggle.className = 'web-toc-toggle';
      toggle.setAttribute('aria-controls', 'web-toc');
      toggle.setAttribute('aria-expanded', 'false');
      toggle.textContent = 'Contents';
      document.body.appendChild(toggle);

      const setDrawer = (open) => {
        document.body.classList.toggle('web-toc-open', open);
        toggle.setAttribute('aria-expanded', String(open));
      };

      toggle.addEventListener('click', () => {
        setDrawer(!document.body.classList.contains('web-toc-open'));
      });
      close.addEventListener('click', () => setDrawer(false));

      nav.addEventListener('click', ev => {
        const link = ev.target.closest('.web-toc-link');
        if (!link) return;

        // Explicitly scroll instead of relying solely on fragment navigation.
        // This also works when the URL already contains the same hash (e.g. #S6).
        const target = document.getElementById(link.dataset.targetId);
        const tocEntry = sectionLinks.find(item => item.link === link);
        if (tocEntry?.mainLi) setExpandedMain(tocEntry.mainLi, true);
        if (target) {
          ev.preventDefault();
          target.scrollIntoView({ behavior: 'smooth', block: 'start' });
          history.replaceState(null, '', `#${target.id}`);
        }
        if (window.matchMedia('(max-width: 1360px)').matches) setDrawer(false);
      });

      document.addEventListener('keydown', ev => {
        if (ev.key === 'Escape') setDrawer(false);
      });

      document.addEventListener('click', ev => {
        if (!document.body.classList.contains('web-toc-open')) return;
        if (nav.contains(ev.target) || toggle.contains(ev.target)) return;
        setDrawer(false);
      });

      // Highlight the section currently being read. Only the current main
      // section is expanded, so the rail stays compact while still exposing the
      // local outline around the reader's position.
      let lastExpandedMain = null;
      const keepLinkVisible = (link) => {
        if (!link || !window.matchMedia('(min-width: 1361px)').matches) return;
        const headerHeight = header.offsetHeight;
        const navTop = nav.scrollTop;
        const navBottom = navTop + nav.clientHeight;
        const linkTop = link.offsetTop;
        const linkBottom = linkTop + link.offsetHeight;
        const safeTop = navTop + headerHeight + 10;
        const safeBottom = navBottom - 18;

        if (linkTop < safeTop) {
          nav.scrollTo({ top: Math.max(0, linkTop - headerHeight - 14), behavior: 'smooth' });
        } else if (linkBottom > safeBottom) {
          nav.scrollTo({ top: linkBottom - nav.clientHeight + 20, behavior: 'smooth' });
        }
      };

      const updateActive = () => {
        const y = 110;
        let current = sectionLinks[0];
        for (const item of sectionLinks) {
          const rect = item.container.getBoundingClientRect();
          if (rect.top <= y) current = item;
          else break;
        }

        sectionLinks.forEach(item => {
          item.link.classList.toggle('is-active', item === current);
        });

        if (current?.mainLi && current.mainLi !== lastExpandedMain) {
          setExpandedMain(current.mainLi, true);
          lastExpandedMain = current.mainLi;
        }

        if (current) keepLinkVisible(current.link);
      };

      let ticking = false;
      const requestActiveUpdate = () => {
        if (ticking) return;
        ticking = true;
        requestAnimationFrame(() => {
          updateActive();
          ticking = false;
        });
      };

      updateActive();
      window.addEventListener('scroll', requestActiveUpdate, { passive: true });
      window.addEventListener('resize', requestActiveUpdate, { passive: true });
    }
  }

  // Footnotes: on wide desktop screens the note is rendered in the stable
  // right-hand margin rail. On tablet/mobile we keep the compact popup fallback.
  const renderMarginNote = (note) => {
    if (!marginNotePanel) return;
    const mark = note.querySelector('.ltx_note_mark');
    const source = note.querySelector('.ltx_note_content');
    if (!source) return;

    marginNotePanel.replaceChildren();
    marginNotePanel.classList.remove('is-empty');

    const label = document.createElement('div');
    label.className = 'web-margin-note-label';
    const markText = mark ? mark.textContent.replace(/\s+/g, ' ').trim() : '';
    label.textContent = markText ? `Footnote ${markText}` : 'Footnote';

    const content = document.createElement('div');
    content.className = 'web-margin-note-content';
    const clone = source.cloneNode(true);
    clone.querySelectorAll('.ltx_note_mark, .ltx_tag_note, [id]').forEach(el => {
      if (el.matches('.ltx_note_mark, .ltx_tag_note')) el.remove();
      else el.removeAttribute('id');
    });
    while (clone.firstChild) content.appendChild(clone.firstChild);

    marginNotePanel.append(label, content);
  };

  document.querySelectorAll('.ltx_note').forEach(note => {
    const mark = note.querySelector('.ltx_note_mark');
    if (!mark) return;
    mark.setAttribute('tabindex', '0');
    mark.setAttribute('role', 'button');
    mark.setAttribute('aria-label', `Show footnote ${mark.textContent.trim()}`);

    // Hover/focus previews the note in the margin. We deliberately leave the
    // latest note visible so the reader can move the pointer over and read it.
    note.addEventListener('mouseenter', () => {
      if (window.matchMedia('(min-width: 1361px)').matches) renderMarginNote(note);
    });
    mark.addEventListener('focus', () => {
      if (window.matchMedia('(min-width: 1361px)').matches) renderMarginNote(note);
    });

    const toggle = (ev) => {
      ev.preventDefault();
      ev.stopPropagation();
      document.querySelectorAll('.ltx_note.is-open').forEach(n => {
        if (n !== note) n.classList.remove('is-open');
      });

      if (window.matchMedia('(min-width: 1361px)').matches) {
        note.classList.add('is-open');
        renderMarginNote(note);
      } else {
        note.classList.toggle('is-open');
      }
    };

    mark.addEventListener('click', toggle);
    mark.addEventListener('keydown', ev => {
      if (ev.key === 'Enter' || ev.key === ' ') toggle(ev);
    });
  });

  document.addEventListener('click', () => {
    document.querySelectorAll('.ltx_note.is-open').forEach(n => n.classList.remove('is-open'));
  });

  setupAnalytics();
});
