/* Skrine editor: renders a form from the parameter schema sent by Ruby. */
/* global sketchup */
const Skrine = {
  schema: null, state: null, auto: false, timer: null, tab: null,

  init(payload) {
    this.schema = payload.schema;
    this.state = payload.state;
    document.getElementById('title').textContent = payload.label;
    this.render();
    this.setResult(payload.result || {});
  },

  render() {
    const tabs = document.getElementById('tabs');
    const panels = document.getElementById('panels');
    tabs.innerHTML = '';
    panels.innerHTML = '';
    this.schema.groups.forEach((g) => {
      const b = document.createElement('button');
      b.type = 'button';
      b.textContent = g.label;
      b.dataset.tab = g.key;
      b.onclick = () => this.showTab(g.key);
      tabs.appendChild(b);
      const panel = document.createElement('div');
      panel.className = 'panel';
      panel.id = 'panel-' + g.key;
      this.schema.params.filter((p) => p.group === g.key).forEach((p) => panel.appendChild(this.field(p, this.state, p.key)));
      panels.appendChild(panel);
    });
    this.showTab(this.tab || this.schema.groups[0].key);
  },

  showTab(key) {
    this.tab = key;
    document.querySelectorAll('#tabs button').forEach((b) => b.classList.toggle('active', b.dataset.tab === key));
    document.querySelectorAll('.panel').forEach((p) => p.classList.toggle('active', p.id === 'panel-' + key));
  },

  field(p, obj, key) {
    if (p.type === 'object') return this.objectField(p, obj[key]);
    if (p.type === 'list') return this.listField(p, obj, key);
    return this.scalarField(p, obj, key);
  },

  scalarField(p, obj, key) {
    const row = document.createElement('label');
    row.className = 'row';
    const span = document.createElement('span');
    span.textContent = p.label;
    row.appendChild(span);
    let input;
    if (p.type === 'boolean') {
      input = document.createElement('input');
      input.type = 'checkbox';
      input.checked = !!obj[key];
      input.onchange = () => { obj[key] = input.checked; this.changed(); };
    } else if (p.type === 'enum') {
      input = document.createElement('select');
      p.options.forEach((o) => {
        const opt = document.createElement('option');
        opt.value = o;
        opt.textContent = this.optionLabel(o);
        input.appendChild(opt);
      });
      input.value = String(obj[key]);
      input.onchange = () => { obj[key] = input.value; this.changed(); };
    } else if (p.type === 'string') {
      input = document.createElement('input');
      input.type = 'text';
      input.value = obj[key] == null ? '' : obj[key];
      input.onchange = () => { obj[key] = input.value; this.changed(); };
    } else {
      input = document.createElement('input');
      input.type = 'number';
      input.step = p.type === 'integer' ? '1' : 'any';
      if (p.min != null) input.min = p.min;
      if (p.max != null) input.max = p.max;
      input.value = obj[key];
      input.onchange = () => {
        const v = p.type === 'integer' ? parseInt(input.value, 10) : parseFloat(input.value);
        if (!Number.isNaN(v)) { obj[key] = v; this.changed(); }
      };
    }
    row.appendChild(input);
    const unit = document.createElement('em');
    unit.textContent = p.type === 'number' && p.unit ? p.unit : '';
    row.appendChild(unit);
    return row;
  },

  objectField(p, obj) {
    const fs = document.createElement('fieldset');
    const lg = document.createElement('legend');
    lg.textContent = p.label;
    fs.appendChild(lg);
    p.item_schema.params.forEach((sp) => fs.appendChild(this.field(sp, obj, sp.key)));
    return fs;
  },

  listField(p, obj, key) {
    const wrap = document.createElement('div');
    wrap.className = 'list';
    const head = document.createElement('div');
    head.className = 'list-head';
    head.textContent = p.label;
    wrap.appendChild(head);
    const items = obj[key];
    const add = document.createElement('button');
    add.type = 'button';
    add.className = 'add';
    add.textContent = '+ Pridať';
    const redraw = () => {
      wrap.querySelectorAll(':scope > .item').forEach((e) => e.remove());
      items.forEach((_, i) => wrap.insertBefore(this.listItem(p, items, i, redraw), add));
    };
    add.onclick = () => { items.push(JSON.parse(JSON.stringify(p.item_schema.defaults))); redraw(); this.changed(); };
    wrap.appendChild(add);
    redraw();
    return wrap;
  },

  listItem(p, items, i, redraw) {
    const card = document.createElement('div');
    card.className = 'item';
    const bar = document.createElement('div');
    bar.className = 'item-bar';
    const title = document.createElement('strong');
    title.textContent = '#' + (i + 1);
    bar.appendChild(title);
    const btn = (txt, tip, fn) => {
      const b = document.createElement('button');
      b.type = 'button';
      b.textContent = txt;
      b.title = tip;
      b.onclick = () => { fn(); redraw(); this.changed(); };
      bar.appendChild(b);
    };
    btn('▲', 'Posunúť vyššie', () => { if (i > 0) items.splice(i - 1, 2, items[i], items[i - 1]); });
    btn('▼', 'Posunúť nižšie', () => { if (i < items.length - 1) items.splice(i, 2, items[i + 1], items[i]); });
    btn('⧉', 'Duplikovať', () => items.splice(i + 1, 0, JSON.parse(JSON.stringify(items[i]))));
    btn('✕', 'Odstrániť', () => { if (items.length > 1) items.splice(i, 1); });
    card.appendChild(bar);
    p.item_schema.params.forEach((sp) => card.appendChild(this.field(sp, items[i], sp.key)));
    return card;
  },

  optionLabel(o) { return Skrine.OPTION_LABELS[o] || o; },

  changed() {
    if (!this.auto) return;
    clearTimeout(this.timer);
    this.timer = setTimeout(() => this.apply(), 300);
  },

  apply() { sketchup.apply(JSON.stringify(this.state)); },

  setResult(r) {
    const box = document.getElementById('messages');
    box.innerHTML = '';
    (r.errors || []).forEach((e) => box.appendChild(this.msg('error', e)));
    (r.warnings || []).forEach((w) => box.appendChild(this.msg('warn', w)));
    const info = document.getElementById('info');
    if (r.info && r.info.inner_w != null) {
      let html = '<b>Vnútorné rozmery:</b> ' + r.info.inner_w + ' × ' + r.info.inner_h + ' × ' + r.info.inner_d +
        ' mm (Š × V × H) · korpus ' + r.info.corpus_w + ' × ' + r.info.corpus_h + ' × ' + r.info.corpus_d;
      (r.info.columns || []).forEach((c) => {
        html += '<br>S' + c.index + ': ' + c.inner_w + ' mm – ' +
          c.cells.map((cell) => 'P' + cell.index + ' ' + cell.inner_h + ' (' + this.optionLabel(cell.content) + ')').join(', ');
      });
      info.innerHTML = html;
    } else {
      info.innerHTML = '';
    }
  },

  msg(cls, text) {
    const d = document.createElement('div');
    d.className = 'msg ' + cls;
    d.textContent = text;
    return d;
  }
};

Skrine.OPTION_LABELS = {
  inset: 'medzi bokmi / vnorené', overlay: 'cez bok / nalozené', half_overlay: 'polonalozené',
  none: 'žiadne', drilled: 'navŕtaná', profile: 'integrovaný profil',
  horizontal: 'vodorovná', vertical: 'zvislá', top: 'hore', bottom: 'dole',
  single_left: '1 krídlo, pánty vľavo', single_right: '1 krídlo, pánty vpravo', double: '2 krídla', flap_up: 'výklop hore',
  auto: 'auto', mm: 'mm', ratio: 'pomer',
  shelves: 'police', rod: 'vešiaková tyč', drawers: 'zásuvky', inner_drawers: 'vnorené zásuvky', empty: 'prázdne',
  groove: 'v drážke (HDF)', legs: 'nožičky', plinth: 'sokel medzi bokmi', floor: 'na podlahe',
  closed: 'zatvorené', open: 'otvorené',
  front_only: 'len čelo + výsuv', wood_box: 'drevený box', blum_legrabox: 'Blum LEGRABOX',
  blum_tandembox: 'Blum TANDEMBOX', blum_merivobox: 'Blum MERIVOBOX',
  dowels: 'kolíky', confirmat: 'konfirmáty', cam_lock: 'excentre',
  front: 'predná hrana', all: 'všetky hrany', wood: 'drevený', metal: 'kovový'
};

window.Skrine = Skrine;

// Report JS errors back to the Ruby Console so they are not lost in the WebView.
window.onerror = (msg, src, line) => {
  const box = document.getElementById('messages');
  if (box) box.appendChild(Skrine.msg('error', 'JS: ' + msg + ' (' + line + ')'));
  if (window.sketchup && sketchup.log) sketchup.log('JS error: ' + msg + ' @' + src + ':' + line);
};

// Ask Ruby for the state until Skrine.init has run (the bridge is not always
// ready at DOMContentLoaded on every platform).
Skrine.requestState = function requestState(attempt) {
  if (this.schema) return;
  if (window.sketchup && sketchup.ready) sketchup.ready();
  if (attempt < 20) setTimeout(() => this.requestState(attempt + 1), 250);
  else this.setResult({ errors: ['Dialóg nedostal dáta zo SketchUpu – zatvor ho a otvor znova (Extensions › Skrine › Upraviť označenú skriňu).'] });
};

window.addEventListener('DOMContentLoaded', () => {
  document.getElementById('btn-apply').onclick = () => Skrine.apply();
  document.getElementById('chk-auto').onchange = (e) => { Skrine.auto = e.target.checked; if (Skrine.auto) Skrine.apply(); };
  document.getElementById('btn-save').onclick = () => sketchup.save_preset(JSON.stringify(Skrine.state));
  document.getElementById('btn-load').onclick = () => sketchup.load_preset();
  document.getElementById('btn-cutlist').onclick = () => sketchup.cutlist();
  document.getElementById('btn-new').onclick = () => sketchup.new_object();
  document.getElementById('info').textContent = 'Čakám na dáta zo SketchUpu…';
  Skrine.requestState(0);
});
window.addEventListener('load', () => Skrine.requestState(0));
