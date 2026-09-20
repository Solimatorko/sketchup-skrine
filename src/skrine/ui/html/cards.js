/* Option cards (radio groups with pictograms) and module thumbnails. */
/* global ICONS */
/* exported Cards */
const Cards = {
  radio(container, { options, value, icons, onChange, small = false }) {
    container.innerHTML = '';
    container.className = 'cards' + (small ? ' small' : '');
    options.forEach((o) => {
      const b = document.createElement('button');
      b.type = 'button';
      b.className = 'card' + (String(o.value) === String(value) ? ' active' : '');
      b.title = o.label;
      const icon = ICONS[(icons ? icons + '.' : '') + o.value];
      b.innerHTML = (icon ? `<span class="icon">${icon}</span>` : '') + `<span class="label">${o.label}</span>`;
      b.onclick = () => {
        container.querySelectorAll('.card').forEach((c) => c.classList.toggle('active', c === b));
        onChange(o.value);
      };
      container.appendChild(b);
    });
    return container;
  },

  // Schematic column drawing for a module definition (cells top → bottom).
  moduleSvg(mod, w = 60, h = 90) {
    const cells = mod.cells;
    const fixed = cells.reduce((s, c) => s + (c.height_mode === 'mm' ? Number(c.height) : 0), 0);
    const autoN = cells.filter((c) => c.height_mode !== 'mm').length;
    const total = 2264; // reference inner height
    const autoH = autoN ? Math.max(0, (total - fixed) / autoN) : 0;
    let y = 2;
    const parts = [`<rect x="2" y="2" width="${w - 4}" height="${h - 4}" fill="#fff" stroke="#333"/>`];
    cells.forEach((c, i) => {
      const ch = ((c.height_mode === 'mm' ? Number(c.height) : autoH) / total) * (h - 4);
      const x0 = 4, x1 = w - 4;
      if (i > 0) parts.push(`<line x1="2" y1="${y}" x2="${w - 2}" y2="${y}" stroke="#333"/>`);
      if (c.content === 'shelves') {
        const n = Number(c.shelves_count || 2);
        for (let k = 1; k <= n; k += 1) parts.push(`<line x1="${x0}" y1="${(y + (ch * k) / (n + 1)).toFixed(1)}" x2="${x1}" y2="${(y + (ch * k) / (n + 1)).toFixed(1)}" stroke="#666"/>`);
      } else if (c.content === 'rod') {
        parts.push(`<line x1="${x0}" y1="${(y + ch * 0.12).toFixed(1)}" x2="${x1}" y2="${(y + ch * 0.12).toFixed(1)}" stroke="#f28c28" stroke-width="2"/>`);
      } else if (c.content === 'drawers' || c.content === 'inner_drawers') {
        const n = Number(c.drawers_count || 3);
        const dh = ch / n;
        for (let k = 0; k < n; k += 1) parts.push(`<rect x="${x0}" y="${(y + k * dh + 1).toFixed(1)}" width="${x1 - x0}" height="${Math.max(1, dh - 2).toFixed(1)}" fill="${c.content === 'drawers' ? '#f4b8a0' : '#ddd'}" stroke="#333"/>`);
      }
      y += ch;
    });
    return `<svg viewBox="0 0 ${w} ${h}" width="${w}" height="${h}">${parts.join('')}</svg>`;
  }
};
