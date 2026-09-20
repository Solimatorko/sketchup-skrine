/* Skrine visual editor: state, selection panels, drawing wiring, advanced form, SketchUp bridge. */
/* global Drawing Cards ICONS Form Gallery sketchup */
const OPTION_LABELS = {
  between_walls: 'medzi stenami', corner_left: 'ľavý roh', corner_right: 'pravý roh', free: 'voľne stojaca',
  inset: 'medzi bokmi / vnorené', overlay: 'cez bok / nalozené', half_overlay: 'polonalozené',
  none: 'žiadne', drilled: 'navŕtaná', profile: 'integrovaný profil',
  horizontal: 'vodorovná', vertical: 'zvislá', top: 'hore', bottom: 'dole',
  single_left: '1 krídlo, pánty vľavo', single_right: '1 krídlo, pánty vpravo', double: '2 krídla', flap_up: 'výklop hore',
  auto: 'auto', mm: 'mm', ratio: 'pomer',
  shelves: 'police', rod: 'vešiaková tyč', drawers: 'zásuvky', inner_drawers: 'vnorené zásuvky', empty: 'prázdne',
  groove: 'v drážke (HDF)', legs: 'nožičky', plinth: 'sokel medzi bokmi', floor: 'na podlahe',
  closed: 'zatvorené', open: 'otvorené',
  front_only: 'len čelo + výsuv', wood_box: 'drevený box', blum_legrabox: 'Blum LEGRABOX', blum_tandembox: 'Blum TANDEMBOX', blum_merivobox: 'Blum MERIVOBOX',
  dowels: 'kolíky', confirmat: 'konfirmáty', cam_lock: 'excentre', front: 'predná hrana', all: 'všetky hrany', wood: 'drevený', metal: 'kovový'
};
const VIEWS = [{ value: 'front', label: 's čelami' }, { value: 'front_open', label: 'bez čiel' }, { value: 'side', label: 'bok' }, { value: 'plan', label: 'pôdorys' }];
const ADVANCED_GROUPS = [['construction', 'Konštrukcia'], ['fronts', 'Čelá a špáry'], ['drawers', 'Zásuvky'], ['materials', 'Materiály'], ['hardware', 'Kovanie a hrany']];

const el = (tag, attrs = {}, ...children) => {
  const e = document.createElement(tag);
  Object.entries(attrs).forEach(([k, v]) => { if (k === 'class') e.className = v; else if (k.startsWith('on')) e[k] = v; else e.setAttribute(k, v); });
  children.forEach((c) => e.append(c));
  return e;
};

const Skrine = {
  schema: null, state: null, modules: [], scene: null, info: {}, errors: [], warnings: [],
  selection: { kind: 'global' }, view: 'front', auto: true, advancedTab: 'construction', previewTimer: null, applyTimer: null,

  init(payload) {
    this.schema = payload.schema;
    this.state = payload.state;
    this.modules = payload.modules || [];
    Form.LABELS = OPTION_LABELS;
    document.getElementById('title').textContent = payload.label;
    this.render();
    this.setPreview(payload.preview || {});
    this.setResult(payload.result || {});
  },

  // ---------- bridge ----------
  changed() {
    clearTimeout(this.previewTimer);
    this.previewTimer = setTimeout(() => sketchup.preview(JSON.stringify(this.state)), 150);
    if (this.auto) { clearTimeout(this.applyTimer); this.applyTimer = setTimeout(() => this.apply(), 600); }
  },
  apply() { sketchup.apply(JSON.stringify(this.state)); },
  setPreview(pv) {
    this.errors = pv.errors || []; this.warnings = pv.warnings || []; this.info = pv.info || {};
    if (pv.scene) this.scene = pv.scene;
    this.drawScene(); this.renderMessages(); this.renderInfo();
  },
  setResult(r) {
    if (r.errors && r.errors.length) this.errors = r.errors;
    if (r.warnings && r.warnings.length) this.warnings = r.warnings;
    if (r.info && r.info.inner_w != null) this.info = r.info;
    this.renderMessages(); this.renderInfo();
  },
  loadParams(params) { this.state = params; this.selection = { kind: 'global' }; this.render(); this.changed(); },
  showGallery(list) { Gallery.show(list, { onApply: (f) => sketchup.use_preset(f, 'apply'), onNew: (f) => sketchup.use_preset(f, 'new') }); },

  // ---------- schema helpers ----------
  param(path) {
    let params = this.schema.params; let p = null;
    path.forEach((k) => { p = params.find((x) => x.key === k); params = p && p.item_schema ? p.item_schema.params : []; });
    return p;
  },
  options(path) { return this.param(path).options.map((o) => ({ value: o, label: OPTION_LABELS[o] || o })); },
  cellDefaults() { return JSON.parse(JSON.stringify(this.param(['columns']).item_schema.params.find((p) => p.key === 'cells').item_schema.defaults)); },
  columnDefaults() { return JSON.parse(JSON.stringify(this.param(['columns']).item_schema.defaults)); },

  // ---------- rendering ----------
  render() { this.renderToolbar(); this.drawScene(); this.renderPanel(); this.renderAdvanced(); },

  renderToolbar() {
    ['width', 'height', 'depth'].forEach((k) => {
      const num = document.getElementById('dim-' + k); const rng = document.getElementById('rng-' + k);
      num.value = this.state[k]; rng.value = this.state[k];
      num.onchange = () => { const v = parseFloat(num.value); if (!Number.isNaN(v)) { this.state[k] = v; rng.value = v; this.changed(); } };
      rng.oninput = () => { this.state[k] = parseFloat(rng.value); num.value = rng.value; this.changed(); };
    });
    Cards.radio(document.getElementById('view-cards'), { options: VIEWS, value: this.view, icons: 'view', small: true,
      onChange: (v) => { this.view = v; this.drawScene(); } });
  },

  drawScene() {
    const host = document.getElementById('drawing');
    if (!this.scene) return;
    Drawing.render(host, this.scene, {
      view: this.view, selection: this.selection,
      onSelect: (t) => this.select(t),
      onHover: (b) => { host.querySelectorAll('rect.box.hover').forEach((r) => r.classList.remove('hover')); if (b) { const r = host.querySelector(`[data-id="${b.id}"]`); if (r) r.classList.add('hover'); } },
      onEditDim: (d, pos) => this.editDim(d, pos)
    });
  },

  select(t) {
    this.selection = t;
    if (t.kind === 'construction') this.openAdvanced('construction');
    this.drawScene(); this.renderPanel();
  },

  editDim(dim, pos) {
    const host = document.getElementById('drawing');
    host.querySelectorAll('.dim-input').forEach((i) => i.remove());
    const input = el('input', { class: 'dim-input', type: 'number', value: dim.value });
    input.style.left = (pos.x - 10) + 'px'; input.style.top = (pos.y - 4) + 'px';
    const commit = () => { const v = parseFloat(input.value); input.remove(); if (!Number.isNaN(v) && v > 0) this.setPath(dim.edit, v); };
    input.onkeydown = (e) => { if (e.key === 'Enter') commit(); if (e.key === 'Escape') input.remove(); };
    input.onblur = commit;
    host.appendChild(input); input.focus(); input.select();
  },

  // 'columns.1.cells.0.height' → sets value and switches the size mode to mm.
  setPath(path, value) {
    const keys = path.split('.'); let obj = this.state;
    keys.slice(0, -1).forEach((k) => { obj = obj[/^\d+$/.test(k) ? Number(k) : k]; });
    const last = keys[keys.length - 1];
    obj[last] = value;
    if (last === 'width' && keys.length > 1) obj.width_mode = 'mm';
    if (last === 'height' && keys.length > 1) obj.height_mode = 'mm';
    this.changed(); this.renderToolbar(); this.renderPanel();
  },

  // ---------- panels ----------
  renderPanel() {
    const body = document.getElementById('panel-body'); body.innerHTML = '';
    const s = this.selection;
    if (s.kind === 'column' && this.state.columns[s.column - 1]) this.panelColumn(body, s.column - 1);
    else if (s.kind === 'cell' && this.state.columns[s.column - 1] && this.state.columns[s.column - 1].cells[s.cell - 1]) this.panelCell(body, s.column - 1, s.cell - 1);
    else if (s.kind === 'base') this.panelBase(body);
    else if (s.kind === 'construction') this.panelConstruction(body);
    else this.panelGlobal(body);
  },

  num(obj, key, label, { unit = 'mm', min, max, step = 1, after } = {}) {
    const input = el('input', { type: 'number', value: obj[key], step });
    if (min != null) input.min = min; if (max != null) input.max = max;
    input.onchange = () => { const v = parseFloat(input.value); if (!Number.isNaN(v)) { obj[key] = v; this.changed(); if (after) after(); } };
    return el('label', { class: 'row' }, el('span', {}, label), input, el('em', {}, unit));
  },
  toggle(obj, key, label, { after } = {}) {
    const input = el('input', { type: 'checkbox' }); input.checked = !!obj[key];
    input.onchange = () => { obj[key] = input.checked; this.changed(); if (after) after(); };
    return el('label', { class: 'row' }, el('span', {}, label), input, el('em'));
  },
  cards(obj, key, path, icons, { small = false, after } = {}) {
    const c = el('div');
    Cards.radio(c, { options: this.options(path), value: obj[key], icons, small, onChange: (v) => { obj[key] = v; this.changed(); if (after) after(); } });
    return c;
  },
  sizeRow(obj, modeKey, valueKey, label) {
    const wrap = el('div');
    wrap.append(el('h3', {}, label));
    const num = el('input', { type: 'number', value: obj[valueKey], step: 1 });
    num.disabled = obj[modeKey] === 'auto';
    num.onchange = () => { const v = parseFloat(num.value); if (!Number.isNaN(v)) { obj[valueKey] = v; this.changed(); } };
    const modes = el('div');
    const optPath = modeKey === 'width_mode' ? ['columns', 'width_mode'] : ['columns', 'cells', 'height_mode'];
    Cards.radio(modes, { options: this.options(optPath), value: obj[modeKey], icons: 'mode', small: true,
      onChange: (v) => { obj[modeKey] = v; num.disabled = v === 'auto'; this.changed(); } });
    wrap.append(modes, el('label', { class: 'row' }, el('span', {}, obj[modeKey] === 'ratio' ? 'Pomer' : 'Hodnota'), num, el('em', {}, 'mm')));
    return wrap;
  },
  h3(t) { return el('h3', {}, t); },

  panelGlobal(body) {
    const st = this.state;
    body.append(el('h2', {}, 'Skriňa'));
    body.append(this.h3('Osadenie'));
    body.append(this.cards(st, 'placement', ['placement'], 'placement', { after: () => { this.applyPlacement(); this.renderPanel(); } }));
    body.append(this.h3('Dvere'));
    body.append(this.toggle(st, 'doors_enabled', 'Dvere (vypnuté = otvorený korpus)', { after: () => this.renderPanel() }));
    if (st.doors_enabled) {
      body.append(this.cards(st.doors, 'type', ['doors', 'type'], 'doors'));
      body.append(this.h3('Uloženie čiel'));
      body.append(this.cards(st.doors, 'mount', ['doors', 'mount'], 'mount', { small: true }));
      body.append(this.h3('Zobrazenie dverí'));
      body.append(this.cards(st, 'door_display', ['door_display'], null, { small: true }));
      if (st.door_display === 'open') body.append(this.num(st, 'open_angle', 'Uhol otvorenia', { unit: '°' }));
    }
    body.append(this.h3('Úchytka'));
    body.append(this.handleFields(st.handle));
    body.append(this.h3('Stĺpce'));
    const row = el('div', { class: 'btnrow' });
    st.columns.forEach((c, i) => row.append(el('button', { type: 'button', onclick: () => this.select({ kind: 'column', column: i + 1 }) }, `Stĺpec ${i + 1}`)));
    row.append(el('button', { type: 'button', onclick: () => { st.columns.push(this.columnDefaults()); this.changed(); this.select({ kind: 'column', column: st.columns.length }); } }, '+ stĺpec'));
    body.append(row);
    body.append(this.h3('Spodok a vrch'));
    body.append(el('button', { type: 'button', onclick: () => this.select({ kind: 'base' }) }, 'Nožičky / sokel / lišty…'));
  },

  applyPlacement() {
    const st = this.state;
    if (st.placement === 'free') { st.gap_left = 0; st.gap_right = 0; st.filler_left = false; st.filler_right = false; }
    if (st.placement === 'corner_left') { st.gap_right = 0; st.filler_right = false; }
    if (st.placement === 'corner_right') { st.gap_left = 0; st.filler_left = false; }
    this.changed();
  },

  handleFields(h) {
    const wrap = el('div');
    wrap.append(this.cards(h, 'type', ['handle', 'type'], 'handle', { after: () => this.renderPanel() }));
    if (h.type === 'drilled') { wrap.append(this.num(h, 'hole_spacing', 'Rozteč otvorov'), this.num(h, 'offset_edge', 'Odsadenie od hrany')); }
    if (h.type === 'profile') { wrap.append(this.num(h, 'profile_height', 'Výška profilu'), this.cards(h, 'profile_position', ['handle', 'profile_position'], null, { small: true })); }
    return wrap;
  },

  panelColumn(body, i) {
    const st = this.state; const col = st.columns[i];
    body.append(el('h2', {}, `Stĺpec ${i + 1}`));
    const bar = el('div', { class: 'btnrow' });
    bar.append(el('button', { type: 'button', title: 'Posunúť doľava', onclick: () => { if (i > 0) { st.columns.splice(i - 1, 2, st.columns[i], st.columns[i - 1]); this.changed(); this.select({ kind: 'column', column: i }); } } }, '◀'));
    bar.append(el('button', { type: 'button', title: 'Posunúť doprava', onclick: () => { if (i < st.columns.length - 1) { st.columns.splice(i, 2, st.columns[i + 1], st.columns[i]); this.changed(); this.select({ kind: 'column', column: i + 2 }); } } }, '▶'));
    bar.append(el('button', { type: 'button', onclick: () => { st.columns.splice(i + 1, 0, JSON.parse(JSON.stringify(col))); this.changed(); this.select({ kind: 'column', column: i + 2 }); } }, '⧉ duplikovať'));
    bar.append(el('button', { type: 'button', class: 'danger', onclick: () => { if (st.columns.length > 1) { st.columns.splice(i, 1); this.changed(); this.select({ kind: 'global' }); } } }, '✕ odstrániť'));
    body.append(bar);
    body.append(this.sizeRow(col, 'width_mode', 'width', 'Šírka stĺpca'));
    body.append(this.h3('Náplň stĺpca (moduly)'));
    const mods = el('div', { class: 'cards modules' });
    this.modules.forEach((m) => {
      const b = el('button', { type: 'button', class: 'card' });
      b.innerHTML = `<span class="icon">${Cards.moduleSvg(m)}</span><span class="label">${m.label}</span>`;
      b.onclick = () => { col.cells = m.cells.map((c) => Object.assign(this.cellDefaults(), c)); this.changed(); this.renderPanel(); };
      mods.append(b);
    });
    body.append(mods);
    body.append(this.h3('Polia (zhora nadol)'));
    const list = el('div', { class: 'cell-list' });
    col.cells.forEach((c, j) => list.append(el('button', { type: 'button', onclick: () => this.select({ kind: 'cell', column: i + 1, cell: j + 1 }) }, `Pole ${j + 1}: ${OPTION_LABELS[c.content] || c.content}${c.height_mode === 'mm' ? ` (${c.height} mm)` : ''}`)));
    list.append(el('button', { type: 'button', onclick: () => { col.cells.push(this.cellDefaults()); this.changed(); this.select({ kind: 'cell', column: i + 1, cell: col.cells.length }); } }, '+ pole dole'));
    body.append(list);
    body.append(this.h3('Dvere'));
    body.append(this.toggle(col, 'doors_override', 'Vlastné nastavenie dverí', { after: () => this.renderPanel() }));
    if (col.doors_override) { body.append(this.cards(col.doors, 'type', ['doors', 'type'], 'doors'), this.cards(col.doors, 'mount', ['doors', 'mount'], 'mount', { small: true })); }
    body.append(this.h3('Úchytka'));
    body.append(this.toggle(col, 'handle_override', 'Vlastná úchytka', { after: () => this.renderPanel() }));
    if (col.handle_override) body.append(this.handleFields(col.handle));
  },

  panelCell(body, i, j) {
    const col = this.state.columns[i]; const cell = col.cells[j];
    body.append(el('h2', {}, `Stĺpec ${i + 1} · Pole ${j + 1}`));
    const bar = el('div', { class: 'btnrow' });
    bar.append(el('button', { type: 'button', onclick: () => this.select({ kind: 'column', column: i + 1 }) }, '↑ stĺpec'));
    bar.append(el('button', { type: 'button', title: 'Posunúť vyššie', onclick: () => { if (j > 0) { col.cells.splice(j - 1, 2, col.cells[j], col.cells[j - 1]); this.changed(); this.select({ kind: 'cell', column: i + 1, cell: j }); } } }, '▲'));
    bar.append(el('button', { type: 'button', title: 'Posunúť nižšie', onclick: () => { if (j < col.cells.length - 1) { col.cells.splice(j, 2, col.cells[j + 1], col.cells[j]); this.changed(); this.select({ kind: 'cell', column: i + 1, cell: j + 2 }); } } }, '▼'));
    bar.append(el('button', { type: 'button', onclick: () => { col.cells.splice(j + 1, 0, this.cellDefaults()); this.changed(); this.select({ kind: 'cell', column: i + 1, cell: j + 2 }); } }, '+ pole pod'));
    bar.append(el('button', { type: 'button', class: 'danger', onclick: () => { if (col.cells.length > 1) { col.cells.splice(j, 1); this.changed(); this.select({ kind: 'column', column: i + 1 }); } } }, '✕'));
    body.append(bar);
    body.append(this.sizeRow(cell, 'height_mode', 'height', 'Výška poľa'));
    body.append(this.h3('Obsah'));
    body.append(this.cards(cell, 'content', ['columns', 'cells', 'content'], 'content', { after: () => this.renderPanel() }));
    if (cell.content === 'shelves') body.append(this.num(cell, 'shelves_count', 'Počet políc', { unit: 'ks', min: 0 }));
    if (cell.content === 'rod') body.append(this.num(cell, 'rod_offset_top', 'Tyč – odsadenie zhora'));
    if (cell.content === 'drawers' || cell.content === 'inner_drawers') {
      body.append(this.num(cell, 'drawers_count', 'Počet zásuviek', { unit: 'ks', min: 1 }));
      const input = el('input', { type: 'text', value: cell.drawer_heights || '' });
      input.onchange = () => { cell.drawer_heights = input.value; this.changed(); };
      body.append(el('label', { class: 'row' }, el('span', {}, 'Výšky čiel zhora (mm, čiarkou; prázdne = rovnomerne)'), input, el('em')));
      body.append(this.h3('Systém zásuviek (globálne)'));
      body.append(this.cards(this.state, 'drawer_system', ['drawer_system'], 'system', { small: true }));
    }
  },

  panelBase(body) {
    const st = this.state;
    body.append(el('h2', {}, 'Spodok, vrch a odsadenia'));
    body.append(this.h3('Spodok'));
    body.append(this.cards(st, 'base_type', ['base_type'], 'base', { after: () => this.renderPanel() }));
    if (st.base_type !== 'floor') body.append(this.num(st, 'base_height', 'Výška spodku'));
    if (st.base_type === 'legs') body.append(this.toggle(st, 'bottom_strip', 'Krycia lišta dole (sokel)', { after: () => this.renderPanel() }));
    if (st.base_type === 'plinth' || (st.base_type === 'legs' && st.bottom_strip)) { body.append(this.num(st, 'bottom_strip_setback', 'Zapustenie sokla'), this.num(st, 'strip_floor_clearance', 'Medzera od podlahy')); }
    body.append(this.h3('Vrch'));
    body.append(this.num(st, 'gap_top', 'Odsadenie od stropu', { after: () => this.renderPanel() }));
    if (st.gap_top > 0) { body.append(this.toggle(st, 'top_strip', 'Krycia lišta hore', { after: () => this.renderPanel() })); if (st.top_strip) body.append(this.num(st, 'top_strip_height', 'Výška lišty (0 = celé odsadenie)'), this.num(st, 'top_strip_setback', 'Zapustenie lišty')); }
    body.append(this.h3('Steny'));
    if (st.placement === 'between_walls' || st.placement === 'corner_left') { body.append(this.num(st, 'gap_left', 'Odsadenie od steny vľavo', { after: () => this.renderPanel() })); if (st.gap_left > 0) body.append(this.toggle(st, 'filler_left', 'Zaslepovacia lišta vľavo')); }
    if (st.placement === 'between_walls' || st.placement === 'corner_right') { body.append(this.num(st, 'gap_right', 'Odsadenie od steny vpravo', { after: () => this.renderPanel() })); if (st.gap_right > 0) body.append(this.toggle(st, 'filler_right', 'Zaslepovacia lišta vpravo')); }
    body.append(el('button', { type: 'button', onclick: () => this.select({ kind: 'global' }) }, '← späť na skriňu'));
  },

  panelConstruction(body) {
    body.append(el('h2', {}, 'Konštrukcia korpusu'));
    body.append(el('p', {}, 'Hrúbky, rohové spoje, zadná stena a odsadenia panelov sú v Rozšírených nastaveniach (záložka Konštrukcia) pod nákresom.'));
    body.append(el('button', { type: 'button', onclick: () => this.select({ kind: 'global' }) }, '← späť na skriňu'));
  },

  // ---------- advanced ----------
  renderAdvanced() {
    const tabs = document.getElementById('adv-tabs'); tabs.innerHTML = '';
    ADVANCED_GROUPS.forEach(([key, label]) => {
      tabs.append(el('button', { type: 'button', class: key === this.advancedTab ? 'active' : '', onclick: () => { this.advancedTab = key; this.renderAdvanced(); } }, label));
    });
    Form.render(document.getElementById('adv-panels'), this.schema, this.state, [this.advancedTab], () => this.changed());
  },
  openAdvanced(tab) {
    this.advancedTab = tab;
    document.getElementById('adv-body').classList.remove('hidden');
    document.getElementById('adv-toggle').textContent = '▾ Rozšírené nastavenia';
    this.renderAdvanced();
  },

  // ---------- messages ----------
  renderMessages() {
    const box = document.getElementById('messages'); box.innerHTML = '';
    this.errors.forEach((e) => box.appendChild(this.msg('error', e)));
    this.warnings.forEach((w) => box.appendChild(this.msg('warn', w)));
  },
  renderInfo() {
    const info = document.getElementById('info'); const r = this.info;
    if (!r || r.inner_w == null) { info.textContent = ''; return; }
    let html = `<b>Vnútorné rozmery:</b> ${r.inner_w} × ${r.inner_h} × ${r.inner_d} mm · korpus ${r.corpus_w} × ${r.corpus_h} × ${r.corpus_d}`;
    (r.columns || []).forEach((c) => { html += `<br>S${c.index}: ${c.inner_w} mm – ` + c.cells.map((cell) => `P${cell.index} ${cell.inner_h} (${OPTION_LABELS[cell.content] || cell.content})`).join(', '); });
    info.innerHTML = html;
  },
  msg(cls, text) { const d = el('div', { class: 'msg ' + cls }); d.textContent = text; return d; },

  requestState(attempt) {
    if (this.schema) return;
    if (window.sketchup && sketchup.ready) sketchup.ready();
    if (attempt < 20) setTimeout(() => this.requestState(attempt + 1), 250);
    else this.setResult({ errors: ['Dialóg nedostal dáta zo SketchUpu – zatvor ho a otvor znova.'] });
  }
};
window.Skrine = Skrine;

window.onerror = (msg, src, line) => {
  const box = document.getElementById('messages');
  if (box) box.appendChild(Skrine.msg('error', 'JS: ' + msg + ' (' + line + ')'));
  if (window.sketchup && sketchup.log) sketchup.log('JS error: ' + msg + ' @' + src + ':' + line);
};

window.addEventListener('DOMContentLoaded', () => {
  const $ = (id) => document.getElementById(id);
  $('btn-apply').onclick = () => Skrine.apply();
  $('chk-auto').onchange = (e) => { Skrine.auto = e.target.checked; if (Skrine.auto) Skrine.apply(); };
  $('btn-cutlist').onclick = () => sketchup.cutlist();
  $('btn-new').onclick = () => sketchup.new_object();
  $('btn-gallery').onclick = () => sketchup.gallery();
  $('gallery-close').onclick = () => Gallery.hide();
  $('btn-presets').onclick = () => $('presets-menu').classList.toggle('hidden');
  $('btn-save-named').onclick = () => { $('presets-menu').classList.add('hidden'); const name = window.prompt('Názov presetu:'); if (name) sketchup.save_named_preset(JSON.stringify(Skrine.state), name); };
  $('btn-save-file').onclick = () => { $('presets-menu').classList.add('hidden'); sketchup.save_preset(JSON.stringify(Skrine.state)); };
  $('btn-load-file').onclick = () => { $('presets-menu').classList.add('hidden'); sketchup.load_preset(); };
  $('adv-toggle').onclick = () => { const b = $('adv-body'); b.classList.toggle('hidden'); $('adv-toggle').textContent = (b.classList.contains('hidden') ? '▸' : '▾') + ' Rozšírené nastavenia'; if (!b.classList.contains('hidden')) Skrine.renderAdvanced(); };
  window.addEventListener('resize', () => Skrine.drawScene());
  $('info').textContent = 'Čakám na dáta zo SketchUpu…';
  Skrine.requestState(0);
});
window.addEventListener('load', () => Skrine.requestState(0));
