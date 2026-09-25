/* Tape measure for the 3D view: snapping to box corners, edge midpoints and face
   centres, a dimension line with the distance, and "use as dimension" when the
   measurement matches a parameter. */
/* global THREE Viewer3d */
/* exported Measure */
const Measure = {
  SNAP_PX: 14,
  COLORS: { corner: 0x2e9e4f, edge: 0x1a56c4, face: 0x888888 },

  active: false,
  first: null,
  list: [],

  start(onChange) {
    this.onChange = onChange || this.onChange;
    this.active = true;
    this.first = null;
    this.render();
  },

  stop() {
    this.active = false;
    this.first = null;
    this.clearPreview();
    this.render();
  },

  clearAll() {
    this.list = [];
    this.first = null;
    this.draw();
    this.render();
  },

  // ---------- snap candidates ----------
  // Every visible box contributes 8 corners, 12 edge midpoints and 6 face centres,
  // all exact because parts are axis-aligned boxes.
  candidates() {
    if (this._cache && this._cacheFor === Viewer3d.boxes) return this._cache;
    const out = [];
    (Viewer3d.boxes || []).forEach((entry) => {
      const b = entry.box;
      const xs = [b.x, b.x + b.dx];
      const ys = [b.y, b.y + b.dy];
      const zs = [b.z, b.z + b.dz];
      const mx = b.x + b.dx / 2;
      const my = b.y + b.dy / 2;
      const mz = b.z + b.dz / 2;
      xs.forEach((x) => ys.forEach((y) => zs.forEach((z) => out.push({ kind: 'corner', x: x, y: y, z: z, box: b }))));
      xs.forEach((x) => ys.forEach((y) => out.push({ kind: 'edge', x: x, y: y, z: mz, box: b })));
      xs.forEach((x) => zs.forEach((z) => out.push({ kind: 'edge', x: x, y: my, z: z, box: b })));
      ys.forEach((y) => zs.forEach((z) => out.push({ kind: 'edge', x: mx, y: y, z: z, box: b })));
      xs.forEach((x) => out.push({ kind: 'face', x: x, y: my, z: mz, box: b }));
      ys.forEach((y) => out.push({ kind: 'face', x: mx, y: y, z: mz, box: b }));
      zs.forEach((z) => out.push({ kind: 'face', x: mx, y: my, z: z, box: b }));
    });
    this._cache = out;
    this._cacheFor = Viewer3d.boxes;
    return out;
  },

  invalidate() {
    this._cache = null;
  },

  // Nearest snap point within SNAP_PX of the cursor, else the ray hit on a face.
  snap(event, hit) {
    const rect = Viewer3d.renderer.domElement.getBoundingClientRect();
    const px = event.clientX - rect.left;
    const py = event.clientY - rect.top;
    let best = null;
    this.candidates().forEach((c) => {
      const v = Viewer3d.vec(c.x, c.y, c.z).project(Viewer3d.camera);
      if (v.z > 1) return;
      const sx = ((v.x + 1) / 2) * rect.width;
      const sy = ((1 - v.y) / 2) * rect.height;
      const d = Math.hypot(sx - px, sy - py);
      if (d <= this.SNAP_PX && (!best || d < best.d)) best = { d: d, point: c };
    });
    if (best) return best.point;
    if (!hit) return null;
    const p = hit.point;
    return { kind: 'free', x: p.x / Viewer3d.MM, y: p.z / Viewer3d.MM, z: p.y / Viewer3d.MM, box: hit.entry.box };
  },

  // ---------- interaction ----------
  onMove(event, hit) {
    if (!this.active) return;
    this.hovered = this.snap(event, hit);
    this.draw();
  },

  onClick(event, hit) {
    if (!this.active) return false;
    const point = this.snap(event, hit);
    if (!point) return true;
    if (!this.first) {
      this.first = point;
    } else {
      this.list.push({ a: this.first, b: point });
      this.first = null;
      this.render();
    }
    this.draw();
    return true;
  },

  cancel() {
    this.first = null;
    this.draw();
  },

  distance(m) {
    return Math.hypot(m.b.x - m.a.x, m.b.y - m.a.y, m.b.z - m.a.z);
  },

  fmt(v) {
    return (Math.round(v * 10) / 10).toString().replace('.', ',');
  },

  // ---------- drawing ----------
  clearPreview() {
    while (Viewer3d.overlay.children.length) {
      const c = Viewer3d.overlay.children.pop();
      if (c.geometry) c.geometry.dispose();
      if (c.material) c.material.dispose();
    }
  },

  dot(point, color) {
    const mesh = new THREE.Mesh(
      new THREE.SphereGeometry(0.012, 10, 8),
      new THREE.MeshBasicMaterial({ color: color })
    );
    mesh.position.copy(Viewer3d.vec(point.x, point.y, point.z));
    Viewer3d.overlay.add(mesh);
  },

  line(a, b, color) {
    const geo = new THREE.BufferGeometry().setFromPoints([
      Viewer3d.vec(a.x, a.y, a.z), Viewer3d.vec(b.x, b.y, b.z)
    ]);
    Viewer3d.overlay.add(new THREE.Line(geo, new THREE.LineBasicMaterial({ color: color, depthTest: false })));
  },

  draw() {
    if (!Viewer3d.overlay) return;
    this.clearPreview();
    this.list.forEach((m) => {
      this.line(m.a, m.b, 0xc62828);
      this.dot(m.a, this.COLORS[m.a.kind] || 0x666666);
      this.dot(m.b, this.COLORS[m.b.kind] || 0x666666);
    });
    if (this.first) this.dot(this.first, this.COLORS[this.first.kind] || 0x666666);
    if (this.active && this.hovered) {
      this.dot(this.hovered, this.COLORS[this.hovered.kind] || 0x666666);
      if (this.first) this.line(this.first, this.hovered, 0xf28c28);
    }
  },

  // ---------- "use as dimension" ----------
  // A measurement maps to a parameter when it runs along one axis and its ends
  // sit on parts that bound that parameter.
  suggestion(m, state, scene) {
    const dx = Math.abs(m.b.x - m.a.x);
    const dy = Math.abs(m.b.y - m.a.y);
    const dz = Math.abs(m.b.z - m.a.z);
    const value = this.distance(m);
    const axis = dx > dy && dx > dz ? 'x' : (dz > dy ? 'z' : 'y');
    const spread = { x: dx, y: dy, z: dz };
    // ignore diagonals: the other two axes must be negligible
    if (['x', 'y', 'z'].some((a) => a !== axis && spread[a] > 0.5)) return null;
    const boxes = [m.a.box, m.b.box].filter(Boolean);

    // Outer width/height/depth may only be offered when the measurement really spans
    // the whole wardrobe; an inner measurement (e.g. between the sides) would silently
    // shrink it. Column widths and cell heights are inner values by definition, so
    // those match the parameters directly.
    const spansAll = (key, size) => {
      const lo = Math.min(m.a[key], m.b[key]);
      const hi = Math.max(m.a[key], m.b[key]);
      return lo <= 0.5 && hi >= size - 0.5;
    };
    if (axis === 'y') return spansAll('y', scene.size.d) ? { path: 'depth', label: 'hĺbku skrine', value: value } : null;
    if (axis === 'x') {
      const columns = boxes.map((b) => b && b.column).filter((c) => c);
      if (columns.length === 2 && columns[0] === columns[1]) {
        return { path: `columns.${columns[0] - 1}.width`, label: `šírku stĺpca ${columns[0]}`, value: value };
      }
      return spansAll('x', scene.size.w) ? { path: 'width', label: 'šírku skrine', value: value } : null;
    }
    const cells = boxes.map((b) => (b && b.column && b.cell ? `${b.column}.${b.cell}` : null)).filter(Boolean);
    if (cells.length === 2 && cells[0] === cells[1]) {
      const [col, cell] = cells[0].split('.').map(Number);
      return { path: `columns.${col - 1}.cells.${cell - 1}.height`, label: `výšku poľa ${col}/${cell}`, value: value };
    }
    return spansAll('z', scene.size.h) ? { path: 'height', label: 'výšku skrine', value: value } : null;
  },

  render() {
    if (this.onChange) this.onChange();
  }
};
