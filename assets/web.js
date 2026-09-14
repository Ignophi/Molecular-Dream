document.addEventListener('DOMContentLoaded', () => {
  const paper = document.querySelector('article.ltx_document, .ltx_document');
  const placeholder = document.querySelector('.web-toc-placeholder');

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
        const annotations = [...item.querySelectorAll('.web-ref-annotation')];

        if (directBlocks.length) {
          const main = document.createElement('div');
          main.className = 'web-ref-main';
          let visiblePart = 0;

          directBlocks.forEach(block => {
            const clone = block.cloneNode(true);
            clone.querySelectorAll('.web-ref-annotation').forEach(note => note.remove());

            // Ignore the punctuation left behind by an annotation-only \newblock.
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

          const notes = document.createElement('div');
          notes.className = 'web-ref-notes';

          annotations.forEach(note => {
            const label = note.querySelector('.ltx_font_bold, strong, b');
            const quote = note.querySelector('.ltx_font_italic, em, i');
            if (label) label.classList.add('web-ref-annotation-label');
            if (quote) quote.classList.add('web-ref-annotation-text');
            notes.appendChild(note);
          });

          directBlocks.forEach(block => block.remove());
          item.appendChild(main);
          if (annotations.length) item.appendChild(notes);
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

        let depth = 1;
        if (container.classList.contains('ltx_subsection')) depth = 2;
        if (container.classList.contains('ltx_subsubsection')) depth = 3;

        const li = document.createElement('li');
        li.className = `web-toc-item depth-${depth}`;

        const a = document.createElement('a');
        a.className = 'web-toc-link';
        a.href = `#${container.id}`;
        a.textContent = heading.textContent.replace(/\s+/g, ' ').trim();
        a.dataset.targetId = container.id;

        li.appendChild(a);
        list.appendChild(li);
        sectionLinks.push({ container, link: a });
      });

      nav.appendChild(list);

      // Put the navigation beside the article without rewriting the article itself.
      const shell = document.createElement('div');
      shell.className = 'web-layout';
      paper.parentNode.insertBefore(shell, paper);
      shell.append(nav, paper);

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

  // Make footnote popovers usable by click/tap as well as hover.
  document.querySelectorAll('.ltx_note').forEach(note => {
    const mark = note.querySelector('.ltx_note_mark');
    if (!mark) return;
    mark.setAttribute('tabindex', '0');
    mark.setAttribute('role', 'button');
    const toggle = (ev) => {
      ev.preventDefault();
      ev.stopPropagation();
      document.querySelectorAll('.ltx_note.is-open').forEach(n => {
        if (n !== note) n.classList.remove('is-open');
      });
      note.classList.toggle('is-open');
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
