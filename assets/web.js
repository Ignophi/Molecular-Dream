document.addEventListener('DOMContentLoaded', () => {
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

      const list = document.createElement('ol');
      list.className = 'web-toc-list';

      const sectionLinks = [];

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

        li.appendChild(a);
        list.appendChild(li);
        sectionLinks.push({ container: target, link: a });
      });

      nav.appendChild(list);

      // Put the navigation beside the article without rewriting the article itself.
      // The third, equal-width rail keeps the manuscript truly centred and is
      // used for stable desktop footnotes instead of floating popovers.
      const marginRail = document.createElement('aside');
      marginRail.className = 'web-margin-rail';
      marginRail.setAttribute('aria-label', 'Footnotes');

      const marginHeader = document.createElement('div');
      marginHeader.className = 'web-margin-header';
      marginHeader.textContent = 'Footnotes';

      marginNotePanel = document.createElement('div');
      marginNotePanel.className = 'web-margin-note is-empty';
      marginNotePanel.setAttribute('aria-live', 'polite');
      marginNotePanel.textContent = 'Hover or click a footnote number to read the note here.';

      marginRail.append(marginHeader, marginNotePanel);

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
        if (target) {
          ev.preventDefault();
          target.scrollIntoView({ behavior: 'smooth', block: 'start' });
          history.replaceState(null, '', `#${target.id}`);
        }
        if (window.matchMedia('(max-width: 1180px)').matches) setDrawer(false);
      });

      document.addEventListener('keydown', ev => {
        if (ev.key === 'Escape') setDrawer(false);
      });

      document.addEventListener('click', ev => {
        if (!document.body.classList.contains('web-toc-open')) return;
        if (nav.contains(ev.target) || toggle.contains(ev.target)) return;
        setDrawer(false);
      });

      // Highlight the section currently being read. We use the nearest section
      // whose top has passed the upper part of the viewport; this is steadier than
      // rapidly toggling on short subsections.
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

        if (current && window.matchMedia('(min-width: 1181px)').matches) {
          const navRect = nav.getBoundingClientRect();
          const linkRect = current.link.getBoundingClientRect();
          if (linkRect.top < navRect.top + 55 || linkRect.bottom > navRect.bottom - 20) {
            current.link.scrollIntoView({ block: 'nearest' });
          }
        }
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
      if (window.matchMedia('(min-width: 1181px)').matches) renderMarginNote(note);
    });
    mark.addEventListener('focus', () => {
      if (window.matchMedia('(min-width: 1181px)').matches) renderMarginNote(note);
    });

    const toggle = (ev) => {
      ev.preventDefault();
      ev.stopPropagation();
      document.querySelectorAll('.ltx_note.is-open').forEach(n => {
        if (n !== note) n.classList.remove('is-open');
      });

      if (window.matchMedia('(min-width: 1181px)').matches) {
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
});
