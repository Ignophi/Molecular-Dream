document.addEventListener('DOMContentLoaded', () => {
  const paper = document.querySelector('article.ltx_document, .ltx_document');
  const placeholder = document.querySelector('.web-toc-placeholder');

  if (paper) {
    const headings = [...paper.querySelectorAll(
      'section.ltx_section > .ltx_title, ' +
      'section.ltx_subsection > .ltx_title, ' +
      'section.ltx_subsubsection > .ltx_title, ' +
      '.ltx_bibliography > .ltx_title'
    )];

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
