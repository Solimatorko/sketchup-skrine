/* Schema-driven form for the advanced groups. */
/* global Cards ICONS */
/* exported Form */
const Form = {
  ICON_GROUPS: { back_mode: 'back', corner_left: 'corner', corner_right: 'corner', joinery: 'joinery', drawer_system: 'system',
    type: null, mount: 'mount', base_type: 'base' },
  LABELS: {},   // filled by app.js (OPTION_LABELS)

  render(container, schema, state, groupKeys, onChange) {
    container.innerHTML = '';
    this.onChange = onChange;
    schema.params.filter((p) => groupKeys.includes(p.group)).forEach((p) => container.appendChild(this.field(p, state, p.key)));
  },

  field(p, obj, key) {
    if (p.type === 'object') return this.objectField(p, obj[key]);
    if (p.type === 'list') return this.listField(p, obj, key);
    return this.scalarField(p, obj, key);
  },

  scalarField(p, obj, key) {
    const iconGroup = this.ICON_GROUPS[key];
    if (p.type === 'enum' && iconGroup && ICONS[iconGroup + '.' + p.options[0]]) {
      const wrap = document.createElement('div');
      const lbl = document.createElement('div'); lbl.textContent = p.label; lbl.className = 'cards-label';
      wrap.appendChild(lbl);
      const cards = document.createElement('div');
      wrap.appendChild(cards);
      Cards.radio(cards, { options: p.options.map((o) => ({ value: o, label: this.LABELS[o] || o })), value: obj[key], icons: iconGroup,
        small: true, onChange: (v) => { obj[key] = v; this.onChange(); } });
      return wrap;
    }
    const row = document.createElement('label');
    row.className = 'row';
    const span = document.createElement('span'); span.textContent = p.label; row.appendChild(span);
    let input;
    if (p.type === 'boolean') {
      input = document.createElement('input'); input.type = 'checkbox'; input.checked = !!obj[key];
      input.onchange = () => { obj[key] = input.checked; this.onChange(); };
    } else if (p.type === 'enum') {
      input = document.createElement('select');
      p.options.forEach((o) => { const opt = document.createElement('option'); opt.value = o; opt.textContent = this.LABELS[o] || o; input.appendChild(opt); });
      input.value = String(obj[key]);
      input.onchange = () => { obj[key] = input.value; this.onChange(); };
    } else if (p.type === 'string') {
      input = document.createElement('input'); input.type = 'text'; input.value = obj[key] == null ? '' : obj[key];
      input.onchange = () => { obj[key] = input.value; this.onChange(); };
    } else {
      input = document.createElement('input'); input.type = 'number'; input.step = p.type === 'integer' ? '1' : 'any';
      if (p.min != null) input.min = p.min; if (p.max != null) input.max = p.max; input.value = obj[key];
      input.onchange = () => { const v = p.type === 'integer' ? parseInt(input.value, 10) : parseFloat(input.value); if (!Number.isNaN(v)) { obj[key] = v; this.onChange(); } };
    }
    row.appendChild(input);
    const unit = document.createElement('em'); unit.textContent = p.type === 'number' && p.unit ? p.unit : ''; row.appendChild(unit);
    return row;
  },

  objectField(p, obj) {
    const fs = document.createElement('fieldset');
    const lg = document.createElement('legend'); lg.textContent = p.label; fs.appendChild(lg);
    p.item_schema.params.forEach((sp) => fs.appendChild(this.field(sp, obj, sp.key)));
    return fs;
  },

  listField(p, obj, key) {
    const wrap = document.createElement('div'); wrap.className = 'list';
    const head = document.createElement('div'); head.className = 'list-head'; head.textContent = p.label; wrap.appendChild(head);
    const items = obj[key];
    const add = document.createElement('button'); add.type = 'button'; add.className = 'add'; add.textContent = '+ Pridať';
    const redraw = () => {
      wrap.querySelectorAll(':scope > .item').forEach((e) => e.remove());
      items.forEach((_, i) => wrap.insertBefore(this.listItem(p, items, i, redraw), add));
    };
    add.onclick = () => { items.push(JSON.parse(JSON.stringify(p.item_schema.defaults))); redraw(); this.onChange(); };
    wrap.appendChild(add);
    redraw();
    return wrap;
  },

  listItem(p, items, i, redraw) {
    const card = document.createElement('div'); card.className = 'item';
    const bar = document.createElement('div'); bar.className = 'item-bar';
    const title = document.createElement('strong'); title.textContent = '#' + (i + 1); bar.appendChild(title);
    const btn = (txt, tip, fn) => { const b = document.createElement('button'); b.type = 'button'; b.textContent = txt; b.title = tip; b.onclick = () => { fn(); redraw(); this.onChange(); }; bar.appendChild(b); };
    btn('▲', 'Posunúť vyššie', () => { if (i > 0) items.splice(i - 1, 2, items[i], items[i - 1]); });
    btn('▼', 'Posunúť nižšie', () => { if (i < items.length - 1) items.splice(i, 2, items[i + 1], items[i]); });
    btn('⧉', 'Duplikovať', () => items.splice(i + 1, 0, JSON.parse(JSON.stringify(items[i]))));
    btn('✕', 'Odstrániť', () => { if (items.length > 1) items.splice(i, 1); });
    card.appendChild(bar);
    p.item_schema.params.forEach((sp) => card.appendChild(this.field(sp, items[i], sp.key)));
    return card;
  }
};
