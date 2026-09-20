/* SVG drawing of a scene with projections, hover/selection and dimension lines. */
/* exported Drawing */
const Drawing = {
  VIEWS: { front: ['x', 'z'], front_open: ['x', 'z'], side: ['y', 'z'], plan: ['x', 'y'] },
  HIDE: { front_open: ['door', 'drawer_front', 'plinth', 'top_strip', 'filler'] },
  COLORS: {
    side: '#d9c9a8', top: '#d9c9a8', bottom: '#d9c9a8', partition: '#cdbb95', shelf: '#e8dcc0', back: '#f0ece0',
    plinth: '#b8a27a', top_strip: '#b8a27a', filler: '#b8a27a', door: '#f4b8a0', drawer_front: '#f4b8a0',
    drawer_box: '#c8c8c8', leg: '#7a7a7a', rod: '#6a6a6a', hardware: '#8a8a8a'
  },
  ACCENT: '#f28c28',

  targetFor(box) {
    switch (box.kind) {
      case 'door': case 'partition': return { kind: 'column', column: box.column, boxId: box.id };
      case 'shelf': case 'drawer_front': case 'drawer_box': case 'rod':
        return { kind: 'cell', column: box.column, cell: box.cell, boxId: box.id };
      case 'plinth': case 'top_strip': case 'filler': case 'leg': return { kind: 'base', boxId: box.id };
      case 'side': case 'top': case 'bottom': case 'back': return { kind: 'construction', boxId: box.id };
      default: return { kind: 'global', boxId: box.id };
    }
  },

  isSelected(box, sel) {
    if (!sel) return false;
    const t = this.targetFor(box);
    if (sel.kind !== t.kind) return false;
    if (sel.kind === 'column') return sel.column === t.column;
    if (sel.kind === 'cell') return sel.column === t.column && sel.cell === t.cell;
    return sel.kind !== 'global';
  },

  fmt(v) { return Number.isInteger(v) ? String(v) : v.toFixed(1); },

  render(host, scene, opts) {
    const view = opts.view || 'front';
    const [ax, ay] = this.VIEWS[view];
    const hide = this.HIDE[view] || [];
    const size = { x: scene.size.w, y: scene.size.d, z: scene.size.h };
    const vw = size[ax];
    const vh = size[ay];
    const m = opts.interactive === false ? { l: 20, r: 20, t: 20, b: 20 } : { l: 220, r: 60, t: 200, b: 60 };
    const W = host.clientWidth || 800;
    const H = host.clientHeight || 600;
    const scale = Math.min((W - 8) / (vw + m.l + m.r), (H - 8) / (vh + m.t + m.b));
    const X = (v) => 4 + (m.l + v) * scale;
    const Y = (v) => (ay === 'z' ? 4 + (m.t + vh - v) * scale : 4 + (m.t + v) * scale);
    const depthAxis = ['x', 'y', 'z'].find((a) => a !== ax && a !== ay);
    // far boxes first: front views look from -Y, side view from -X, plan from +Z
    const depthKey = (b) => (depthAxis === 'z' ? b.z : -(b[depthAxis] + b['d' + depthAxis]));
    const parts = [];
    const geom = (b) => {
      const x0 = b[ax]; const dx = b['d' + ax]; const y0 = b[ay]; const dy = b['d' + ay];
      const px = X(x0); const py = ay === 'z' ? Y(y0 + dy) : Y(y0);
      return `x="${px.toFixed(1)}" y="${py.toFixed(1)}" width="${(dx * scale).toFixed(1)}" height="${(dy * scale).toFixed(1)}"`;
    };
    if (opts.interactive !== false) {
      scene.cells.forEach((c) => {
        const b = { x: c.x, y: 0, z: c.z, dx: c.w, dy: size.y, dz: c.h };
        const sel = opts.selection && opts.selection.kind === 'cell' && opts.selection.column === c.column && opts.selection.cell === c.cell;
        parts.push(`<rect class="cell${sel ? ' selected' : ''}" ${geom(b)} data-target="cell" data-column="${c.column}" data-cell="${c.cell}"/>`);
      });
    }
    scene.boxes.filter((b) => !hide.includes(b.kind)).sort((a, b) => depthKey(a) - depthKey(b)).forEach((b) => {
      const cls = ['box', b.kind, this.isSelected(b, opts.selection) ? 'selected' : '', opts.hover === b.id ? 'hover' : ''].join(' ');
      parts.push(`<rect class="${cls}" ${geom(b)} data-id="${b.id}" fill="${this.COLORS[b.kind] || '#999'}"><title>${b.name} ${this.fmt(b.dx)}×${this.fmt(b.dz)}×${this.fmt(b.dy)}</title></rect>`);
    });
    // dimension lines
    const dims = this.dimsFor(scene, view);
    dims.forEach((d) => {
      const text = this.fmt(d.value);
      const editable = d.edit && opts.interactive !== false;
      if (d.orient === 'h') {
        const y = d.axisAt === 'z' ? Y(d.at) : 4 + (m.t + d.at) * scale;
        const x1 = X(d.from); const x2 = X(d.to);
        parts.push(`<g class="dim${editable ? ' editable' : ''}" data-dim="${d.id}"><line x1="${x1}" y1="${y}" x2="${x2}" y2="${y}"/><line x1="${x1}" y1="${y - 5}" x2="${x1}" y2="${y + 5}"/><line x1="${x2}" y1="${y - 5}" x2="${x2}" y2="${y + 5}"/><text x="${(x1 + x2) / 2}" y="${y - 4}" text-anchor="middle">${text}</text></g>`);
      } else {
        const x = d.axisAt === 'x' ? X(d.at) : 4 + (m.l + d.at) * scale;
        const y1 = ay === 'z' ? Y(d.to) : Y(d.from); const y2 = ay === 'z' ? Y(d.from) : Y(d.to);
        parts.push(`<g class="dim${editable ? ' editable' : ''}" data-dim="${d.id}"><line x1="${x}" y1="${y1}" x2="${x}" y2="${y2}"/><line x1="${x - 5}" y1="${y1}" x2="${x + 5}" y2="${y1}"/><line x1="${x - 5}" y1="${y2}" x2="${x + 5}" y2="${y2}"/><text x="${x - 4}" y="${(y1 + y2) / 2 + 4}" text-anchor="end">${text}</text></g>`);
      }
    });
    host.innerHTML = `<svg class="drawing" width="${W}" height="${H}" data-view="${view}">${parts.join('')}</svg>`;
    if (opts.interactive === false) return;
    const svg = host.firstElementChild;
    const boxById = Object.fromEntries(scene.boxes.map((b) => [b.id, b]));
    const dimById = Object.fromEntries(dims.map((d) => [d.id, d]));
    svg.addEventListener('mousemove', (e) => {
      const el = e.target.closest('[data-id]');
      if (opts.onHover) opts.onHover(el ? boxById[el.dataset.id] : null);
    });
    svg.addEventListener('mouseleave', () => opts.onHover && opts.onHover(null));
    svg.addEventListener('click', (e) => {
      const dimEl = e.target.closest('.dim.editable');
      if (dimEl) {
        const t = dimEl.querySelector('text');
        const r = t.getBoundingClientRect(); const hr = host.getBoundingClientRect();
        if (opts.onEditDim) opts.onEditDim(dimById[dimEl.dataset.dim], { x: r.left - hr.left, y: r.top - hr.top, w: r.width, h: r.height });
        return;
      }
      const boxEl = e.target.closest('[data-id]');
      if (boxEl) return opts.onSelect && opts.onSelect(this.targetFor(boxById[boxEl.dataset.id]));
      const cellEl = e.target.closest('[data-target="cell"]');
      if (cellEl) return opts.onSelect && opts.onSelect({ kind: 'cell', column: Number(cellEl.dataset.column), cell: Number(cellEl.dataset.cell) });
      return opts.onSelect && opts.onSelect({ kind: 'global' });
    });
  },

  // Which dimension lines make sense in a view, with orientation and where their offset applies.
  dimsFor(scene, view) {
    const all = scene.dims;
    const get = (id) => all.find((d) => d.id === id);
    if (view === 'front' || view === 'front_open') {
      return all.filter((d) => d.axis !== 'y').map((d) => ({ ...d, orient: d.axis === 'x' ? 'h' : 'v', axisAt: d.axis === 'x' ? 'z' : 'x' }));
    }
    if (view === 'side') {
      const h = get('height'); const dp = get('depth');
      return [{ ...h, orient: 'v', axisAt: 'y', at: -140 }, { ...dp, orient: 'h', axisAt: 'z', at: scene.size.h + 120 }];
    }
    const w = get('width'); const dp = get('depth');
    return [{ ...w, orient: 'h', axisAt: 'raw', at: -140 }, { ...dp, orient: 'v', axisAt: 'raw', at: -140 }];
  }
};
