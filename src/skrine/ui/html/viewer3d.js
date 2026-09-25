/* WebGL view of the scene: boxes + edges, orbit camera, hover/selection, clipping. */
/* global THREE Drawing */
/* exported Viewer3d */
const Viewer3d = {
  MM: 0.001,                       // scene units are metres, the model is millimetres
  ACCENT: 0xf28c28,
  available() {
    if (this._available != null) return this._available;
    try {
      const canvas = document.createElement('canvas');
      this._available = !!(window.THREE && (canvas.getContext('webgl2') || canvas.getContext('webgl')));
    } catch (e) {
      this._available = false;
    }
    return this._available;
  },

  // ---------- lifecycle ----------
  mount(host) {
    if (this.renderer && this.host === host) return true;
    if (!this.available()) return false;
    this.host = host;
    this.renderer = new THREE.WebGLRenderer({ antialias: true });
    this.renderer.setPixelRatio(window.devicePixelRatio || 1);
    this.renderer.localClippingEnabled = true;
    this.renderer.setClearColor(0xf7f7f7, 1);
    host.appendChild(this.renderer.domElement);
    this.scene3 = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(35, 1, 0.05, 200);
    this.scene3.add(new THREE.HemisphereLight(0xffffff, 0x9a9a9a, 0.95));
    const sun = new THREE.DirectionalLight(0xffffff, 0.55);
    sun.position.set(2.5, -4, 5);
    this.scene3.add(sun);
    this.root = new THREE.Group();
    this.scene3.add(this.root);
    this.overlay = new THREE.Group();          // measurement graphics, cleared separately
    this.scene3.add(this.overlay);
    this.raycaster = new THREE.Raycaster();
    this.clipPlane = new THREE.Plane(new THREE.Vector3(0, -1, 0), 10);
    this.target = new THREE.Vector3();
    this.spherical = new THREE.Spherical(6, 1.15, Math.PI - 0.7);
    this.bindInput();
    this.loop();
    return true;
  },

  dispose() {
    if (!this.renderer) return;
    cancelAnimationFrame(this.raf);
    this.renderer.dispose();
    if (this.renderer.domElement.parentNode) this.renderer.domElement.parentNode.removeChild(this.renderer.domElement);
    this.renderer = null;
    this.host = null;
  },

  loop() {
    this.raf = requestAnimationFrame(() => this.loop());
    if (!this.renderer || !this.host || !this.host.clientWidth) return;
    const w = this.host.clientWidth;
    const h = this.host.clientHeight;
    if (this.renderer.domElement.width !== w || this.renderer.domElement.height !== h) {
      this.renderer.setSize(w, h, false);
      this.camera.aspect = w / Math.max(1, h);
      this.camera.updateProjectionMatrix();
    }
    this.camera.position.setFromSpherical(this.spherical).add(this.target);
    this.camera.lookAt(this.target);
    this.renderer.render(this.scene3, this.camera);
  },

  // ---------- scene ----------
  // +X right, +Y depth (front plane at 0, carcass towards +Y), +Z up — the model's
  // own system, mapped to three.js as (x, z, y) so that Z stays up on screen.
  vec(x, y, z) {
    return new THREE.Vector3(x * this.MM, z * this.MM, y * this.MM);
  },

  build(scene, opts) {
    if (!this.renderer) return;
    while (this.root.children.length) {
      const child = this.root.children.pop();
      if (child.geometry) child.geometry.dispose();
      if (child.material) child.material.dispose();
    }
    this.boxes = [];
    const hidden = opts.withoutFronts ? ['door', 'drawer_front', 'plinth', 'top_strip', 'filler'] : [];
    scene.boxes.filter((b) => !hidden.includes(b.kind)).forEach((b) => {
      const color = new THREE.Color(Drawing.COLORS[b.kind] || '#999999');
      const geo = new THREE.BoxGeometry(b.dx * this.MM, b.dz * this.MM, b.dy * this.MM);
      const mat = new THREE.MeshLambertMaterial({ color: color, clippingPlanes: [this.clipPlane] });
      const mesh = new THREE.Mesh(geo, mat);
      mesh.position.copy(this.vec(b.x + b.dx / 2, b.y + b.dy / 2, b.z + b.dz / 2));
      mesh.userData.box = b;
      const edges = new THREE.LineSegments(
        new THREE.EdgesGeometry(geo),
        new THREE.LineBasicMaterial({ color: 0x333333, clippingPlanes: [this.clipPlane] })
      );
      mesh.add(edges);
      if (opts.openDoors && b.kind === 'door' && b.rotation) this.applyRotation(mesh, b);
      this.root.add(mesh);
      this.boxes.push({ box: b, mesh: mesh, base: color.clone() });
    });
    this.applySelection(opts.selection);
    this.frame(scene, opts.keepCamera);
    this.clipPlane.constant = 10;
  },

  applyRotation(mesh, b) {
    const r = b.rotation;
    const pivot = this.vec(r.point[0], r.point[1], r.point[2]);
    const axis = new THREE.Vector3(r.axis[0], r.axis[2], r.axis[1]).normalize();
    mesh.position.sub(pivot);
    mesh.position.applyAxisAngle(axis, (r.angle * Math.PI) / 180);
    mesh.position.add(pivot);
    mesh.rotateOnWorldAxis(axis, (r.angle * Math.PI) / 180);
  },

  frame(scene, keepCamera) {
    this.target.set((scene.size.w / 2) * this.MM, (scene.size.h / 2) * this.MM, (scene.size.d / 2) * this.MM);
    if (keepCamera && this.framed) return;
    const radius = Math.max(scene.size.w, scene.size.h, scene.size.d) * this.MM * 1.9;
    this.spherical.set(radius, 1.15, Math.PI - 0.7);
    this.framed = true;
  },

  setView(name) {
    const r = this.spherical.radius;
    const views = {
      front: [r, Math.PI / 2, Math.PI],
      side: [r, Math.PI / 2, Math.PI / 2],
      top: [r, 0.05, Math.PI],
      iso: [r, 1.15, Math.PI - 0.7]
    };
    const v = views[name] || views.iso;
    this.spherical.set(v[0], v[1], v[2]);
  },

  // fraction 0 = nothing cut away, 1 = the whole depth cut away (front to back).
  // Three-space depth is +Z, so keep everything with z <= cut.
  setClip(fraction, scene) {
    const depth = scene.size.d * this.MM;
    this.clipPlane.set(new THREE.Vector3(0, 0, -1), fraction <= 0 ? 1e3 : depth * (1 - fraction));
  },

  applySelection(selection) {
    if (!this.boxes) return;
    this.boxes.forEach((entry) => {
      const selected = Drawing.isSelected(entry.box, selection);
      entry.mesh.material.color.copy(selected ? new THREE.Color(this.ACCENT) : entry.base);
      entry.mesh.material.emissive = new THREE.Color(entry.hovered ? 0x553300 : 0x000000);
    });
  },

  hover(entryOrNull) {
    if (!this.boxes) return;
    this.boxes.forEach((e) => {
      const on = e === entryOrNull;
      if (e.hovered !== on) {
        e.hovered = on;
        e.mesh.material.emissive = new THREE.Color(on ? 0x553300 : 0x000000);
      }
    });
  },

  // ---------- input ----------
  pointer(event) {
    const rect = this.renderer.domElement.getBoundingClientRect();
    return new THREE.Vector2(
      ((event.clientX - rect.left) / rect.width) * 2 - 1,
      -((event.clientY - rect.top) / rect.height) * 2 + 1
    );
  },

  pick(event) {
    if (!this.boxes || !this.boxes.length) return null;
    this.raycaster.setFromCamera(this.pointer(event), this.camera);
    const hits = this.raycaster.intersectObjects(this.boxes.map((e) => e.mesh), false);
    if (!hits.length) return null;
    const entry = this.boxes.find((e) => e.mesh === hits[0].object);
    return entry ? { entry: entry, point: hits[0].point } : null;
  },

  bindInput() {
    const el = this.renderer.domElement;
    let dragging = null;
    let moved = 0;
    el.addEventListener('contextmenu', (e) => e.preventDefault());
    el.addEventListener('pointerdown', (e) => {
      dragging = { x: e.clientX, y: e.clientY, pan: e.button !== 0 || e.shiftKey };
      moved = 0;
      el.setPointerCapture(e.pointerId);
    });
    el.addEventListener('pointermove', (e) => {
      if (this.onPointerMove) this.onPointerMove(e);
      if (!dragging) {
        const hit = this.pick(e);
        this.hover(hit ? hit.entry : null);
        if (this.onHover) this.onHover(hit ? hit.entry.box : null);
        return;
      }
      const dx = e.clientX - dragging.x;
      const dy = e.clientY - dragging.y;
      moved += Math.abs(dx) + Math.abs(dy);
      dragging.x = e.clientX;
      dragging.y = e.clientY;
      if (dragging.pan) {
        const scale = this.spherical.radius * 0.0015;
        const right = new THREE.Vector3().setFromMatrixColumn(this.camera.matrix, 0);
        const up = new THREE.Vector3().setFromMatrixColumn(this.camera.matrix, 1);
        this.target.addScaledVector(right, -dx * scale).addScaledVector(up, dy * scale);
      } else {
        this.spherical.theta -= dx * 0.005;
        this.spherical.phi = Math.min(Math.PI - 0.05, Math.max(0.05, this.spherical.phi - dy * 0.005));
      }
    });
    el.addEventListener('pointerup', (e) => {
      el.releasePointerCapture(e.pointerId);
      const wasDrag = moved > 6;
      dragging = null;
      if (wasDrag) return;
      if (this.onClick) this.onClick(e, this.pick(e));
    });
    el.addEventListener('wheel', (e) => {
      e.preventDefault();
      this.spherical.radius = Math.min(60, Math.max(0.4, this.spherical.radius * (1 + Math.sign(e.deltaY) * 0.12)));
    }, { passive: false });
  }
};
