# Vizuálny editor (UI v2) – implementačný plán

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nahradiť schémový formulár editorom s živým SVG nákresom (klik na prvok → panel s obrázkovými kartami), knižnicou modulov stĺpca a galériou hotových skríň.

**Architecture:** Čistý Ruby `Export::Scene` prevedie `Layout` na JSON scénu (boxy s druhom/stĺpcom/poľom, klikacie polia, kóty). `UI::PreviewService` (čistý Ruby) obsluhuje `preview`/`gallery` pre dialóg aj pre dev HTTP server, takže sa UI dá vizuálne testovať v bežnom prehliadači. JS je rozdelené: `drawing.js` (SVG + interakcia), `cards.js`+`icons.js` (obrázkové voľby), `gallery.js`, `app.js` (stav, panely, rozšírený formulár, handshake).

**Tech Stack:** Ruby 3.2 (SketchUp) / testy Homebrew Ruby, minitest; vanilla JS/CSS v `UI::HtmlDialog`; dev server na `socket` stdlib.

**Spec:** `docs/superpowers/specs/2026-09-20-visual-editor-design.md` (+ pôvodný `2026-09-19-skrine-plugin-design.md`)

## Global Constraints

- Repo `~/Git/sketchup-skrine`, práca na vetve `feat/visual-editor`. Kód/komentáre anglicky, UI slovensky.
- Testy: `/opt/homebrew/opt/ruby/bin/ruby -Isrc -Itest test/run_all.rb` – zelené pred každým commitom; `node --check` na každý JS súbor; `ruby -wc` na Ruby súbory SketchUp vrstvy.
- Čistá vrstva (`core`, `data`, `wardrobe`, `export`, `ui/preview_service.rb`, `core/preset_store.rb`) bez `Sketchup`/`UI`/`Geom`.
- Súradnice mm: X šírka, Y hĺbka (predná rovina 0), Z výška. Scene JSON podľa specu §3.1; výberový model §3.2; farby: zvýraznenie `#f28c28`.
- Existujúce správanie (`apply` → `Builder.rebuild`, presety, nárezový plán) zostáva funkčné.
- Dev náhľad: `scripts/ui_server.rb` (port 8792) + prehliadač; screenshoty sú súčasť overenia úloh 6–8.

---

### Task 1: Metadáta pre nákres (stĺpec/pole na dielcoch, geometria polí, lišty, `placement`)

**Files:**
- Modify: `src/skrine/wardrobe/columns.rb`, `src/skrine/wardrobe/corpus.rb`, `src/skrine/wardrobe/params.rb`
- Test: `test/wardrobe/scene_meta_test.rb`

**Interfaces:**
- Produces: `layout.info[:columns][i]` má navyše `x:`; každé `cells[j]` má `x: z: w: h:`. Každý dielec/kovanie vytvorené obsahom poľa má `meta[:column]` a `meta[:cell]`. Lišty: `meta[:strip]` = `:plinth | :top | :filler`. Nový param `placement` (enum `between_walls corner_left corner_right free`, default `between_walls`, skupina `dims`, prvý v poradí) – model ho nepoužíva.

- [ ] **Step 1: Failing test**

`test/wardrobe/scene_meta_test.rb`:
```ruby
require 'test_helper'

class SceneMetaTest < Minitest::Test
  def test_column_and_cell_geometry_in_info
    l = wardrobe
    col = l.info[:columns][0]
    assert_in_delta 18, col[:x]
    cell = col[:cells][0]
    assert_in_delta 18, cell[:x]
    assert_in_delta 736, cell[:z]
    assert_in_delta 973, cell[:w]
    assert_in_delta 1646, cell[:h]
  end

  def test_cell_contents_carry_column_and_cell_meta
    l = wardrobe
    assert_equal({ column: 2, cell: 1 }, l.find('Polica S2/P1-1').meta.slice(:column, :cell))
    assert_equal 2, l.find('Čelo Zásuvka S1/P2-1').meta[:cell]
    assert_equal 2, l.find('Dno Zásuvka S1/P2-1').meta[:cell]
    rod = l.hardware.find { |h| h.kind == :rod }
    assert_equal 1, rod.meta[:cell]
    assert_equal 1, l.find('Polica pevná S1/1').meta[:cell]
  end

  def test_strip_meta
    l = wardrobe(gap_top: 80, top_strip: true, gap_left: 30, filler_left: true)
    assert_equal :plinth, l.find('Sokel').meta[:strip]
    assert_equal :top, l.find('Lišta horná').meta[:strip]
    assert_equal :filler, l.find('Lišta zaslepovacia Ľ').meta[:strip]
  end

  def test_placement_param_exists_and_is_ignored_by_geometry
    d = Skrine::Wardrobe::Params::SCHEMA.defaults
    assert_equal :between_walls, d[:placement]
    assert_equal :placement, Skrine::Wardrobe::Params::SCHEMA.params.keys.first
    assert wardrobe(placement: :free).valid?
  end
end
```

- [ ] **Step 2: Spusti – zlyhá.**

- [ ] **Step 3: Implementácia**

`params.rb` – v `group :dims` ako prvý riadok:
```ruby
enum :placement, :between_walls, options: %i[between_walls corner_left corner_right free], label: 'Osadenie'
```

`columns.rb`:
- v `build_columns` info: `{ index: col.index, x: x0.round(1), inner_w: w.round(1), cells: col.cells.map { |c| { index: c.index, x: x0.round(1), z: c.z0.round(1), w: w.round(1), h: c.h.round(1), inner_h: c.h.round(1), content: c.params[:content] } } }`
- `build_cells`: fixed shelf medzi poľami: `shelf_part(col, cell.z0 - ts, "Polica pevná S#{col.index}/#{cell.index}", cell: cell.index)`.
- `shelf_part(col, z, name, adjustable: false, cell: nil)` → `meta: { column: col.index, cell: cell, adjustable: adjustable }`; `build_adjustable_shelves` volá s `cell: cell.index`.
- `build_cell_content(col, cell)`: obalí dispatch tagovaním nových dielcov/kovania:
```ruby
def build_cell_content(col, cell)
  parts_before = layout.parts.size
  hw_before = layout.hardware.size
  case cell.params[:content]
  when :shelves then build_adjustable_shelves(col, cell)
  when :rod then build_rod(col, cell)
  when :drawers then build_drawers(col, cell, inner: false)
  when :inner_drawers then build_drawers(col, cell, inner: true)
  end
  (layout.parts[parts_before..] || []).each { |pt| pt.meta[:column] ||= col.index; pt.meta[:cell] ||= cell.index }
  (layout.hardware[hw_before..] || []).each { |hw| hw.meta[:column] ||= col.index; hw.meta[:cell] ||= cell.index }
end
```

`corpus.rb`: `build_bottom_strip` → `meta: { strip: :plinth }`; `build_top_strip` → `meta: { strip: :top }`; `build_filler` → `meta: { strip: :filler, side: which }`.

- [ ] **Step 4: Testy** – PASS (aj pôvodné).

- [ ] **Step 5: Commit** `feat(wardrobe): column/cell geometry and part metadata for the visual editor`

---

### Task 2: `Export::Scene` – JSON scéna nákresu

**Files:**
- Create: `src/skrine/export/scene.rb`
- Modify: `src/skrine/core.rb` (`require_relative 'export/scene'`)
- Test: `test/export/scene_test.rb`

**Interfaces:**
- Produces: `Skrine::Export::Scene.build(layout, params) -> Hash` podľa specu §3.1: `size`, `boxes[]` (`id kind column cell name category x y z dx dy dz`), `columns[]` (`index x w`), `cells[]` (`column cell x z w h content`), `dims[]` (`id axis from to at value edit`). Kinds: `side top bottom partition shelf back plinth top_strip filler door drawer_front drawer_box leg rod hardware`.

- [ ] **Step 1: Failing test**

`test/export/scene_test.rb`:
```ruby
require 'test_helper'

class SceneTest < Minitest::Test
  def scene(**over)
    params = wardrobe_params(**over)
    l = Skrine::Wardrobe::Model.new(params).layout
    assert l.valid?, l.errors.join('; ')
    Skrine::Export::Scene.build(l, params)
  end

  def test_size_and_kinds
    s = scene
    assert_equal({ w: 2000.0, h: 2400.0, d: 600.0 }, s[:size])
    kinds = s[:boxes].map { |b| b[:kind] }.uniq
    %w[side top bottom partition shelf back plinth door drawer_front drawer_box leg rod].each { |k| assert_includes kinds, k }
    door = s[:boxes].find { |b| b[:name] == 'Dvere S1 Ľ' }
    assert_equal 'door', door[:kind]
    assert_equal 1, door[:column]
    assert_in_delta 496.75, door[:dx]
  end

  def test_cells_and_columns
    s = scene
    assert_equal [1, 2], s[:columns].map { |c| c[:index] }
    assert_in_delta 973, s[:columns][0][:w]
    c = s[:cells].find { |x| x[:column] == 1 && x[:cell] == 2 }
    assert_equal 'drawers', c[:content]
    assert_in_delta 118, c[:z]
    assert_in_delta 600, c[:h]
  end

  def test_dims_are_editable_paths
    s = scene
    ids = s[:dims].map { |d| d[:id] }
    assert_includes ids, 'width'
    assert_includes ids, 'col-1'
    assert_includes ids, 'cell-1-1'
    col = s[:dims].find { |d| d[:id] == 'col-2' }
    assert_equal 'columns.1.width', col[:edit]
    assert_in_delta 973, col[:value]
    assert_in_delta 2400 + 50, col[:at]          # above the corpus top (gap_top 0)
    cell = s[:dims].find { |d| d[:id] == 'cell-2-1' }
    assert_equal 'columns.1.cells.0.height', cell[:edit]
    assert_equal 'z', cell[:axis]
  end

  def test_strips_and_hardware_kinds
    s = scene(gap_top: 80, top_strip: true)
    assert s[:boxes].any? { |b| b[:kind] == 'top_strip' }
    assert s[:boxes].any? { |b| b[:kind] == 'plinth' }
    assert_equal 6, s[:boxes].count { |b| b[:kind] == 'leg' }
  end

  def test_json_serialisable
    assert JSON.generate(scene).size > 1000
  end
end
```

- [ ] **Step 2: Spusti – zlyhá.**

- [ ] **Step 3: Implementácia**

`src/skrine/export/scene.rb`:
```ruby
module Skrine
  module Export
    # Serialisable drawing of a layout for the dialog (front/side/plan views are
    # projected in JS). Pure Ruby.
    module Scene
      module_function

      def build(layout, params)
        boxes = []
        layout.parts.each_with_index do |pt, i|
          boxes << box_hash("p#{i}", pt.box, kind_for(pt), pt.meta, pt.name, pt.category.to_s)
        end
        layout.hardware.each_with_index do |hw, i|
          next unless hw.box

          boxes << box_hash("h#{i}", hw.box, hardware_kind(hw), hw.meta, hw.name, 'hardware')
        end
        info_columns = layout.info[:columns] || []
        columns = info_columns.map { |c| { index: c[:index], x: c[:x], w: c[:inner_w] } }
        cells = info_columns.flat_map do |c|
          c[:cells].map do |cell|
            { column: c[:index], cell: cell[:index], x: cell[:x], z: cell[:z], w: cell[:w], h: cell[:h], content: cell[:content].to_s }
          end
        end
        {
          size: { w: params[:width].to_f, h: params[:height].to_f, d: params[:depth].to_f },
          boxes: boxes, columns: columns, cells: cells,
          dims: dims(params, columns, cells)
        }
      end

      def box_hash(id, b, kind, meta, name, category)
        { id: id, kind: kind, column: meta[:column], cell: meta[:cell], name: name, category: category,
          x: r(b.x), y: r(b.y), z: r(b.z), dx: r(b.dx), dy: r(b.dy), dz: r(b.dz) }
      end

      def kind_for(part)
        case part.category
        when :corpus then part.meta[:panel] ? part.meta[:panel].to_s : 'side'
        when :shelf then 'shelf'
        when :partition then 'partition'
        when :back then 'back'
        when :strip then part.meta[:strip] == :top ? 'top_strip' : 'plinth'
        when :filler then 'filler'
        when :front then part.meta[:hinge] ? 'door' : 'drawer_front'
        when :drawer_box then 'drawer_box'
        else part.category.to_s
        end
      end

      def hardware_kind(hw)
        case hw.kind
        when :rod then 'rod'
        when :leg then 'leg'
        when :drawer_side then 'drawer_box'
        else 'hardware'
        end
      end

      def dims(params, columns, cells)
        w = params[:width].to_f
        h = params[:height].to_f
        top = h - params[:gap_top].to_f
        list = [
          { id: 'width', axis: 'x', from: 0.0, to: w, at: h + 120.0, value: w, edit: 'width' },
          { id: 'height', axis: 'z', from: 0.0, to: h, at: -140.0, value: h, edit: 'height' },
          { id: 'depth', axis: 'y', from: 0.0, to: params[:depth].to_f, at: -140.0, value: params[:depth].to_f, edit: 'depth' }
        ]
        columns.each do |c|
          list << { id: "col-#{c[:index]}", axis: 'x', from: c[:x], to: r(c[:x] + c[:w]), at: top + 50.0, value: c[:w],
                    edit: "columns.#{c[:index] - 1}.width" }
        end
        cells.each do |c|
          list << { id: "cell-#{c[:column]}-#{c[:cell]}", axis: 'z', from: c[:z], to: r(c[:z] + c[:h]), at: c[:x] + 60.0,
                    value: c[:h], edit: "columns.#{c[:column] - 1}.cells.#{c[:cell] - 1}.height" }
        end
        list
      end

      def r(v)
        v.to_f.round(1)
      end
    end
  end
end
```

- [ ] **Step 4: Testy** – PASS.
- [ ] **Step 5: Commit** `feat(export): scene JSON for the visual editor`

---

### Task 3: Knižnica modulov stĺpca + úložisko presetov (čistý Ruby)

**Files:**
- Create: `src/skrine/data/column_modules.rb`, `src/skrine/core/preset_store.rb`
- Modify: `src/skrine/core.rb`, `src/skrine/sketchup/presets.rb` (deleguje na PresetStore), `src/skrine/sketchup/commands.rb` (`new_from_preset_file`)
- Test: `test/data/column_modules_test.rb`, `test/core/preset_store_test.rb`

**Interfaces:**
- `Skrine::Data::ColumnModules::MODULES` (`[{key:, label:, cells: [...]}]`), `.find(key)`, `.apply(params, column_index, key) -> new params Hash` (deep copy, cells doplnené `CELL` defaultmi), `.to_h -> [{key, label, cells}]`.
- `Skrine::Core::PresetStore`: `.builtin_dir`, `.user_dir` (mac: `~/Library/Application Support/Skrine/presets`, inak `~/.skrine/presets`), `.all -> [{file:, name:, params:}]` (name = `_name` v JSON alebo názov súboru s `-`→medzera, capitalize), `.save_named(params, name) -> path` (zapíše do user_dir `<slug>.json` s `_name`), `.read(file) -> params Hash bez `_name``. `SU::Presets.save/load` zostávajú (súborové dialógy), `SU::Presets::DIR` = `PresetStore.builtin_dir`.
- `SU::Commands.new_from_preset_file(file)`; `new_from_preset` (výber súboru) ho volá.

- [ ] **Step 1: Failing testy**

`test/data/column_modules_test.rb`:
```ruby
require 'test_helper'

class ColumnModulesTest < Minitest::Test
  M = Skrine::Data::ColumnModules

  def test_every_module_builds_a_valid_column
    M::MODULES.each do |mod|
      params = M.apply(wardrobe_params, 0, mod[:key])
      l = Skrine::Wardrobe::Model.new(params).layout
      assert l.valid?, "#{mod[:key]}: #{l.errors.join('; ')}"
    end
  end

  def test_apply_replaces_cells_and_keeps_other_columns
    before = wardrobe_params
    after = M.apply(before, 1, :shelves_5)
    assert_equal %i[rod drawers], before[:columns][0][:cells].map { |c| c[:content] }   # untouched (deep copy)
    assert_equal [:shelves], after[:columns][1][:cells].map { |c| c[:content] }
    assert_equal 5, after[:columns][1][:cells][0][:shelves_count]
    assert_equal :auto, after[:columns][1][:cells][0][:height_mode]                    # CELL defaults filled
    assert_equal %i[rod drawers], after[:columns][0][:cells].map { |c| c[:content] }
  end

  def test_unknown_module_raises
    assert_raises(ArgumentError) { M.apply(wardrobe_params, 0, :nope) }
  end

  def test_to_h_is_json_friendly
    h = M.to_h
    assert_equal M::MODULES.size, h.size
    assert h.first.key?(:label)
  end
end
```

`test/core/preset_store_test.rb`:
```ruby
require 'test_helper'
require 'tmpdir'

class PresetStoreTest < Minitest::Test
  S = Skrine::Core::PresetStore

  def test_builtin_presets_listed_with_names
    all = S.all(user_dir: Dir.mktmpdir)
    names = all.map { |p| p[:name] }
    assert_includes names, 'Satnik 2 stlpce'
    assert all.all? { |p| p[:params].is_a?(Hash) }
    refute all.first[:params].key?('_name')
  end

  def test_save_named_writes_slug_file_and_lists_it
    Dir.mktmpdir do |dir|
      path = S.save_named({ 'width' => 1500 }, 'Moja skriňa – detská', user_dir: dir)
      assert_equal File.join(dir, 'moja-skrina-detska.json'), path
      entry = S.all(user_dir: dir).find { |p| p[:file] == path }
      assert_equal 'Moja skriňa – detská', entry[:name]
      assert_equal 1500, entry[:params]['width']
      assert_equal 1500, S.read(path)['width']
    end
  end
end
```

- [ ] **Step 2: Spusti – zlyhá.**

- [ ] **Step 3: Implementácia**

`src/skrine/data/column_modules.rb`:
```ruby
require_relative '../wardrobe/params'

module Skrine
  module Data
    # Ready-made interior layouts for one column (top → bottom cells).
    module ColumnModules
      MODULES = [
        { key: :hanging_drawers, label: 'Vešanie + 3 zásuvky',
          cells: [{ content: :rod }, { content: :drawers, height_mode: :mm, height: 600, drawers_count: 3 }] },
        { key: :hanging_only, label: 'Dlhé vešanie', cells: [{ content: :rod }] },
        { key: :double_hanging, label: '2× krátke vešanie', cells: [{ content: :rod }, { content: :rod }] },
        { key: :shelves_5, label: '5 políc', cells: [{ content: :shelves, shelves_count: 5 }] },
        { key: :shelves_drawers, label: 'Police + 3 zásuvky',
          cells: [{ content: :shelves, shelves_count: 4 }, { content: :drawers, height_mode: :mm, height: 600, drawers_count: 3 }] },
        { key: :hanging_top_shelves, label: 'Vešanie hore, police dole',
          cells: [{ content: :rod, height_mode: :mm, height: 1100 }, { content: :shelves, shelves_count: 3 }] },
        { key: :drawers_only, label: 'Police + 4 zásuvky',
          cells: [{ content: :shelves, shelves_count: 2 }, { content: :drawers, height_mode: :mm, height: 900, drawers_count: 4 }] },
        { key: :hanging_inner_drawers, label: 'Vešanie + vnorené zásuvky',
          cells: [{ content: :rod }, { content: :inner_drawers, height_mode: :mm, height: 500, drawers_count: 2 }] },
        { key: :empty, label: 'Prázdny', cells: [{ content: :empty }] }
      ].freeze

      def self.find(key)
        MODULES.find { |m| m[:key] == key.to_s.to_sym } || raise(ArgumentError, "neznámy modul: #{key}")
      end

      # Returns a deep copy of +params+ with column +index+ (0-based) filled by the module.
      def self.apply(params, index, key)
        mod = find(key)
        copy = Marshal.load(Marshal.dump(params))
        column = copy[:columns][index] || raise(ArgumentError, "stĺpec #{index + 1} neexistuje")
        column[:cells] = mod[:cells].map { |c| Wardrobe::Params::CELL.merge_defaults(c) }
        copy
      end

      def self.to_h
        MODULES.map { |m| { key: m[:key], label: m[:label], cells: m[:cells] } }
      end
    end
  end
end
```

`src/skrine/core/preset_store.rb`:
```ruby
require 'json'
require 'fileutils'

module Skrine
  module Core
    # Preset files: built-in (repo presets/) and user-saved (per-user directory).
    module PresetStore
      NAME_KEY = '_name'.freeze

      def self.builtin_dir
        [File.expand_path('../../../presets', __dir__), File.expand_path('../presets', __dir__)].find { |d| Dir.exist?(d) }
      end

      def self.user_dir
        if RUBY_PLATFORM.include?('darwin')
          File.join(Dir.home, 'Library', 'Application Support', 'Skrine', 'presets')
        else
          File.join(Dir.home, '.skrine', 'presets')
        end
      end

      # [{file:, name:, params:}] – built-in first, then user presets; unreadable files are skipped.
      def self.all(user_dir: self.user_dir)
        dirs = [builtin_dir, user_dir].compact.select { |d| Dir.exist?(d) }
        dirs.flat_map do |dir|
          Dir[File.join(dir, '*.json')].sort.map do |file|
            raw = JSON.parse(File.read(file))
            name = raw[NAME_KEY] || humanize(File.basename(file, '.json'))
            { file: file, name: name, params: raw.reject { |k, _| k == NAME_KEY } }
          rescue JSON::ParserError
            nil
          end
        end.compact
      end

      def self.read(file)
        JSON.parse(File.read(file)).reject { |k, _| k == NAME_KEY }
      end

      def self.save_named(params, name, user_dir: self.user_dir)
        FileUtils.mkdir_p(user_dir)
        path = File.join(user_dir, "#{slug(name)}.json")
        data = { NAME_KEY => name }.merge(stringify(params))
        File.write(path, JSON.pretty_generate(data))
        path
      end

      def self.humanize(basename)
        basename.tr('-_', '  ').strip.capitalize
      end

      def self.slug(name)
        ascii = name.unicode_normalize(:nfkd).encode('ASCII', replace: '').downcase
        ascii.gsub(/[^a-z0-9]+/, '-').gsub(/\A-|-\z/, '')
      end

      def self.stringify(obj)
        case obj
        when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify(v) }
        when Array then obj.map { |v| stringify(v) }
        when Symbol then obj.to_s
        else obj
        end
      end
    end
  end
end
```
Pozn.: `unicode_normalize` je v stdlib (`require 'unicode_normalize/normalize'` netreba od Ruby 2.2 – metóda String#unicode_normalize je vstavaná).

`core.rb` pridaj: `require_relative 'core/preset_store'` a `require_relative 'data/column_modules'` (po `wardrobe/params`).

`src/skrine/sketchup/presets.rb`: `DIR = Core::PresetStore.builtin_dir`; `save`/`load` nezmenené (savepanel defaultne do `Core::PresetStore.user_dir`, vytvor ho `FileUtils.mkdir_p` pred `savepanel`).

`commands.rb`:
```ruby
def new_from_preset
  path = UI.openpanel('Načítať preset', Core::PresetStore.user_dir, 'JSON|*.json||')
  new_from_preset_file(path) if path
end

def new_from_preset_file(file)
  params = Core::PresetStore.read(file)
  model = Sketchup.active_model
  res = Builder.create(model, :wardrobe, Core::Registry.fetch(:wardrobe).schema.merge_defaults(params))
  if res[:errors].any?
    UI.messagebox("Skriňa sa nevytvorila:\n#{res[:errors].join("\n")}")
  else
    open_editor(res[:group])
  end
rescue JSON::ParserError, Errno::ENOENT => e
  UI.messagebox("Preset sa nedá načítať: #{e.message}")
end
```

- [ ] **Step 4: Testy** – PASS; `ruby -wc` na presets.rb, commands.rb.
- [ ] **Step 5: Commit** `feat: column module library and preset store`

---

### Task 4: `UI::PreviewService`, callbacky dialógu, dev server

**Files:**
- Create: `src/skrine/ui/preview_service.rb`, `scripts/ui_server.rb`
- Modify: `src/skrine/core.rb`, `src/skrine/ui/dialog.rb`
- Test: `test/ui/preview_service_test.rb`, `test/sketchup/load_test.rb` (require preview_service; dialog stále načíta)

**Interfaces:**
- `Skrine::UI::PreviewService.preview(type, values) -> { scene:, info:, errors:, warnings:, state: }` (`scene` nil pri chybách), `.init_payload(type, params, result = {}) -> { type, label, schema, state, result, modules, preview }`, `.gallery(type, presets = PresetStore.all) -> [{ file:, name:, scene: }]`.
- Dialóg → JS: `Skrine.init(payload)`, `Skrine.setPreview(previewHash)`, `Skrine.setResult(result)`, `Skrine.showGallery(list)`. JS → Ruby callbacky: `ready`, `preview(json)`, `apply(json)`, `gallery()`, `use_preset(file, mode)` (`mode` = `'apply' | 'new'`), `save_named_preset(json, name)`, `save_preset(json)`, `load_preset()`, `cutlist()`, `new_object()`, `log(msg)`.
- Dev server: `/opt/homebrew/opt/ruby/bin/ruby scripts/ui_server.rb` → `http://localhost:8792/` (stub `window.sketchup` volá HTTP).

- [ ] **Step 1: Failing test**

`test/ui/preview_service_test.rb`:
```ruby
require 'test_helper'

class PreviewServiceTest < Minitest::Test
  TYPE = Skrine::Core::Registry.fetch(:wardrobe)
  PS = Skrine::UI::PreviewService

  def test_preview_returns_scene_for_valid_params
    pv = PS.preview(TYPE, { 'width' => 2000 })
    assert_equal [], pv[:errors]
    assert pv[:scene][:boxes].size > 20
    assert_in_delta 1964, pv[:info][:inner_w]
    assert_equal 2000.0, pv[:state][:width]
  end

  def test_preview_reports_errors_without_scene
    pv = PS.preview(TYPE, { 'width' => 10 })
    assert_nil pv[:scene]
    assert_includes pv[:errors], 'width: min 200'
  end

  def test_init_payload_has_everything_the_page_needs
    p = PS.init_payload(TYPE, TYPE.schema.defaults)
    assert_equal %i[type label schema state result modules preview], p.keys
    assert_equal :wardrobe, p[:type]
    assert p[:modules].size >= 5
    assert p[:preview][:scene]
  end

  def test_gallery_lists_builtin_presets_with_scenes
    g = PS.gallery(TYPE)
    assert_operator g.size, :>=, 3
    assert g.all? { |e| e[:scene] && e[:name] && e[:file] }
  end
end
```

- [ ] **Step 2: Spusti – zlyhá.**

- [ ] **Step 3: Implementácia**

`src/skrine/ui/preview_service.rb` (čistý Ruby):
```ruby
require_relative '../export/scene'
require_relative '../data/column_modules'
require_relative '../core/preset_store'

module Skrine
  module UI
    # Builds what the editor page needs (scene, info, messages). Used by the
    # SketchUp dialog and by scripts/ui_server.rb, so it must stay SketchUp-free.
    module PreviewService
      module_function

      def preview(type, values)
        params = type.schema.merge_defaults(values)
        layout = type.model_class.new(params).layout
        {
          scene: layout.valid? ? Export::Scene.build(layout, params) : nil,
          info: layout.info, errors: layout.errors, warnings: layout.warnings, state: params
        }
      end

      def init_payload(type, params, result = {})
        {
          type: type.key, label: type.label, schema: type.schema.to_h, state: params, result: result,
          modules: Data::ColumnModules.to_h, preview: preview(type, params)
        }
      end

      def gallery(type, presets = Core::PresetStore.all)
        presets.map do |p|
          pv = preview(type, p[:params])
          next nil unless pv[:scene]

          { file: p[:file], name: p[:name], scene: pv[:scene] }
        end.compact
      end
    end
  end
end
```
`core.rb`: `require_relative 'ui/preview_service'` (na koniec).

`src/skrine/ui/dialog.rb` – zmeny:
```ruby
require_relative 'preview_service'
# ...
def build_dialog
  d = UI::HtmlDialog.new(dialog_title: 'Skrine', preferences_key: 'sk.skrine.editor', width: 1320, height: 880,
                         resizable: true, style: UI::HtmlDialog::STYLE_DIALOG)
  d.set_file(HTML)
  d.add_action_callback('ready') { push_state }
  d.add_action_callback('log') { |_, msg| puts "[Skrine] #{msg}" }
  d.add_action_callback('preview') { |_, json| send_js('Skrine.setPreview', PreviewService.preview(@type, JSON.parse(json))) }
  d.add_action_callback('apply') { |_, json| apply(JSON.parse(json)) }
  d.add_action_callback('gallery') { send_js('Skrine.showGallery', PreviewService.gallery(@type)) }
  d.add_action_callback('use_preset') { |_, file, mode| use_preset(file, mode) }
  d.add_action_callback('save_named_preset') do |_, json, name|
    path = Core::PresetStore.save_named(JSON.parse(json), name)
    UI.messagebox("Preset uložený do galérie:\n#{path}")
  end
  d.add_action_callback('save_preset') { |_, json| Presets.save(json) }
  d.add_action_callback('load_preset') { load_preset }
  d.add_action_callback('cutlist') { run_cutlist }
  d.add_action_callback('new_object') { Commands.new_object(@type ? @type.key : :wardrobe) }
  d
end

def send_js(function, obj)
  dialog.execute_script("#{function}(#{self.class.js_json(obj)})")
end

def push_state
  return unless @params

  send_js('Skrine.init', PreviewService.init_payload(@type, @params, @last || {}))
end

def use_preset(file, mode)
  if mode == 'new'
    Commands.new_from_preset_file(file)
  else
    apply(Core::PresetStore.read(file))
    push_state
  end
rescue JSON::ParserError, Errno::ENOENT => e
  UI.messagebox("Preset sa nedá načítať: #{e.message}")
end
```
`apply` a `load_preset`, `run_cutlist`, `open_for` (s `UI.start_timer`) zostávajú.

`scripts/ui_server.rb`:
```ruby
# Dev server for the editor page: serves src/skrine/ui/html with a stub
# `window.sketchup` that talks HTTP to this process. No SketchUp needed.
#   /opt/homebrew/opt/ruby/bin/ruby scripts/ui_server.rb   → http://localhost:8792/
require 'socket'
require 'json'
require 'uri'
$LOAD_PATH.unshift File.expand_path('../src', __dir__)
require 'skrine/core'

PORT = (ARGV[0] || 8792).to_i
HTML_DIR = File.expand_path('../src/skrine/ui/html', __dir__)
TYPE = Skrine::Core::Registry.fetch(:wardrobe)
TYPES = { '.html' => 'text/html; charset=utf-8', '.js' => 'text/javascript; charset=utf-8', '.css' => 'text/css; charset=utf-8',
          '.json' => 'application/json; charset=utf-8', '.svg' => 'image/svg+xml' }.freeze

STUB = <<~JS
  <script>
  window.sketchup = {
    _call(path, body, then_) { fetch(path, body ? { method: 'POST', body } : {}).then(r => r.json()).then(then_); },
    ready() { this._call('/state', null, p => Skrine.init(p)); },
    preview(json) { this._call('/preview', json, r => Skrine.setPreview(r)); },
    apply(json) { this._call('/preview', json, r => Skrine.setResult({ errors: r.errors, warnings: r.warnings, info: r.info })); },
    gallery() { this._call('/gallery', null, g => Skrine.showGallery(g)); },
    use_preset(file, mode) { this._call('/preset?file=' + encodeURIComponent(file), null, p => Skrine.loadParams(p)); },
    save_named_preset(json, name) { console.log('save_named_preset', name); alert('Uložené (stub): ' + name); },
    save_preset() { alert('save_preset (stub)'); }, load_preset() { alert('load_preset (stub)'); },
    cutlist() { alert('cutlist (stub)'); }, new_object() { alert('new_object (stub)'); }, log(m) { console.log(m); }
  };
  </script>
JS

def respond(sock, status, type, body)
  sock.write("HTTP/1.1 #{status}\r\nContent-Type: #{type}\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n")
  sock.write(body)
end

def json(sock, obj)
  respond(sock, 200, TYPES['.json'], JSON.generate(obj))
end

def handle(sock)
  request = sock.gets or return
  method, target, = request.split(' ')
  headers = {}
  while (line = sock.gets) && line != "\r\n"
    k, v = line.split(':', 2)
    headers[k.downcase] = v.strip
  end
  body = headers['content-length'] ? sock.read(headers['content-length'].to_i) : ''
  uri = URI.parse(target)
  case [method, uri.path]
  when ['GET', '/'], ['GET', '/index.html']
    html = File.read(File.join(HTML_DIR, 'index.html')).sub('<script src="app.js">', "#{STUB}<script src=\"app.js\">")
    respond(sock, 200, TYPES['.html'], html)
  when ['GET', '/state']
    json(sock, Skrine::UI::PreviewService.init_payload(TYPE, TYPE.schema.defaults))
  when ['POST', '/preview']
    json(sock, Skrine::UI::PreviewService.preview(TYPE, JSON.parse(body)))
  when ['GET', '/gallery']
    json(sock, Skrine::UI::PreviewService.gallery(TYPE))
  when ['GET', '/preset']
    file = URI.decode_www_form(uri.query.to_s).to_h['file']
    json(sock, TYPE.schema.merge_defaults(Skrine::Core::PresetStore.read(file)))
  else
    path = File.join(HTML_DIR, File.basename(uri.path))
    if File.file?(path)
      respond(sock, 200, TYPES[File.extname(path)] || 'application/octet-stream', File.binread(path))
    else
      respond(sock, 404, 'text/plain', 'not found')
    end
  end
rescue StandardError => e
  respond(sock, 500, 'text/plain', "#{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
ensure
  sock.close
end

server = TCPServer.new('127.0.0.1', PORT)
puts "Skrine UI dev server: http://localhost:#{PORT}/"
loop { Thread.new(server.accept) { |s| handle(s) } }
```

`test/sketchup/load_test.rb`: pridaj `require 'skrine/ui/preview_service'` (už ide cez core) a assert `defined?(Skrine::UI::PreviewService)`.

- [ ] **Step 4: Testy** – PASS; `ruby -wc src/skrine/ui/dialog.rb scripts/ui_server.rb`; spusti server a `curl -s localhost:8792/state | head -c 200` vráti JSON.
- [ ] **Step 5: Commit** `feat(ui): preview service, dialog callbacks for the visual editor, dev server`

---

### Task 5: Piktogramy a obrázkové karty (`icons.js`, `cards.js`)

**Files:**
- Create: `src/skrine/ui/html/icons.js`, `src/skrine/ui/html/cards.js`
- Test: `node --check`; vizuálne v Task 7/8 (katalóg ikon: `scripts/ui_server.rb` → `http://localhost:8792/icons.html` – vytvor `src/skrine/ui/html/icons.html`, ktorá vypíše všetky ikony s kľúčmi)

**Interfaces:**
- `ICONS[key] -> svg string` (viewBox 0 0 48 48), kľúče: `placement.between_walls|corner_left|corner_right|free`, `base.legs|plinth|floor`, `back.groove|overlay|inset`, `doors.none|single_left|single_right|double|flap_up`, `mount.overlay|half_overlay|inset`, `handle.none|drilled|profile`, `content.shelves|rod|drawers|inner_drawers|empty`, `system.front_only|wood_box|blum_legrabox|blum_tandembox|blum_merivobox`, `corner.inset|overlay`, `joinery.none|dowels|confirmat|cam_lock`, `mode.auto|mm|ratio`, `view.front|front_open|side|plan`.
- `Cards.radio(container, { options: [{value,label}], value, icons, onChange, small })` – vykreslí `.cards` s `.card[.active]`; `Cards.moduleSvg(mod) -> svg string` (mini nákres stĺpca z definície modulu).

- [ ] **Step 1: icons.js**

```javascript
/* Pictograms for option cards. Style: white faces, dark outline, orange accent. */
/* exported ICONS */
const ICONS = (() => {
  const S = '#333';
  const A = '#f28c28';
  const svg = (body) => `<svg viewBox="0 0 48 48" width="48" height="48" fill="none" stroke="${S}" stroke-width="1.6" stroke-linejoin="round">${body}</svg>`;
  const cab = (x = 10, y = 8, w = 28, h = 32) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="#fff"/>`;
  const wall = (x) => `<line x1="${x}" y1="4" x2="${x}" y2="44" stroke-width="3"/>`;
  const shelves = (x = 10, w = 28, ys = [18, 26, 34]) => ys.map((y) => `<line x1="${x}" y1="${y}" x2="${x + w}" y2="${y}"/>`).join('');
  const drawers = (x = 11, y = 22, w = 26, n = 3, h = 6) =>
    Array.from({ length: n }, (_, i) => `<rect x="${x}" y="${y + i * h}" width="${w}" height="${h - 1}" fill="#fff"/><line x1="${x + w / 2 - 4}" y1="${y + i * h + 2.5}" x2="${x + w / 2 + 4}" y2="${y + i * h + 2.5}" stroke="${A}" stroke-width="2"/>`).join('');
  const rod = (x = 12, w = 24, y = 16) => `<line x1="${x}" y1="${y}" x2="${x + w}" y2="${y}" stroke="${A}" stroke-width="2.5"/>` +
    [0, 8, 16].map((d) => `<path d="M${x + 4 + d} ${y} v3 l-3 5 h6 z" fill="#fff"/>`).join('');
  const dots = (x, ys) => ys.map((y) => `<circle cx="${x}" cy="${y}" r="1.6" fill="${A}" stroke="none"/>`).join('');
  const planSides = () => `<rect x="8" y="14" width="4" height="26" fill="#fff"/><rect x="36" y="14" width="4" height="26" fill="#fff"/>`;

  return {
    'placement.between_walls': svg(wall(6) + wall(42) + cab(10, 8, 28, 34)),
    'placement.corner_left': svg(wall(6) + cab(10, 8, 28, 34)),
    'placement.corner_right': svg(wall(42) + cab(10, 8, 28, 34)),
    'placement.free': svg(cab(10, 8, 28, 34)),

    'base.legs': svg(cab(10, 6, 28, 30) + `<rect x="13" y="36" width="3" height="6" fill="${A}" stroke="none"/><rect x="32" y="36" width="3" height="6" fill="${A}" stroke="none"/><line x1="6" y1="43" x2="42" y2="43"/>`),
    'base.plinth': svg(cab(10, 6, 28, 30) + `<rect x="13" y="36" width="22" height="6" fill="${A}" stroke="none"/><line x1="6" y1="43" x2="42" y2="43"/>`),
    'base.floor': svg(cab(10, 10, 28, 33) + '<line x1="6" y1="43" x2="42" y2="43"/>'),

    'back.groove': svg(planSides() + `<rect x="12" y="34" width="24" height="2" fill="${A}" stroke="none"/><line x1="8" y1="14" x2="40" y2="14" stroke-dasharray="2 2"/>`),
    'back.overlay': svg(planSides() + `<rect x="8" y="40" width="32" height="2" fill="${A}" stroke="none"/>`),
    'back.inset': svg(planSides() + `<rect x="12" y="34" width="24" height="5" fill="${A}" stroke="none"/>`),

    'doors.none': svg(cab() + shelves()),
    'doors.single_left': svg(cab() + `<rect x="12" y="10" width="24" height="28" fill="${A}" fill-opacity=".35"/>` + dots(14, [16, 32])),
    'doors.single_right': svg(cab() + `<rect x="12" y="10" width="24" height="28" fill="${A}" fill-opacity=".35"/>` + dots(34, [16, 32])),
    'doors.double': svg(cab() + `<rect x="12" y="10" width="11" height="28" fill="${A}" fill-opacity=".35"/><rect x="25" y="10" width="11" height="28" fill="${A}" fill-opacity=".35"/>` + dots(14, [16, 32]) + dots(34, [16, 32])),
    'doors.flap_up': svg(cab(10, 14, 28, 22) + `<path d="M12 16 L36 16 L36 6 L12 10 Z" fill="${A}" fill-opacity=".35"/><path d="M24 30 v-8 m-3 3 l3 -3 l3 3" stroke="${A}" stroke-width="2"/>`),

    'mount.overlay': svg(planSides() + `<rect x="8" y="10" width="32" height="4" fill="${A}" stroke="none"/>`),
    'mount.half_overlay': svg(planSides() + `<rect x="10" y="10" width="28" height="4" fill="${A}" stroke="none"/>`),
    'mount.inset': svg(planSides() + `<rect x="12" y="15" width="24" height="4" fill="${A}" stroke="none"/>`),

    'handle.none': svg(cab(12, 8, 24, 32)),
    'handle.drilled': svg(cab(12, 8, 24, 32) + `<line x1="18" y1="14" x2="30" y2="14" stroke="${A}" stroke-width="2.5"/>` + dots(18, [14]) + dots(30, [14])),
    'handle.profile': svg(cab(12, 12, 24, 28) + `<rect x="12" y="8" width="24" height="4" fill="${A}" stroke="none"/>`),

    'content.shelves': svg(cab() + shelves()),
    'content.rod': svg(cab() + rod()),
    'content.drawers': svg(cab() + drawers(11, 12, 26, 4, 7)),
    'content.inner_drawers': svg(cab() + `<rect x="12" y="10" width="24" height="28" stroke-dasharray="3 2"/>` + drawers(14, 20, 20, 2, 7)),
    'content.empty': svg(cab()),

    'system.front_only': svg(`<rect x="8" y="10" width="4" height="28" fill="${A}" stroke="none"/><line x1="12" y1="24" x2="40" y2="24" stroke-dasharray="3 2"/>`),
    'system.wood_box': svg(`<rect x="8" y="10" width="4" height="28" fill="${A}" stroke="none"/><rect x="12" y="16" width="26" height="16" fill="#e8dcc0"/>`),
    'system.blum_legrabox': svg(`<rect x="8" y="10" width="4" height="28" fill="${A}" stroke="none"/><rect x="12" y="14" width="26" height="18" fill="#dcdcdc"/><text x="25" y="27" font-size="7" text-anchor="middle" fill="${S}" stroke="none" font-family="sans-serif">LEGRA</text>`),
    'system.blum_tandembox': svg(`<rect x="8" y="10" width="4" height="28" fill="${A}" stroke="none"/><rect x="12" y="14" width="26" height="18" fill="#dcdcdc"/><text x="25" y="27" font-size="6" text-anchor="middle" fill="${S}" stroke="none" font-family="sans-serif">TANDEM</text>`),
    'system.blum_merivobox': svg(`<rect x="8" y="10" width="4" height="28" fill="${A}" stroke="none"/><rect x="12" y="14" width="26" height="18" fill="#dcdcdc"/><text x="25" y="27" font-size="6" text-anchor="middle" fill="${S}" stroke="none" font-family="sans-serif">MERIVO</text>`),

    'corner.inset': svg(`<rect x="10" y="8" width="6" height="32" fill="#fff"/><rect x="16" y="8" width="22" height="6" fill="${A}" fill-opacity=".5"/>`),
    'corner.overlay': svg(`<rect x="10" y="14" width="6" height="26" fill="#fff"/><rect x="10" y="8" width="28" height="6" fill="${A}" fill-opacity=".5"/>`),

    'joinery.none': svg(cab(10, 12, 28, 24)),
    'joinery.dowels': svg(cab(10, 12, 28, 24) + dots(24, [16, 32])),
    'joinery.confirmat': svg(cab(10, 12, 28, 24) + `<line x1="24" y1="14" x2="24" y2="34" stroke="${A}" stroke-width="2.5"/>`),
    'joinery.cam_lock': svg(cab(10, 12, 28, 24) + `<circle cx="24" cy="24" r="4" stroke="${A}" stroke-width="2"/>`),

    'mode.auto': svg(`<text x="24" y="30" font-size="14" text-anchor="middle" fill="${S}" stroke="none" font-family="sans-serif">auto</text>`),
    'mode.mm': svg(`<text x="24" y="30" font-size="14" text-anchor="middle" fill="${S}" stroke="none" font-family="sans-serif">mm</text>`),
    'mode.ratio': svg(`<text x="24" y="30" font-size="14" text-anchor="middle" fill="${S}" stroke="none" font-family="sans-serif">1 : n</text>`),

    'view.front': svg(cab() + `<rect x="12" y="10" width="11" height="28" fill="${A}" fill-opacity=".35"/><rect x="25" y="10" width="11" height="28" fill="${A}" fill-opacity=".35"/>`),
    'view.front_open': svg(cab() + shelves()),
    'view.side': svg(`<rect x="16" y="8" width="16" height="32" fill="#fff"/><rect x="14" y="8" width="2" height="32" fill="${A}" stroke="none"/>`),
    'view.plan': svg(`<rect x="8" y="14" width="32" height="20" fill="#fff"/><rect x="8" y="12" width="32" height="2" fill="${A}" stroke="none"/>`)
  };
})();
```

- [ ] **Step 2: cards.js**

```javascript
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
```

- [ ] **Step 3: icons.html** (katalóg na vizuálnu kontrolu)

```html
<!DOCTYPE html><html lang="sk"><head><meta charset="utf-8"><title>Ikony</title>
<style>body{font-family:sans-serif;display:flex;flex-wrap:wrap;gap:10px;padding:10px}div{width:110px;text-align:center;font-size:10px;border:1px solid #ddd;padding:6px}</style></head>
<body><script src="icons.js"></script><script>
Object.keys(ICONS).forEach((k) => { const d = document.createElement('div'); d.innerHTML = ICONS[k] + '<br>' + k; document.body.appendChild(d); });
</script></body></html>
```

- [ ] **Step 4: Over** – `node --check` oba súbory; spusti `scripts/ui_server.rb`, otvor `http://localhost:8792/icons.html`, všetky ikony sa vykreslia (screenshot do reportu).
- [ ] **Step 5: Commit** `feat(ui): pictogram set and option cards`

---

### Task 6: `drawing.js` – SVG nákres, projekcie, hover/klik, kóty

**Files:**
- Create: `src/skrine/ui/html/drawing.js`, `src/skrine/ui/html/drawing.html` (harness: načíta `/state`, vykreslí 4 pohľady, loguje kliknutia)

**Interfaces:**
- `Drawing.render(host, scene, opts)` – `opts = { view: 'front'|'front_open'|'side'|'plan', selection, hover, interactive: true, onSelect(target), onHover(target|null), onEditDim(dim, screenPos) }`; `target = { kind: 'column'|'cell'|'base'|'construction'|'global', column, cell, boxId }`. Vráti nič; `host.innerHTML` = SVG.
- `Drawing.targetFor(box) -> target` (mapovanie druh → výber podľa specu §3.2), `Drawing.isSelected(box, selection)`.

- [ ] **Step 1: drawing.js**

```javascript
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
```

- [ ] **Step 2: drawing.html** (harness)

```html
<!DOCTYPE html><html lang="sk"><head><meta charset="utf-8"><title>Drawing</title><link rel="stylesheet" href="style.css">
<style>.host{width:820px;height:620px;border:1px solid #ccc;display:inline-block;margin:6px;position:relative}#log{font:12px monospace;white-space:pre}</style></head>
<body><div id="views"></div><div id="log"></div>
<script src="drawing.js"></script><script>
fetch('/state').then(r => r.json()).then(p => {
  const scene = p.preview.scene; const log = document.getElementById('log');
  ['front', 'front_open', 'side', 'plan'].forEach((view) => {
    const host = document.createElement('div'); host.className = 'host'; document.getElementById('views').appendChild(host);
    Drawing.render(host, scene, { view, selection: { kind: 'column', column: 1 },
      onSelect: (t) => { log.textContent = JSON.stringify(t) + '\n' + log.textContent; },
      onHover: (b) => { if (b) log.textContent = 'hover ' + b.name + '\n' + log.textContent.split('\n').slice(0, 8).join('\n'); },
      onEditDim: (d) => { log.textContent = 'edit ' + d.id + ' ' + d.edit + '\n' + log.textContent; } });
  });
});
</script></body></html>
```

Štýly (do `style.css`, Task 7 ich rozšíri): `.drawing rect.box{stroke:#333;stroke-width:.6}.drawing rect.box.hover{stroke:#f28c28;stroke-width:2}.drawing rect.box.selected{fill:#f28c28 !important;fill-opacity:.35;stroke:#f28c28;stroke-width:1.5}.drawing rect.cell{fill:transparent;stroke:none}.drawing rect.cell.selected{fill:#f28c28;fill-opacity:.12}.drawing .dim line{stroke:#555;stroke-width:1}.drawing .dim text{font:11px sans-serif;fill:#333}.drawing .dim.editable text{fill:#1a56c4;cursor:pointer;text-decoration:underline}`

- [ ] **Step 3: Over** – `node --check drawing.js`; dev server → `http://localhost:8792/drawing.html`: 4 pohľady, stĺpec 1 zvýraznený (dvere + priečka oranžové), hover mení obrys, klik loguje správne ciele (dvere → column, polica → cell, sokel → base, bok → construction), klik na kótu loguje `edit …`. Screenshot do reportu.
- [ ] **Step 4: Commit** `feat(ui): SVG scene drawing with projections, selection and dimensions`

---

### Task 7: Stránka editora – `index.html`, `style.css`, `form.js`, `gallery.js`, `app.js`

**Files:**
- Create: `src/skrine/ui/html/form.js` (presunutý schémový generátor z dnešného `app.js`, enumy ako karty), `src/skrine/ui/html/gallery.js`
- Rewrite: `src/skrine/ui/html/index.html`, `src/skrine/ui/html/style.css`, `src/skrine/ui/html/app.js`

**Interfaces:**
- Consumes: `Drawing`, `Cards`, `ICONS` (Task 5–6), payload z `PreviewService.init_payload` (`schema`, `state`, `modules`, `preview`), callbacky z Task 4.
- Produces: `Skrine.init/setPreview/setResult/showGallery/loadParams`; `Form.render(container, schema, state, groupKeys, onChange)`; `Gallery.show(list, {onApply, onNew})`, `Gallery.hide()`.

- [ ] **Step 1: index.html**

```html
<!DOCTYPE html>
<html lang="sk">
<head>
  <meta charset="utf-8">
  <title>Skrine</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <div id="app">
    <header id="toolbar">
      <h1 id="title">Skriňa</h1>
      <div class="group">
        <button id="btn-gallery" type="button">Galéria skríň</button>
        <div class="menu">
          <button id="btn-presets" type="button">Presety ▾</button>
          <div class="menu-items hidden" id="presets-menu">
            <button id="btn-save-named" type="button">Uložiť do galérie…</button>
            <button id="btn-save-file" type="button">Uložiť do súboru…</button>
            <button id="btn-load-file" type="button">Načítať zo súboru…</button>
          </div>
        </div>
        <button id="btn-new" type="button">Nová skriňa</button>
      </div>
      <div class="group dims">
        <label>Šírka <input id="dim-width" type="number" min="200" max="10000" step="1"><input id="rng-width" type="range" min="300" max="6000" step="10"></label>
        <label>Výška <input id="dim-height" type="number" min="200" max="4000" step="1"><input id="rng-height" type="range" min="300" max="3000" step="10"></label>
        <label>Hĺbka <input id="dim-depth" type="number" min="100" max="1500" step="1"><input id="rng-depth" type="range" min="200" max="900" step="10"></label>
      </div>
    </header>
    <div id="viewbar">
      <div id="view-cards"></div>
      <span class="hint">Klikni na stĺpec, pole, dvere alebo sokel v nákreze. Modré kóty sa dajú prepísať.</span>
    </div>
    <div id="drawing"></div>
    <section id="advanced">
      <button id="adv-toggle" type="button">▸ Rozšírené nastavenia (konštrukcia, čelá, zásuvky, materiály, kovanie)</button>
      <div id="adv-body" class="hidden">
        <nav id="adv-tabs"></nav>
        <div id="adv-panels"></div>
      </div>
    </section>
    <aside id="panel"><div id="panel-body"></div></aside>
    <footer id="actions">
      <div class="row">
        <button id="btn-apply" class="primary" type="button">Použiť v SketchUpe</button>
        <label class="auto"><input type="checkbox" id="chk-auto" checked> Auto</label>
        <button id="btn-cutlist" type="button">Nárezový plán</button>
      </div>
      <div id="messages"></div>
      <div id="info"></div>
    </footer>
  </div>
  <div id="gallery" class="hidden">
    <div class="gbox">
      <header><h2>Galéria skríň</h2><button id="gallery-close" type="button">✕</button></header>
      <div class="grid"></div>
    </div>
  </div>
  <script src="icons.js"></script>
  <script src="cards.js"></script>
  <script src="drawing.js"></script>
  <script src="form.js"></script>
  <script src="gallery.js"></script>
  <script src="app.js"></script>
</body>
</html>
```

- [ ] **Step 2: style.css**

```css
* { box-sizing: border-box; }
html, body { height: 100%; margin: 0; }
body { font: 13px -apple-system, "Segoe UI", Helvetica, Arial, sans-serif; color: #222; background: #f3f3f3; }
.hidden { display: none !important; }
button { font: inherit; padding: 4px 10px; border: 1px solid #bbb; border-radius: 4px; background: #fafafa; cursor: pointer; }
button:hover { background: #eee; }
button.primary { background: #2f6fdb; border-color: #2f6fdb; color: #fff; }
button.primary:hover { background: #245cb8; }
input[type=number], input[type=text], select { font: inherit; padding: 3px 5px; border: 1px solid #bbb; border-radius: 3px; width: 90px; }
input[type=range] { width: 110px; vertical-align: middle; }

#app { display: grid; height: 100vh; grid-template-columns: 1fr 380px; grid-template-rows: auto auto 1fr auto;
  grid-template-areas: "toolbar toolbar" "viewbar panel" "drawing panel" "advanced actions"; }
#toolbar { grid-area: toolbar; display: flex; align-items: center; gap: 18px; padding: 6px 12px; background: #fff; border-bottom: 1px solid #ddd; }
#toolbar h1 { font-size: 15px; margin: 0 6px 0 0; }
#toolbar .group { display: flex; align-items: center; gap: 6px; }
#toolbar .dims label { display: inline-flex; align-items: center; gap: 4px; margin-right: 8px; }
#toolbar .dims input[type=number] { width: 70px; }
.menu { position: relative; }
.menu-items { position: absolute; top: 100%; left: 0; background: #fff; border: 1px solid #bbb; border-radius: 4px; display: flex; flex-direction: column; z-index: 5; min-width: 180px; }
.menu-items button { border: none; text-align: left; border-radius: 0; }

#viewbar { grid-area: viewbar; display: flex; align-items: center; gap: 12px; padding: 4px 12px; background: #fafafa; border-bottom: 1px solid #e5e5e5; }
#viewbar .hint { color: #666; font-size: 12px; }
#drawing { grid-area: drawing; position: relative; overflow: hidden; background: #fff; min-height: 300px; }
#drawing .dim-input { position: absolute; width: 70px; font: 12px sans-serif; padding: 2px 4px; border: 1px solid #1a56c4; }

#advanced { grid-area: advanced; background: #fff; border-top: 1px solid #ddd; max-height: 45vh; display: flex; flex-direction: column; }
#adv-toggle { border: none; background: none; text-align: left; padding: 6px 12px; font-weight: 600; }
#adv-body { overflow: auto; padding: 0 12px 10px; }
#adv-tabs { display: flex; gap: 2px; margin-bottom: 6px; }
#adv-tabs button { border-radius: 4px 4px 0 0; background: #eee; }
#adv-tabs button.active { background: #fff; font-weight: 600; border-bottom-color: #fff; }

#panel { grid-area: panel; background: #fff; border-left: 1px solid #ddd; overflow: auto; }
#panel-body { padding: 10px 12px; }
#panel h2 { font-size: 15px; margin: 0 0 8px; }
#panel h3 { font-size: 12px; text-transform: uppercase; letter-spacing: .04em; color: #666; margin: 14px 0 6px; }
.row { display: grid; grid-template-columns: 1fr 100px 28px; align-items: center; gap: 6px; padding: 3px 0; }
.row em { color: #888; font-style: normal; font-size: 11px; }
.row input[type=checkbox] { justify-self: start; }
.btnrow { display: flex; gap: 6px; flex-wrap: wrap; margin: 6px 0; }
.btnrow button.danger { color: #9b1c1c; }
.cards { display: flex; flex-wrap: wrap; gap: 6px; margin: 4px 0 8px; }
.card { display: flex; flex-direction: column; align-items: center; gap: 2px; width: 84px; padding: 6px 4px; border: 2px solid #ddd; border-radius: 6px; background: #fff; }
.card .label { font-size: 11px; text-align: center; line-height: 1.15; }
.card.active { border-color: #f28c28; background: #fff7ef; }
.cards.small .card { width: 60px; padding: 3px; }
.cards.small .card .icon svg { width: 32px; height: 32px; }
.modules .card { width: 96px; }
.cell-list button { display: block; width: 100%; text-align: left; margin-bottom: 4px; }
.cell-list button.active { border-color: #f28c28; background: #fff7ef; }
fieldset { border: 1px solid #ddd; border-radius: 4px; margin: 8px 0; padding: 6px 10px; }
legend { font-weight: 600; padding: 0 4px; }
.list .item { border: 1px solid #ccc; border-radius: 4px; padding: 6px 10px; margin-bottom: 8px; }
.item-bar { display: flex; gap: 4px; align-items: center; margin-bottom: 4px; }
.item-bar strong { flex: 1; }

#actions { grid-area: actions; background: #fff; border-left: 1px solid #ddd; border-top: 1px solid #ddd; padding: 8px 12px; max-height: 45vh; overflow: auto; }
#actions .row { display: flex; gap: 8px; align-items: center; }
.msg { padding: 4px 8px; border-radius: 3px; margin: 4px 0; }
.msg.error { background: #fde8e8; color: #9b1c1c; }
.msg.warn { background: #fff4e0; color: #8a5300; }
#info { font-size: 12px; color: #444; line-height: 1.5; margin-top: 6px; }

.drawing rect.box { stroke: #333; stroke-width: .6; }
.drawing rect.box.hover { stroke: #f28c28; stroke-width: 2; }
.drawing rect.box.selected { fill: #f28c28 !important; fill-opacity: .35; stroke: #f28c28; stroke-width: 1.5; }
.drawing rect.cell { fill: transparent; stroke: none; }
.drawing rect.cell.selected { fill: #f28c28; fill-opacity: .12; }
.drawing .dim line { stroke: #555; stroke-width: 1; }
.drawing .dim text { font: 11px sans-serif; fill: #333; }
.drawing .dim.editable text { fill: #1a56c4; cursor: pointer; text-decoration: underline; }

#gallery { position: fixed; inset: 0; background: rgba(0,0,0,.45); z-index: 20; display: flex; align-items: center; justify-content: center; }
#gallery .gbox { background: #fff; border-radius: 8px; width: min(1100px, 92vw); max-height: 88vh; overflow: auto; padding: 12px 16px; }
#gallery header { display: flex; justify-content: space-between; align-items: center; }
#gallery .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(230px, 1fr)); gap: 12px; }
.gcard { border: 1px solid #ddd; border-radius: 6px; padding: 8px; }
.gcard h4 { margin: 0 0 6px; font-size: 13px; }
.gcard .thumb { width: 100%; height: 190px; background: #fafafa; }
.gcard .btnrow { justify-content: space-between; }
```

- [ ] **Step 3: form.js** (schémový generátor pre „Rozšírené“ – presun z dnešného app.js; enum → karty ak existuje skupina ikon)

```javascript
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
```

- [ ] **Step 4: gallery.js**

```javascript
/* Wardrobe gallery overlay (presets with thumbnails). */
/* global Drawing */
/* exported Gallery */
const Gallery = {
  show(list, { onApply, onNew }) {
    const overlay = document.getElementById('gallery');
    const grid = overlay.querySelector('.grid');
    grid.innerHTML = '';
    overlay.classList.remove('hidden');
    list.forEach((entry) => {
      const card = document.createElement('div'); card.className = 'gcard';
      const h = document.createElement('h4'); h.textContent = entry.name; card.appendChild(h);
      const thumb = document.createElement('div'); thumb.className = 'thumb'; card.appendChild(thumb);
      const row = document.createElement('div'); row.className = 'btnrow';
      const bApply = document.createElement('button'); bApply.type = 'button'; bApply.textContent = 'Použiť na túto skriňu';
      bApply.onclick = () => { this.hide(); onApply(entry.file); };
      const bNew = document.createElement('button'); bNew.type = 'button'; bNew.textContent = 'Vytvoriť novú';
      bNew.onclick = () => { this.hide(); onNew(entry.file); };
      row.appendChild(bApply); row.appendChild(bNew); card.appendChild(row);
      grid.appendChild(card);
      Drawing.render(thumb, entry.scene, { view: 'front', interactive: false });
    });
    if (!list.length) grid.innerHTML = '<p>Žiadne presety.</p>';
  },
  hide() { document.getElementById('gallery').classList.add('hidden'); }
};
```

- [ ] **Step 5: app.js**

```javascript
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
    Cards.radio(modes, { options: this.options(['columns', modeKey === 'width_mode' ? 'width_mode' : 'cells', ...(modeKey === 'height_mode' ? ['height_mode'] : [])].filter(Boolean)), value: obj[modeKey], icons: 'mode', small: true,
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
```

Poznámky pre implementáciu:
- `sizeRow`: cesta k `options` je pre šírku `['columns','width_mode']`, pre výšku `['columns','cells','height_mode']` – zjednoduš výraz na `this.options(modeKey === 'width_mode' ? ['columns', 'width_mode'] : ['columns', 'cells', 'height_mode'])`.
- `Form.ICON_GROUPS.type: null` je len výslovné „bez ikon“ pre kľúč `type` v Rozšírených (dvere sú v paneli).
- `window.prompt` v `UI::HtmlDialog` funguje (CEF); v dev serveri tiež.

- [ ] **Step 6: Over** – `node --check` na všetkých 6 JS; dev server → `http://localhost:8792/`: nákres so skriňou, klik na dvere → panel Stĺpec, klik na policu → panel Pole, karty modulov menia nákres, kóta stĺpca → input → zmena šírky (ostatné stĺpce auto), Galéria skríň zobrazí 3 karty s náhľadmi, Rozšírené záložky fungujú. Screenshoty: default, stĺpec, pole, galéria.
- [ ] **Step 7: Commit** `feat(ui): visual editor page – drawing-driven panels, module library, gallery, advanced form`

---

### Task 8: Vizuálna a SketchUp QA, dokumentácia

**Files:**
- Modify: `README.md`, `docs/superpowers/specs/2026-09-20-visual-editor-design.md` (sekcia Overenie)
- Delete: `scripts/preview.rb` (nahradený `drawing.html`) – alebo ponechať, ak sa používa v testoch (nie je); zmaž.

- [ ] **Step 1: Prehliadač** – prejsť scenáre zo Step 6 Task 7 + editácia kóty poľa, zmena osadenia (voľne stojaca vynuluje odsadenia), zapnutie/vypnutie dverí, otvorené dvere (otvorenie sa v nákreze neprejaví – len v modeli; napíš to do hint textu pri karte „otvorené“), Auto vypnuté → Použiť. Opraviť nájdené chyby (commit `fix(ui): …`).
- [ ] **Step 2: SketchUp** – `load '/Users/milos/Git/sketchup-skrine/scripts/reload.rb'`, označiť skriňu → Upraviť; v editore: zmena šírky kótou → Auto → model sa prekreslí; modul „5 políc“ na stĺpec 2; galéria → Vytvoriť novú. Screenshot `view.write_image` cez `scripts/verify.rb` po zmene.
- [ ] **Step 3: README** – sekcia Použitie prepísať na nový editor (nákres, panely, galéria, rozšírené, dev server `scripts/ui_server.rb`).
- [ ] **Step 4: Commit** `docs: visual editor usage and verification notes`

---

## Self-review

- Spec §2 rozloženie → T7 (index/style); §3 tok dát/scene/selection/kóty → T2, T4, T6, T7; §4 karty a piktogramy → T5, T7; §5 moduly → T3, T7; §6 galéria → T3 (PresetStore), T4 (gallery callback), T7 (gallery.js); §7 rozšírené → T7 (form.js); §8 súbory → všetky; §9 testy → T1–T4 minitest, T5–T8 vizuálne.
- Rozhrania: `Scene.build` (T2) ↔ `Drawing` kinds (T6) ↔ `targetFor`; `PreviewService.init_payload` kľúče (T4) ↔ `Skrine.init` (T7); callbacky `use_preset(file, mode)`/`save_named_preset(json, name)` (T4) ↔ `gallery.js`/`app.js` (T7); `Cards.moduleSvg` (T5) ↔ `panelColumn` (T7); `ColumnModules.to_h` cells používajú kľúče `content/height_mode/height/shelves_count/drawers_count` (T3) ↔ `moduleSvg` (T5).
- Placeholdery: žiadne TBD; poznámky k implementácii sú konkrétne.
