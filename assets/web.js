document.addEventListener('DOMContentLoaded', () => {
  // Build an HTML-native, clickable outline from the section headings.
  const placeholder = document.querySelector('.web-toc-placeholder');
  if (placeholder) {
    const headings = [...document.querySelectorAll(
      'section.ltx_section > .ltx_title, ' +
      'section.ltx_subsection > .ltx_title, ' +
      'section.ltx_subsubsection > .ltx_title, ' +
      '.ltx_bibliography > .ltx_title'
    )];

    const nav = document.createElement('nav');
    nav.className = 'web-toc';
    nav.setAttribute('aria-label', 'Contents');
    const list = document.createElement('ol');

    headings.forEach((heading, i) => {
      const container = heading.parentElement;
      if (!container) return;
      if (!container.id) container.id = `web-section-${i + 1}`;

      let depth = 1;
      if (container.classList.contains('ltx_subsection')) depth = 2;
      if (container.classList.contains('ltx_subsubsection')) depth = 3;

      const li = document.createElement('li');
      li.className = `depth-${depth}`;
      const a = document.createElement('a');
      a.href = `#${container.id}`;
      a.textContent = heading.textContent.replace(/\s+/g, ' ').trim();
      li.appendChild(a);
      list.appendChild(li);
    });

    nav.appendChild(list);
    const markerBlock = placeholder.closest('p, .ltx_para') || placeholder;
    markerBlock.insertAdjacentElement('afterend', nav);
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
