/* Browser demo bridge: runs the plugin's Ruby model in WebAssembly and exposes the
   same `window.sketchup` API the SketchUp dialog provides. */
/* global Skrine */
(function () {
  const WASM_URL = 'https://cdn.jsdelivr.net/npm/@ruby/3.3-wasm-wasi@2.10.1/dist/ruby+stdlib.wasm';
  const status = (text) => { const el = document.getElementById('boot-status'); if (el) el.textContent = text; };
  let vm = null;
  const queue = [];

  function call(name, payload) {
    if (!vm) return null;
    window.skrineCall = name;
    window.skrinePayload = payload ? JSON.stringify(payload) : '';
    window.skrineResult = '';
    vm.eval('Skrine::Demo.run');
    try {
      return JSON.parse(window.skrineResult || '{}');
    } catch (e) {
      return { errors: ['Neplatná odpoveď z modelu: ' + e.message] };
    }
  }

  window.sketchup = {
    ready() { if (vm) Skrine.init(call('init')); else queue.push(() => Skrine.init(call('init'))); },
    preview(json, seq) { const r = call('preview', { state: JSON.parse(json), seq: seq }); if (r) Skrine.setPreview(r); },
    apply(json, seq) {
      const r = call('apply', { state: JSON.parse(json), seq: seq });
      if (!r) return;
      Skrine.setResult(r);
      if (r.demo) status(r.demo);
    },
    gallery() { const r = call('gallery'); if (r) Skrine.showGallery(r); },
    use_preset(file) { const r = call('preset', { file: file }); if (r) Skrine.init(r); },
    cutlist(json) {
      const r = call('cutlist', { state: JSON.parse(json || JSON.stringify(Skrine.state)) });
      if (!r) return;
      if (r.errors && r.errors.length) { window.alert(r.errors.join('\n')); return; }
      const blob = new Blob([r.html], { type: 'text/html;charset=utf-8' });
      window.open(URL.createObjectURL(blob), '_blank');
    },
    save_named_preset() { window.alert('Ukladanie presetov funguje v SketchUpe – demo beží len v prehliadači.'); },
    save_preset() {
      const blob = new Blob([JSON.stringify(Skrine.state, null, 2)], { type: 'application/json' });
      const a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = 'skrina.json';
      a.click();
    },
    load_preset() { window.alert('Načítanie zo súboru funguje v SketchUpe; v demu použi Galériu skríň.'); },
    new_object() { const r = call('init'); if (r) Skrine.init(r); },
    log(message) { console.log('[Skrine]', message); }
  };

  async function boot() {
    try {
      status('Sťahujem Ruby (WebAssembly)…');
      const response = await fetch(WASM_URL);
      const module = await WebAssembly.compileStreaming(response);
      status('Spúšťam model…');
      const api = window['ruby-wasm-wasi'];   // UMD global of @ruby/3.3-wasm-wasi
      if (!api || !api.DefaultRubyVM) throw new Error('ruby.wasm sa nenačítal');
      const result = await api.DefaultRubyVM(module);
      vm = result.vm;
      const source = await (await fetch('skrine.rb')).text();
      vm.eval(source);
      document.getElementById('boot').classList.add('hidden');
      queue.splice(0).forEach((fn) => fn());
      if (!Skrine.schema) Skrine.init(call('init'));
    } catch (error) {
      status('Demo sa nepodarilo spustiť: ' + error.message);
      console.error(error);
    }
  }

  window.addEventListener('DOMContentLoaded', boot);
}());
