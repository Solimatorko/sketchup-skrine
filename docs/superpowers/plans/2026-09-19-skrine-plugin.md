# Skrine – SketchUp plugin: implementačný plán

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** SketchUp 2026 extension „Skrine“, ktorý z parametrov vygeneruje skriňu (korpus, stĺpce, polia, police, tyče, zásuvky, dvere, lišty), pregeneruje ju po každej zmene a exportuje nárezový plán + kusovník kovania.

**Architecture:** Čistá Ruby vrstva (schéma parametrov → `Layout` dielcov a kovania v mm) bez závislosti na SketchUp API, testovaná minitestom; tenká SketchUp vrstva (builder groupy s atribútmi, storage, HtmlDialog, cutlist z modelu). Typy objektov sú v registri; prvý typ je `:wardrobe`.

**Tech Stack:** Ruby 3.2 (SketchUp 2026 embedded; testy cez homebrew `/opt/homebrew/opt/ruby/bin/ruby`), minitest (stdlib), `UI::HtmlDialog` + vanilla JS/CSS, JSON.

**Spec:** `docs/superpowers/specs/2026-09-19-skrine-plugin-design.md`

## Global Constraints

- Repo: `~/Git/sketchup-skrine`. Kód a komentáre anglicky, UI texty slovensky.
- Všetky rozmery v modeli sú **mm ako Float**; na palce prevádza iba `src/skrine/sketchup/builder.rb` (`mm / 25.4`).
- Súbory v `src/skrine/core`, `data`, `wardrobe`, `export/cutlist*.rb` **nesmú** volať SketchUp API (`Sketchup`, `UI`, `Geom`).
- Testy: `cd ~/Git/sketchup-skrine && /opt/homebrew/opt/ruby/bin/ruby -Isrc -Itest test/run_all.rb` – musia prejsť pred každým commitom.
- Súradnice skrine: X šírka (zľava), Y hĺbka (predná rovina čiel Y=0, korpus do +Y), Z výška (podlaha Z=0). `width/height/depth` sú vonkajšie rozmery.
- Atribúty v SketchUpe: dictionary `Skrine` na skrini (`type`, `version`, `params` JSON), `Skrine::Part` na dielcoch, `Skrine::Hardware` na kovaní.
- Každý task končí commitom; commit správy `feat:`/`test:`/`docs:`/`chore:`.
- Odchýlka od specu: v1 má menu + kontextové menu, **bez toolbaru** (toolbar vyžaduje ikony; doplní sa neskôr).

---

### Task 1: Kostra repa, extension loader, test runner

**Files:**
- Create: `src/skrine.rb`, `src/skrine/version.rb`, `src/skrine/core.rb`, `src/skrine/loader.rb`
- Create: `test/test_helper.rb`, `test/run_all.rb`, `test/core/version_test.rb`
- Create: `scripts/install_dev.sh`, `README.md`

**Interfaces:**
- Produces: `Skrine::VERSION` (String); `require 'skrine/core'` načíta celú čistú vrstvu (ďalšie tasky doň pridávajú `require_relative`).

- [ ] **Step 1: Vytvor testovaciu infraštruktúru a failing test**

`test/test_helper.rb`:
```ruby
$LOAD_PATH.unshift File.expand_path('../src', __dir__)
require 'minitest/autorun'
require 'json'
require 'skrine/core'
```

`test/run_all.rb`:
```ruby
Dir[File.join(__dir__, '**', '*_test.rb')].sort.each { |f| require f }
```

`test/core/version_test.rb`:
```ruby
require 'test_helper'

class VersionTest < Minitest::Test
  def test_version_is_semver
    assert_match(/\A\d+\.\d+\.\d+\z/, Skrine::VERSION)
  end
end
```

- [ ] **Step 2: Spusti test – musí zlyhať**

Run: `cd ~/Git/sketchup-skrine && /opt/homebrew/opt/ruby/bin/ruby -Isrc -Itest test/run_all.rb`
Expected: `cannot load such file -- skrine/core`

- [ ] **Step 3: Vytvor zdrojové súbory**

`src/skrine/version.rb`:
```ruby
module Skrine
  VERSION = '0.1.0'
end
```

`src/skrine/core.rb` (agregátor čistej vrstvy – ďalšie tasky sem pridávajú riadky):
```ruby
# Pure-Ruby layer of the Skrine plugin. No SketchUp API is required here,
# so everything below can be loaded and tested with plain Ruby.
require_relative 'version'
```

`src/skrine.rb`:
```ruby
require 'sketchup.rb'
require 'extensions.rb'
require_relative 'skrine/version'

module Skrine
  PLUGIN_DIR = File.join(__dir__, 'skrine')

  unless file_loaded?(__FILE__)
    extension = SketchupExtension.new('Skrine', File.join(PLUGIN_DIR, 'loader.rb'))
    extension.description = 'Parametrické skrine: generovanie, úprava a nárezový plán.'
    extension.version = VERSION
    extension.creator = 'Miloš Selečéni'
    Sketchup.register_extension(extension, true)
    file_loaded(__FILE__)
  end
end
```

`src/skrine/loader.rb` (SketchUp-only časti sa pridajú v Task 11–14):
```ruby
require 'json'
require_relative 'core'

module Skrine
  # SketchUp-side modules are required here (see sketchup/ and ui/).
end
```

`scripts/install_dev.sh`:
```bash
#!/usr/bin/env bash
# Symlinks the plugin into SketchUp 2026 Plugins so edits are live after "Reload".
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)/src"
DST="$HOME/Library/Application Support/SketchUp 2026/SketchUp/Plugins"
ln -sfn "$SRC/skrine.rb" "$DST/skrine.rb"
ln -sfn "$SRC/skrine" "$DST/skrine"
echo "Linked $SRC -> $DST"
```

`README.md`:
```markdown
# Skrine – parametrické skrine pre SketchUp

Ruby extension pre SketchUp 2026. Skriňa sa generuje z parametrov (rozmery,
konštrukcia, stĺpce/polia, dvere, zásuvky, úchytky, materiály) a po každej zmene
sa pregeneruje. Z modelu sa exportuje nárezový plán a kusovník kovania.

## Vývoj
- `scripts/install_dev.sh` – symlink do SketchUp Plugins
- Testy: `/opt/homebrew/opt/ruby/bin/ruby -Isrc -Itest test/run_all.rb`
- Spec: `docs/superpowers/specs/2026-09-19-skrine-plugin-design.md`
```

- [ ] **Step 4: Spusti testy – musia prejsť**

Run: `chmod +x scripts/install_dev.sh && /opt/homebrew/opt/ruby/bin/ruby -Isrc -Itest test/run_all.rb`
Expected: `1 runs, 1 assertions, 0 failures`

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "chore: extension skeleton, pure-ruby core loader and minitest runner"
```

---

### Task 2: ParamSchema – deklaratívna schéma parametrov

**Files:**
- Create: `src/skrine/core/param_schema.rb`
- Modify: `src/skrine/core.rb` (pridaj `require_relative 'core/param_schema'`)
- Test: `test/core/param_schema_test.rb`

**Interfaces:**
- Produces: `Skrine::Core::ParamSchema.new { ... }` s DSL `group(key, label) {}`, `number(key, default, label:, min:, max:, unit:)`, `integer`, `boolean`, `enum(key, default, options:, label:)`, `string`, `object(key, schema, label:, default:)`, `list(key, schema, label:, default:)`; metódy `defaults -> Hash`, `merge_defaults(values) -> Hash` (symbol keys, enum ako Symbol, čísla Float/Integer), `validate(values) -> [String]`, `to_h -> {groups:, params:, defaults:}`.

- [ ] **Step 1: Failing test**

`test/core/param_schema_test.rb`:
```ruby
require 'test_helper'

class ParamSchemaTest < Minitest::Test
  S = Skrine::Core::ParamSchema

  INNER = S.new do
    number :thickness, 18, label: 'Hrúbka', min: 3, max: 60
    enum :corner, :inset, options: %i[inset overlay], label: 'Roh'
  end

  SCHEMA = S.new do
    group :dims, 'Rozmery' do
      number :width, 2000, label: 'Šírka', min: 200, max: 10000
      integer :count, 2, label: 'Počet', min: 1
      boolean :flag, true, label: 'Prepínač'
      string :note, '', label: 'Poznámka'
    end
    group :parts, 'Diely' do
      object :top, INNER, label: 'Strop', default: { thickness: 25 }
      list :columns, INNER, label: 'Stĺpce', default: [{ corner: :overlay }]
    end
  end

  def test_defaults_include_nested_objects_and_lists
    d = SCHEMA.defaults
    assert_equal 2000, d[:width]
    assert_equal({ thickness: 25, corner: :inset }, d[:top])
    assert_equal [{ thickness: 18, corner: :overlay }], d[:columns]
  end

  def test_merge_defaults_fills_missing_coerces_and_drops_unknown
    m = SCHEMA.merge_defaults('width' => '1500', 'count' => '3', 'flag' => 'false',
                              'top' => { 'corner' => 'overlay' }, 'columns' => [{}, { 'thickness' => 16 }],
                              'bogus' => 1)
    assert_equal 1500.0, m[:width]
    assert_equal 3, m[:count]
    assert_equal false, m[:flag]
    assert_equal({ thickness: 25, corner: :overlay }, m[:top])
    assert_equal [{ thickness: 18, corner: :inset }, { thickness: 16.0, corner: :inset }], m[:columns]
    refute m.key?(:bogus)
  end

  def test_validate_reports_range_enum_and_nested_paths
    v = SCHEMA.merge_defaults(width: 100, top: { corner: :weird }, columns: [{ thickness: 1 }])
    errors = SCHEMA.validate(v)
    assert_includes errors, 'width: min 200'
    assert_includes errors, "top.corner: neplatná hodnota 'weird'"
    assert_includes errors, 'columns[1].thickness: min 3'
  end

  def test_validate_is_empty_for_defaults
    assert_equal [], SCHEMA.validate(SCHEMA.defaults)
  end

  def test_to_h_exposes_groups_params_and_defaults
    h = SCHEMA.to_h
    assert_equal %i[dims parts], h[:groups].map { |g| g[:key] }
    width = h[:params].find { |p| p[:key] == :width }
    assert_equal :dims, width[:group]
    cols = h[:params].find { |p| p[:key] == :columns }
    assert_equal 18, cols[:item_schema][:defaults][:thickness]
    assert_equal 2000, h[:defaults][:width]
  end

  def test_duplicate_key_raises
    assert_raises(ArgumentError) { S.new { number :a, 1, label: 'a'; number :a, 2, label: 'b' } }
  end
end
```

- [ ] **Step 2: Spusti – musí zlyhať**

Run: `/opt/homebrew/opt/ruby/bin/ruby -Isrc -Itest test/core/param_schema_test.rb`
Expected: `uninitialized constant Skrine::Core`

- [ ] **Step 3: Implementácia**

`src/skrine/core/param_schema.rb`:
```ruby
module Skrine
  module Core
    # Declarative parameter schema. It is the single source of truth for
    # defaults, validation, JSON (de)serialization and the HTML form.
    class ParamSchema
      Param = Struct.new(:key, :type, :default, :label, :group, :min, :max,
                         :options, :unit, :item_schema, :help, keyword_init: true)
      Group = Struct.new(:key, :label, keyword_init: true)

      attr_reader :params, :groups

      def initialize(&block)
        @params = {}
        @groups = []
        @current_group = nil
        instance_eval(&block) if block
      end

      def group(key, label)
        @groups << Group.new(key: key, label: label)
        @current_group = key
        yield
        @current_group = nil
      end

      def number(key, default, label:, min: nil, max: nil, unit: 'mm', help: nil)
        add(key, :number, default, label, min: min, max: max, unit: unit, help: help)
      end

      def integer(key, default, label:, min: nil, max: nil, help: nil)
        add(key, :integer, default, label, min: min, max: max, help: help)
      end

      def boolean(key, default, label:, help: nil)
        add(key, :boolean, default, label, help: help)
      end

      def enum(key, default, options:, label:, help: nil)
        add(key, :enum, default, label, options: options.map(&:to_sym), help: help)
      end

      def string(key, default, label:, help: nil)
        add(key, :string, default, label, help: help)
      end

      # Nested hash with its own schema. +default+ overrides the nested defaults.
      def object(key, schema, label:, default: nil, help: nil)
        add(key, :object, default, label, item_schema: schema, help: help)
      end

      # Array of hashes sharing +schema+.
      def list(key, schema, label:, default: [], help: nil)
        add(key, :list, default, label, item_schema: schema, help: help)
      end

      def defaults
        merge_defaults({})
      end

      # Fills missing keys with defaults, coerces scalar types, drops unknown keys.
      def merge_defaults(values)
        values = symbolize(values || {})
        @params.values.each_with_object({}) do |p, h|
          v = values[p.key]
          h[p.key] = case p.type
                     when :object
                       p.item_schema.merge_defaults(symbolize(p.default || {}).merge(symbolize(v || {})))
                     when :list
                       items = v.is_a?(Array) ? v : deep_dup(p.default)
                       items.map { |item| p.item_schema.merge_defaults(item) }
                     else
                       v.nil? ? deep_dup(p.default) : coerce(p, v)
                     end
        end
      end

      # Returns error strings ("path: problem"); empty when valid.
      def validate(values, path = '')
        errors = []
        @params.values.each do |p|
          v = values[p.key]
          name = "#{path}#{p.key}"
          case p.type
          when :number, :integer
            unless v.is_a?(Numeric)
              errors << "#{name}: musí byť číslo"
              next
            end
            errors << "#{name}: min #{p.min}" if p.min && v < p.min
            errors << "#{name}: max #{p.max}" if p.max && v > p.max
          when :enum
            errors << "#{name}: neplatná hodnota '#{v}'" unless p.options.include?(v.to_s.to_sym)
          when :boolean
            errors << "#{name}: musí byť áno/nie" unless [true, false].include?(v)
          when :object
            errors.concat(p.item_schema.validate(v || {}, "#{name}."))
          when :list
            if v.is_a?(Array)
              v.each_with_index { |item, i| errors.concat(p.item_schema.validate(item, "#{name}[#{i + 1}].")) }
            else
              errors << "#{name}: musí byť zoznam"
            end
          end
        end
        errors
      end

      def to_h
        {
          groups: @groups.map(&:to_h),
          params: @params.values.map { |p| param_to_h(p) },
          defaults: defaults
        }
      end

      private

      def add(key, type, default, label, **opts)
        raise ArgumentError, "duplicate param #{key}" if @params.key?(key)

        @params[key] = Param.new(key: key, type: type, default: default, label: label,
                                 group: @current_group, **opts)
        nil
      end

      def param_to_h(p)
        h = p.to_h.reject { |_, v| v.nil? }
        h[:item_schema] = p.item_schema.to_h if p.item_schema
        h
      end

      def coerce(p, v)
        case p.type
        when :number
          v.is_a?(Numeric) ? v.to_f : (Float(v.to_s, exception: false) || v)
        when :integer
          v.is_a?(Numeric) ? v.to_i : (Integer(v.to_s, exception: false) || v)
        when :enum then v.to_s.to_sym
        when :boolean then v == true || v.to_s == 'true'
        when :string then v.to_s
        else v
        end
      end

      def symbolize(h)
        return {} unless h.is_a?(Hash)

        h.each_with_object({}) { |(k, v), o| o[k.to_sym] = v }
      end

      def deep_dup(o)
        Marshal.load(Marshal.dump(o))
      end
    end
  end
end
```

Do `src/skrine/core.rb` pridaj: `require_relative 'core/param_schema'`

- [ ] **Step 4: Spusti testy**

Run: `/opt/homebrew/opt/ruby/bin/ruby -Isrc -Itest test/run_all.rb`
Expected: všetky PASS (7 runs).

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(core): declarative ParamSchema with defaults, coercion and validation"
```

---

### Task 3: Box, Part, HardwareItem, Layout, Sizing, Registry

**Files:**
- Create: `src/skrine/core/box.rb`, `src/skrine/core/part.rb`, `src/skrine/core/hardware.rb`, `src/skrine/core/layout.rb`, `src/skrine/core/sizing.rb`, `src/skrine/core/registry.rb`
- Modify: `src/skrine/core.rb`
- Test: `test/core/layout_test.rb`, `test/core/sizing_test.rb`

**Interfaces:**
- Produces:
  - `Core::Box.new(x:, y:, z:, dx:, dy:, dz:)` + `x2/y2/z2`, `to_h`.
  - `Core::Part.new(name:, category:, material:, length:, width:, thickness:, edges:, grain:, box:, rotation:, meta:)`; `edges` = `{long_a:, long_b:, short_a:, short_b:}` (bool); `edge_code -> "2D 1K"`; `to_attrs -> Hash` (ploché hodnoty pre SketchUp atribúty); `Part.from_attrs(Hash)`.
  - `Core::HardwareItem.new(kind:, name:, qty:, unit:, box:, meta:)`; `to_attrs`, `from_attrs`.
  - `Core::Layout`: `part(**kw) -> Part`, `hardware_item(**kw) -> HardwareItem`, `warn(msg)`, `error(msg)`, `valid?`, `parts`, `hardware`, `warnings`, `errors`, `info` (Hash), `find(name)`, `by_category(sym)`.
  - `Core::Sizing.resolve(specs, total) -> [Float]` (`specs = [{mode: :mm|:ratio|:auto, value:}]`), `Sizing.positions(sizes, separator, origin) -> [[start, size]]`, `Sizing::Error`.
  - `Core::Registry.register(key, label:, schema:, model_class:)`, `Registry.fetch(key) -> Type(key,label,schema,model_class)`, `Registry.types`.

- [ ] **Step 1: Failing testy**

`test/core/sizing_test.rb`:
```ruby
require 'test_helper'

class SizingTest < Minitest::Test
  Sizing = Skrine::Core::Sizing

  def test_auto_splits_evenly
    assert_equal [500.0, 500.0], Sizing.resolve([{ mode: :auto, value: 1 }, { mode: :auto, value: 1 }], 1000)
  end

  def test_mm_fixed_then_ratio_shares_rest
    sizes = Sizing.resolve([{ mode: :mm, value: 400 }, { mode: :ratio, value: 1 }, { mode: :ratio, value: 2 }], 1000)
    assert_equal [400.0, 200.0, 400.0], sizes
  end

  def test_string_modes_are_accepted
    assert_equal [300.0, 700.0], Sizing.resolve([{ mode: 'mm', value: '300' }, { mode: 'auto', value: 1 }], 1000)
  end

  def test_fixed_overflow_raises
    assert_raises(Sizing::Error) { Sizing.resolve([{ mode: :mm, value: 1200 }], 1000) }
  end

  def test_all_fixed_must_match_total
    assert_raises(Sizing::Error) { Sizing.resolve([{ mode: :mm, value: 400 }], 1000) }
    assert_equal [1000.0], Sizing.resolve([{ mode: :mm, value: 1000 }], 1000)
  end

  def test_positions_with_separator
    assert_equal [[10.0, 100.0], [128.0, 200.0]], Sizing.positions([100.0, 200.0], 18, 10.0)
  end
end
```

`test/core/layout_test.rb`:
```ruby
require 'test_helper'

class LayoutTest < Minitest::Test
  Core = Skrine::Core

  def test_part_edge_code_and_attr_roundtrip
    part = Core::Part.new(name: 'Bok Ľ', category: :corpus, material: :corpus, length: 2300, width: 582, thickness: 18,
                          edges: { long_a: true, long_b: false, short_a: true, short_b: true },
                          box: Core::Box.new(x: 0, y: 18, z: 100, dx: 18, dy: 582, dz: 2300), meta: { side: :left })
    assert_equal '1D 2K', part.edge_code
    attrs = part.to_attrs
    assert_equal 'corpus', attrs['category']
    assert_kind_of String, attrs['edges']
    back = Core::Part.from_attrs(attrs)
    assert_equal :corpus, back.category
    assert_equal part.edges, back.edges
    assert_equal 'left', back.meta[:side]
    assert_nil back.box
  end

  def test_part_defaults
    part = Core::Part.new(name: 'X', category: :shelf, material: :corpus, length: 1, width: 1, thickness: 1)
    assert_equal '-', part.edge_code
    assert_equal :length, part.grain
    assert_equal({}, part.meta)
  end

  def test_layout_collects_parts_hardware_and_messages
    l = Core::Layout.new
    l.part(name: 'Strop', category: :corpus, material: :corpus, length: 1, width: 1, thickness: 18)
    l.hardware_item(kind: :hinge, name: 'Pánt', qty: 2, unit: :pcs)
    l.warn('w')
    assert l.valid?
    l.error('e')
    refute l.valid?
    assert_equal 'Strop', l.find('Strop').name
    assert_equal 1, l.by_category(:corpus).size
    assert_equal ['w'], l.warnings
    assert_equal 2, l.hardware.first.qty
  end

  def test_registry
    schema = Core::ParamSchema.new { number :w, 1, label: 'w' }
    klass = Class.new
    Core::Registry.register(:demo, label: 'Demo', schema: schema, model_class: klass)
    t = Core::Registry.fetch('demo')
    assert_equal :demo, t.key
    assert_equal klass, t.model_class
    assert_raises(Skrine::Core::Registry::UnknownType) { Core::Registry.fetch(:nope) }
  end
end
```

- [ ] **Step 2: Spusti – zlyhá**

Run: `/opt/homebrew/opt/ruby/bin/ruby -Isrc -Itest test/run_all.rb`
Expected: `uninitialized constant Skrine::Core::Sizing` (a Part/Layout/Registry).

- [ ] **Step 3: Implementácia**

`src/skrine/core/box.rb`:
```ruby
module Skrine
  module Core
    # Axis-aligned box in wardrobe-local millimetres.
    Box = Struct.new(:x, :y, :z, :dx, :dy, :dz, keyword_init: true) do
      def x2 = x + dx
      def y2 = y + dy
      def z2 = z + dz
    end
  end
end
```

`src/skrine/core/part.rb`:
```ruby
require 'json'

module Skrine
  module Core
    # One sheet part. +length+ runs along the grain; +edges+ marks banded
    # edges: long_a/long_b are the two edges of size +length+, short_a/short_b
    # the two of size +width+.
    Part = Struct.new(:name, :category, :material, :length, :width, :thickness,
                      :edges, :grain, :box, :rotation, :meta, keyword_init: true) do
      NO_EDGES = { long_a: false, long_b: false, short_a: false, short_b: false }.freeze

      def initialize(**kw)
        kw[:edges] = NO_EDGES.merge(kw[:edges] || {})
        kw[:grain] ||= :length
        kw[:meta] ||= {}
        super
      end

      # "2D 1K" – D = long edges (dlhé), K = short edges (krátke).
      def edge_code
        long = [edges[:long_a], edges[:long_b]].count(true)
        short = [edges[:short_a], edges[:short_b]].count(true)
        code = []
        code << "#{long}D" if long.positive?
        code << "#{short}K" if short.positive?
        code.empty? ? '-' : code.join(' ')
      end

      def edge_length
        (edges[:long_a] ? length : 0) + (edges[:long_b] ? length : 0) +
          (edges[:short_a] ? width : 0) + (edges[:short_b] ? width : 0)
      end

      # Flat, attribute-safe representation (strings/numbers only).
      def to_attrs
        {
          'name' => name, 'category' => category.to_s, 'material' => material.to_s,
          'length' => length.to_f, 'width' => width.to_f, 'thickness' => thickness.to_f,
          'edges' => JSON.generate(edges), 'grain' => grain.to_s, 'meta' => JSON.generate(meta)
        }
      end

      def self.from_attrs(a)
        new(name: a['name'], category: a['category'].to_sym, material: a['material'].to_sym,
            length: a['length'].to_f, width: a['width'].to_f, thickness: a['thickness'].to_f,
            edges: JSON.parse(a['edges'] || '{}', symbolize_names: true),
            grain: (a['grain'] || 'length').to_sym,
            meta: JSON.parse(a['meta'] || '{}', symbolize_names: true))
      end
    end
  end
end
```

`src/skrine/core/hardware.rb`:
```ruby
require 'json'

module Skrine
  module Core
    # Hardware / fittings entry. Items with a +box+ are drawn schematically.
    # unit: :pcs, :pair, :set or :mm (qty is then a length).
    HardwareItem = Struct.new(:kind, :name, :qty, :unit, :box, :meta, keyword_init: true) do
      def initialize(**kw)
        kw[:unit] ||= :pcs
        kw[:meta] ||= {}
        super
      end

      def to_attrs
        { 'kind' => kind.to_s, 'name' => name, 'qty' => qty.to_f, 'unit' => unit.to_s, 'meta' => JSON.generate(meta) }
      end

      def self.from_attrs(a)
        new(kind: a['kind'].to_sym, name: a['name'], qty: a['qty'].to_f, unit: (a['unit'] || 'pcs').to_sym,
            meta: JSON.parse(a['meta'] || '{}', symbolize_names: true))
      end
    end
  end
end
```

`src/skrine/core/layout.rb`:
```ruby
require_relative 'part'
require_relative 'hardware'

module Skrine
  module Core
    # Result of a generator: parts, hardware, computed info and messages.
    class Layout
      attr_reader :parts, :hardware, :warnings, :errors, :info

      def initialize
        @parts = []
        @hardware = []
        @warnings = []
        @errors = []
        @info = {}
      end

      def part(**kw)
        Part.new(**kw).tap { |p| @parts << p }
      end

      def hardware_item(**kw)
        HardwareItem.new(**kw).tap { |h| @hardware << h }
      end

      def warn(message)
        @warnings << message
        nil
      end

      def error(message)
        @errors << message
        nil
      end

      def valid?
        @errors.empty?
      end

      def find(name)
        @parts.find { |p| p.name == name }
      end

      def by_category(category)
        @parts.select { |p| p.category == category }
      end
    end
  end
end
```

`src/skrine/core/sizing.rb`:
```ruby
module Skrine
  module Core
    # Distributes a total length among items given as
    # {mode: :mm | :ratio | :auto, value: Numeric}. :mm is fixed, :ratio shares
    # the remainder proportionally, :auto behaves like ratio 1.
    module Sizing
      class Error < StandardError; end

      def self.resolve(specs, total)
        specs = specs.map { |s| { mode: s[:mode].to_s.to_sym, value: s[:value].to_f } }
        fixed = specs.select { |s| s[:mode] == :mm }.sum { |s| s[:value] }
        remaining = total.to_f - fixed
        raise Error, "pevné rozmery (#{fixed.round(1)} mm) presahujú dostupný priestor (#{total.round(1)} mm)" if remaining < -0.01

        weights = specs.map { |s| s[:mode] == :ratio ? s[:value] : (s[:mode] == :auto ? 1.0 : 0.0) }
        wsum = weights.sum
        if wsum <= 0 && remaining.abs > 0.01
          raise Error, "súčet pevných rozmerov (#{fixed.round(1)} mm) sa nerovná dostupnému priestoru (#{total.round(1)} mm) – pridaj položku v režime auto"
        end

        specs.each_with_index.map do |s, i|
          s[:mode] == :mm ? s[:value] : (wsum.positive? ? remaining * weights[i] / wsum : 0.0)
        end
      end

      def self.positions(sizes, separator, origin = 0.0)
        pos = origin.to_f
        sizes.map do |s|
          entry = [pos, s]
          pos += s + separator
          entry
        end
      end
    end
  end
end
```

`src/skrine/core/registry.rb`:
```ruby
module Skrine
  module Core
    # Registry of parametric object types (wardrobe, later top cabinet, ...).
    # model_class must respond to .new(params) and #layout -> Layout.
    module Registry
      class UnknownType < StandardError; end

      Type = Struct.new(:key, :label, :schema, :model_class, keyword_init: true)

      @types = {}

      def self.register(key, label:, schema:, model_class:)
        @types[key.to_sym] = Type.new(key: key.to_sym, label: label, schema: schema, model_class: model_class)
      end

      def self.fetch(key)
        @types.fetch(key.to_s.to_sym) { raise UnknownType, "neznámy typ objektu: #{key}" }
      end

      def self.types
        @types.values
      end
    end
  end
end
```

Do `src/skrine/core.rb` pridaj (v tomto poradí):
```ruby
require_relative 'core/box'
require_relative 'core/part'
require_relative 'core/hardware'
require_relative 'core/layout'
require_relative 'core/sizing'
require_relative 'core/registry'
```

- [ ] **Step 4: Spusti testy**

Run: `/opt/homebrew/opt/ruby/bin/ruby -Isrc -Itest test/run_all.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(core): Box, Part, HardwareItem, Layout, Sizing and type Registry"
```

---

### Task 4: Dáta systémov zásuviek + schéma parametrov typu Skriňa

**Files:**
- Create: `src/skrine/data/drawer_systems.rb`, `src/skrine/wardrobe/params.rb`
- Modify: `src/skrine/core.rb`
- Test: `test/wardrobe/params_test.rb`

**Interfaces:**
- Produces: `Skrine::Data::DrawerSystems::DEFAULTS` (Hash key → hash so stringovými tabuľkami), `Skrine::Wardrobe::Params::SCHEMA` (ParamSchema), plus sub-schémy `PANEL`, `PANEL_WITH_CORNERS`, `HANDLE`, `DOORS`, `CELL`, `COLUMN`, `MATERIALS`, `DRAWER_SYSTEM`.
- Kľúče parametrov (používajú ich Task 5–8) – viď kód nižšie; `columns[i][:cells]` sú **zhora nadol**.

- [ ] **Step 1: Failing test**

`test/wardrobe/params_test.rb`:
```ruby
require 'test_helper'

class WardrobeParamsTest < Minitest::Test
  SCHEMA = Skrine::Wardrobe::Params::SCHEMA

  def test_defaults_are_valid
    assert_equal [], SCHEMA.validate(SCHEMA.defaults)
  end

  def test_default_layout_has_two_columns_with_two_cells
    d = SCHEMA.defaults
    assert_equal 2, d[:columns].size
    assert_equal %i[rod drawers], d[:columns][0][:cells].map { |c| c[:content] }
    assert_equal 600, d[:columns][0][:cells][1][:height]
    assert_equal :mm, d[:columns][0][:cells][1][:height_mode]
    assert_equal :double, d[:columns][0][:doors][:type]
  end

  def test_drawer_systems_are_editable_tables
    d = SCHEMA.defaults
    assert_equal 'Blum LEGRABOX', d[:drawer_systems][:blum_legrabox][:label]
    assert_match(/N:/, d[:drawer_systems][:blum_legrabox][:heights])
    assert_equal :blum_legrabox, d[:drawer_system]
  end

  def test_materials_have_names_and_colors
    d = SCHEMA.defaults
    assert_equal 'DTD 18 biela', d[:materials][:corpus][:name]
    assert_match(/\A#[0-9a-f]{6}\z/, d[:materials][:front][:color])
  end

  def test_json_roundtrip_keeps_symbols
    json = JSON.generate(SCHEMA.defaults)
    back = SCHEMA.merge_defaults(JSON.parse(json))
    assert_equal SCHEMA.defaults, back
  end
end
```

- [ ] **Step 2: Spusti – zlyhá** (`uninitialized constant Skrine::Wardrobe`).

- [ ] **Step 3: Implementácia**

`src/skrine/data/drawer_systems.rb`:
```ruby
module Skrine
  module Data
    # Default drawer-system tables. Values are typical catalogue figures and are
    # editable in the dialog (Zásuvky › Tabuľky systémov); verify against the
    # manufacturer's current catalogue before ordering.
    # heights: "CLASS:side_height_mm,..." ; lengths: nominal runner lengths (NL).
    module DrawerSystems
      DEFAULTS = {
        front_only: {
          label: 'Len čelo + výsuv', box: :none, heights: '', lengths: '250,300,350,400,450,500,550,600',
          side_clearance: 0, height_clearance: 0, bottom_width_deduction: 0, bottom_length_deduction: 0,
          back_width_deduction: 0, back_height_deduction: 0, front_min_extra: 0
        },
        wood_box: {
          label: 'Drevený box', box: :wood, heights: '', lengths: '250,300,350,400,450,500,550,600',
          side_clearance: 13, height_clearance: 25, bottom_width_deduction: 0, bottom_length_deduction: 0,
          back_width_deduction: 0, back_height_deduction: 0, front_min_extra: 0
        },
        blum_legrabox: {
          label: 'Blum LEGRABOX', box: :metal, heights: 'N:66.5,M:90.5,K:128.5,C:177,F:241',
          lengths: '270,300,350,400,450,500,550,600,650',
          side_clearance: 12.5, height_clearance: 0, bottom_width_deduction: 87, bottom_length_deduction: 12,
          back_width_deduction: 87, back_height_deduction: 0, front_min_extra: 12
        },
        blum_tandembox: {
          label: 'Blum TANDEMBOX antaro', box: :metal, heights: 'N:68,M:83,K:115,C:192,D:224',
          lengths: '270,300,350,400,450,500,550,600,650',
          side_clearance: 12.5, height_clearance: 0, bottom_width_deduction: 87, bottom_length_deduction: 14,
          back_width_deduction: 87, back_height_deduction: 0, front_min_extra: 15
        },
        blum_merivobox: {
          label: 'Blum MERIVOBOX', box: :metal, heights: 'N:68,M:91,K:127,E:187',
          lengths: '270,300,350,400,450,500,550,600',
          side_clearance: 12.5, height_clearance: 0, bottom_width_deduction: 84, bottom_length_deduction: 12,
          back_width_deduction: 84, back_height_deduction: 0, front_min_extra: 12
        }
      }.freeze
    end
  end
end
```

`src/skrine/wardrobe/params.rb`:
```ruby
require_relative '../core/param_schema'
require_relative '../data/drawer_systems'

module Skrine
  module Wardrobe
    # Parameter schema of the "Skriňa" object type.
    module Params
      S = Core::ParamSchema

      PANEL = S.new do
        number :thickness, 18, label: 'Hrúbka', min: 3, max: 60
        number :front_recess, 0, label: 'Odsadenie vpredu', min: 0
        number :back_recess, 0, label: 'Odsadenie vzadu', min: 0
      end

      PANEL_WITH_CORNERS = S.new do
        number :thickness, 18, label: 'Hrúbka', min: 3, max: 60
        enum :corner_left, :inset, options: %i[inset overlay], label: 'Ľavý roh (medzi bokmi / cez bok)'
        enum :corner_right, :inset, options: %i[inset overlay], label: 'Pravý roh (medzi bokmi / cez bok)'
        number :engagement, 0, label: 'Zapustenie do boku', min: 0, max: 20
        number :front_recess, 0, label: 'Odsadenie vpredu', min: 0
        number :back_recess, 0, label: 'Odsadenie vzadu', min: 0
      end

      HANDLE = S.new do
        enum :type, :profile, options: %i[none drilled profile], label: 'Typ úchytky'
        number :hole_spacing, 160, label: 'Rozteč otvorov', min: 0
        number :offset_edge, 30, label: 'Odsadenie od hrany', min: 0
        enum :orientation, :horizontal, options: %i[horizontal vertical], label: 'Orientácia'
        number :profile_height, 30, label: 'Výška profilu (skráti čelo)', min: 0, max: 100
        enum :profile_position, :top, options: %i[top bottom], label: 'Pozícia profilu'
      end

      DOORS = S.new do
        enum :type, :double, options: %i[none single_left single_right double flap_up], label: 'Typ dverí'
        enum :mount, :overlay, options: %i[overlay half_overlay inset], label: 'Uloženie čiel'
      end

      CELL = S.new do
        enum :height_mode, :auto, options: %i[auto mm ratio], label: 'Výška – režim'
        number :height, 1, label: 'Výška (mm / pomer)', min: 0
        enum :content, :shelves, options: %i[shelves rod drawers inner_drawers empty], label: 'Obsah'
        integer :shelves_count, 2, label: 'Počet políc', min: 0, max: 30
        integer :drawers_count, 3, label: 'Počet zásuviek', min: 1, max: 12
        string :drawer_heights, '', label: 'Výšky čiel zhora (mm, čiarkou; prázdne = rovnomerne)'
        number :rod_offset_top, 60, label: 'Tyč – odsadenie zhora', min: 0
      end

      COLUMN = S.new do
        enum :width_mode, :auto, options: %i[auto mm ratio], label: 'Šírka – režim'
        number :width, 1, label: 'Šírka (mm / pomer)', min: 0
        boolean :doors_override, false, label: 'Vlastné nastavenie dverí'
        object :doors, DOORS, label: 'Dvere'
        boolean :handle_override, false, label: 'Vlastná úchytka'
        object :handle, HANDLE, label: 'Úchytka'
        list :cells, CELL, label: 'Polia (zhora nadol)', default: [{}]
      end

      MATERIAL = S.new do
        string :name, '', label: 'Názov / dekor'
        string :color, '#ffffff', label: 'Farba v modeli (#rrggbb)'
      end

      MATERIALS = S.new do
        object :corpus, MATERIAL, label: 'Korpus', default: { name: 'DTD 18 biela', color: '#e8e8e8' }
        object :front, MATERIAL, label: 'Čelá', default: { name: 'DTD 18 dekor', color: '#f4b8a0' }
        object :back, MATERIAL, label: 'Zadná stena', default: { name: 'HDF 3 biela', color: '#f5f5f5' }
        object :drawer_box, MATERIAL, label: 'Zásuvkový box', default: { name: 'DTD 16 biela', color: '#dddddd' }
        object :strip, MATERIAL, label: 'Lišty', default: { name: 'DTD 18 biela', color: '#e0e0e0' }
      end

      DRAWER_SYSTEM = S.new do
        string :label, '', label: 'Názov'
        enum :box, :metal, options: %i[none wood metal], label: 'Typ boxu'
        string :heights, '', label: 'Výškové triedy (N:66.5,M:90.5,…)'
        string :lengths, '', label: 'Nominálne dĺžky NL (mm, čiarkou)'
        number :side_clearance, 0, label: 'Bočná vôľa na stranu', min: 0
        number :height_clearance, 0, label: 'Výšková vôľa dreveného boxu', min: 0
        number :bottom_width_deduction, 0, label: 'Dno: odpočet od vnútornej šírky', min: 0
        number :bottom_length_deduction, 0, label: 'Dno: odpočet od NL', min: 0
        number :back_width_deduction, 0, label: 'Zadný diel: odpočet od vnútornej šírky', min: 0
        number :back_height_deduction, 0, label: 'Zadný diel: odpočet od výšky triedy', min: 0
        number :front_min_extra, 0, label: 'Min. presah čela nad výšku triedy', min: 0
      end

      DRAWER_SYSTEMS = S.new do
        Data::DrawerSystems::DEFAULTS.each do |key, defaults|
          object key, DRAWER_SYSTEM, label: defaults[:label], default: defaults
        end
      end

      SCHEMA = S.new do
        group :dims, 'Rozmery' do
          number :width, 2000, label: 'Šírka (vonkajšia)', min: 200, max: 10_000
          number :height, 2400, label: 'Výška (vonkajšia)', min: 200, max: 4000
          number :depth, 600, label: 'Hĺbka (vonkajšia)', min: 100, max: 1500
          boolean :depth_includes_fronts, true, label: 'Hĺbka vrátane čiel'
          number :gap_left, 0, label: 'Odsadenie od steny vľavo', min: 0
          number :gap_right, 0, label: 'Odsadenie od steny vpravo', min: 0
          boolean :filler_left, false, label: 'Zaslepovacia lišta vľavo'
          boolean :filler_right, false, label: 'Zaslepovacia lišta vpravo'
          number :gap_top, 0, label: 'Odsadenie od stropu', min: 0
          boolean :top_strip, false, label: 'Krycia lišta hore'
          number :top_strip_height, 0, label: 'Výška hornej lišty (0 = celé odsadenie)', min: 0
          number :top_strip_setback, 0, label: 'Zapustenie hornej lišty od čiel', min: 0
          enum :base_type, :legs, options: %i[legs plinth floor], label: 'Spodok (nožičky / sokel medzi bokmi / na podlahe)'
          number :base_height, 100, label: 'Výška spodku', min: 0, max: 400
          boolean :bottom_strip, true, label: 'Krycia lišta dole (sokel)'
          number :bottom_strip_setback, 50, label: 'Zapustenie sokla od čiel', min: 0
          number :strip_floor_clearance, 10, label: 'Medzera sokla od podlahy', min: 0
        end

        group :construction, 'Konštrukcia' do
          number :panel_thickness, 18, label: 'Hrúbka korpusu (všeobecná)', min: 3, max: 60
          number :front_thickness, 18, label: 'Hrúbka čiel', min: 3, max: 60
          number :back_thickness, 3, label: 'Hrúbka zadnej steny (HDF)', min: 1, max: 30
          number :shelf_thickness, 18, label: 'Hrúbka políc', min: 3, max: 60
          number :partition_thickness, 18, label: 'Hrúbka priečok', min: 3, max: 60
          number :strip_thickness, 18, label: 'Hrúbka líšt', min: 3, max: 60
          object :top, PANEL_WITH_CORNERS, label: 'Strop'
          object :bottom, PANEL_WITH_CORNERS, label: 'Dno'
          object :side_left, PANEL, label: 'Ľavý bok'
          object :side_right, PANEL, label: 'Pravý bok'
          enum :back_mode, :groove, options: %i[groove overlay inset], label: 'Zadná stena (v drážke / nalozená / priznaná)'
          number :groove_depth, 8, label: 'Hĺbka drážky', min: 0
          number :groove_offset, 12, label: 'Drážka od zadnej hrany', min: 0
          number :back_inset_thickness, 18, label: 'Hrúbka priznanej zadnej steny', min: 3
          number :shelf_setback, 2, label: 'Zapustenie políc vpredu', min: 0
          number :shelf_back_clearance, 0, label: 'Vôľa políc vzadu', min: 0
          boolean :line_drilling, false, label: 'Rad otvorov (systém 32)'
          number :drill_pitch, 32, label: 'Rozteč otvorov', min: 1
          number :drill_offset_front, 37, label: 'Rad od prednej hrany', min: 0
          number :drill_offset_back, 37, label: 'Rad od zadnej hrany', min: 0
          number :drill_start, 100, label: 'Prvý otvor od dna', min: 0
          number :drill_end_offset, 100, label: 'Posledný otvor od stropu', min: 0
        end

        group :fronts, 'Čelá a špáry' do
          number :front_gap_h, 3, label: 'Špára medzi čelami vodorovne', min: 0
          number :front_gap_v, 3, label: 'Špára medzi čelami zvisle', min: 0
          number :reveal_top, 2, label: 'Odsadenie čela od hornej hrany', min: 0
          number :reveal_bottom, 0, label: 'Odsadenie čela od spodnej hrany', min: 0
          number :reveal_left, 2, label: 'Odsadenie čela od ľavej hrany', min: 0
          number :reveal_right, 2, label: 'Odsadenie čela od pravej hrany', min: 0
          number :inset_depth, 2, label: 'Zapustenie vnorených čiel', min: 0
          enum :front_grain, :vertical, options: %i[vertical horizontal], label: 'Smer dekoru čiel'
        end

        group :doors, 'Dvere' do
          boolean :doors_enabled, true, label: 'Dvere (vypnuté = otvorený korpus)'
          object :doors, DOORS, label: 'Predvolené dvere'
          enum :door_display, :closed, options: %i[closed open], label: 'Zobrazenie dverí'
          number :open_angle, 90, label: 'Uhol otvorenia', min: 0, max: 180, unit: '°'
          number :door_max_width, 600, label: 'Max. odporúčaná šírka krídla', min: 100
          string :hinge_table, '900:2,1600:3,2100:4,9999:5', label: 'Pánty: do výšky:počet, …'
        end

        group :handles, 'Úchytky' do
          object :handle, HANDLE, label: 'Predvolená úchytka'
        end

        group :drawers, 'Zásuvky' do
          enum :drawer_system, :blum_legrabox, options: Data::DrawerSystems::DEFAULTS.keys, label: 'Systém zásuviek'
          number :drawer_box_thickness, 16, label: 'Hrúbka bokov/zadného dielu boxu', min: 3
          number :drawer_bottom_thickness, 3, label: 'Drevený box – hrúbka dna', min: 1
          number :drawer_bottom_groove, 6, label: 'Drevený box – drážka dna', min: 0
          number :metal_box_bottom_thickness, 16, label: 'Kovový box – hrúbka dna', min: 3
          number :drawer_depth_reserve, 20, label: 'Rezerva hĺbky za zásuvkou', min: 0
          number :inner_drawer_setback, 30, label: 'Vnorená zásuvka – zapustenie čela', min: 0
          number :inner_drawer_side_gap, 3, label: 'Vnorená zásuvka – bočná špára', min: 0
          object :drawer_systems, DRAWER_SYSTEMS, label: 'Tabuľky systémov'
        end

        group :columns, 'Stĺpce' do
          list :columns, COLUMN, label: 'Stĺpce (zľava doprava)', default: [
            { cells: [{ content: :rod }, { content: :drawers, height_mode: :mm, height: 600, drawers_count: 3 }] },
            { cells: [{ content: :shelves, shelves_count: 4 }, { content: :drawers, height_mode: :mm, height: 600, drawers_count: 3 }] }
          ]
        end

        group :materials, 'Materiály' do
          object :materials, MATERIALS, label: 'Materiály'
        end

        group :hardware, 'Kovanie a hrany' do
          enum :joinery, :confirmat, options: %i[none dowels confirmat cam_lock], label: 'Spojovací materiál'
          number :joinery_pitch, 300, label: 'Rozteč spojov', min: 50
          integer :wall_brackets, 0, label: 'Závesné kovanie (ks)', min: 0
          enum :edge_corpus, :front, options: %i[none front all], label: 'Hrany – boky, strop, dno'
          enum :edge_shelf, :front, options: %i[none front all], label: 'Hrany – police, priečky'
          enum :edge_front, :all, options: %i[none front all], label: 'Hrany – čelá'
          enum :edge_strip, :all, options: %i[none front all], label: 'Hrany – lišty'
          enum :edge_drawer_box, :front, options: %i[none front all], label: 'Hrany – drevený box (horná hrana)'
        end
      end
    end
  end
end
```

Do `src/skrine/core.rb` pridaj:
```ruby
require_relative 'data/drawer_systems'
require_relative 'wardrobe/params'
```

- [ ] **Step 4: Spusti testy** – PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(wardrobe): parameter schema and drawer-system tables"
```

---

### Task 5: Model – rám, korpus, spodok, lišty, zadná stena

**Files:**
- Create: `src/skrine/wardrobe/model.rb`, `src/skrine/wardrobe/corpus.rb`
- Create (prázdne moduly, naplnia sa v Task 6–9): `src/skrine/wardrobe/columns.rb`, `src/skrine/wardrobe/fronts.rb`, `src/skrine/wardrobe/drawers.rb`, `src/skrine/wardrobe/extras.rb`
- Modify: `src/skrine/core.rb`, `test/test_helper.rb`
- Test: `test/wardrobe/corpus_test.rb`

**Interfaces:**
- Produces: `Skrine::Wardrobe::Model.new(params).layout -> Core::Layout`; vnútorné `@p` (merged params), `@f` (frame hash s kľúčmi `corpus_x0 corpus_w corpus_z0 corpus_h corpus_y0 corpus_d body_d inner_x0 inner_w inner_z0 inner_h inner_d back_clearance t_top t_bot base_h fronts_protrude`), helpery `edges_for(rule, visible)`, `column_doors(col_params)`, `column_handle(col_params)`, `drilling_spec`.
- Test helper: `wardrobe(**overrides) -> Layout` a `wardrobe_params(**overrides)`.

- [ ] **Step 1: Test helper + failing test**

Do `test/test_helper.rb` pridaj:
```ruby
module WardrobeHelper
  # Build a wardrobe layout from defaults merged with +overrides+ (top-level keys only;
  # pass whole sub-hashes/arrays for nested params).
  def wardrobe_params(**overrides)
    Skrine::Wardrobe::Params::SCHEMA.defaults.merge(overrides)
  end

  def wardrobe(**overrides)
    Skrine::Wardrobe::Model.new(wardrobe_params(**overrides)).layout
  end

  def assert_box(part, x:, y:, z:, dx:, dy:, dz:, delta: 0.01)
    b = part.box
    { x: x, y: y, z: z, dx: dx, dy: dy, dz: dz }.each do |k, v|
      assert_in_delta v, b[k], delta, "#{part.name}.#{k}"
    end
  end
end
Minitest::Test.include WardrobeHelper
```

`test/wardrobe/corpus_test.rb` (referenčná konfigurácia: 2000×2400×600, nožičky 100, groove 3 mm, overlay čelá → korpus začína v Y=18, hĺbka korpusu 582):
```ruby
require 'test_helper'

class CorpusTest < Minitest::Test
  def test_default_layout_is_valid
    l = wardrobe
    assert l.valid?, l.errors.join('; ')
  end

  def test_frame_info
    l = wardrobe
    assert_in_delta 1964, l.info[:inner_w]
    assert_in_delta 2264, l.info[:inner_h]     # 2300 corpus - 18 - 18
    assert_in_delta 567, l.info[:inner_d]      # 582 - (12 groove offset + 3 HDF)
  end

  def test_sides_full_height_between_inset_top_and_bottom
    l = wardrobe
    left = l.find('Bok Ľ')
    assert_box left, x: 0, y: 18, z: 100, dx: 18, dy: 582, dz: 2300
    assert_equal 2300, left.length
    assert_equal 582, left.width
    assert_equal '1D', left.edge_code
    right = l.find('Bok P')
    assert_box right, x: 1982, y: 18, z: 100, dx: 18, dy: 582, dz: 2300
  end

  def test_top_and_bottom_inset_between_sides
    l = wardrobe
    assert_box l.find('Strop'), x: 18, y: 18, z: 2382, dx: 1964, dy: 582, dz: 18
    assert_box l.find('Dno'), x: 18, y: 18, z: 100, dx: 1964, dy: 582, dz: 18
  end

  def test_top_overlay_shortens_sides
    top = wardrobe_params[:top].merge(corner_left: :overlay, corner_right: :overlay)
    l = wardrobe(top: top)
    assert_box l.find('Strop'), x: 0, y: 18, z: 2382, dx: 2000, dy: 582, dz: 18
    assert_box l.find('Bok Ľ'), x: 0, y: 18, z: 100, dx: 18, dy: 582, dz: 2282
  end

  def test_engagement_extends_bottom_into_sides
    bottom = wardrobe_params[:bottom].merge(engagement: 6)
    l = wardrobe(bottom: bottom)
    assert_box l.find('Dno'), x: 12, y: 18, z: 100, dx: 1976, dy: 582, dz: 18
  end

  def test_side_recess_and_custom_thickness
    l = wardrobe(side_left: { thickness: 25, front_recess: 10, back_recess: 5 })
    assert_box l.find('Bok Ľ'), x: 0, y: 28, z: 100, dx: 25, dy: 567, dz: 2300
    assert_in_delta 1957, l.info[:inner_w]
  end

  def test_legs_and_bottom_strip
    l = wardrobe
    legs = l.hardware.select { |h| h.kind == :leg }
    assert_equal 6, legs.sum(&:qty)                 # 4 + 2 per partition (1 partition)
    assert legs.all?(&:box)
    strip = l.find('Sokel')
    assert_box strip, x: 0, y: 50, z: 10, dx: 2000, dy: 18, dz: 90
    assert_equal :strip, strip.category
  end

  def test_plinth_sides_reach_floor_and_plinth_sits_between_sides
    l = wardrobe(base_type: :plinth)
    assert_box l.find('Bok Ľ'), x: 0, y: 18, z: 0, dx: 18, dy: 582, dz: 2400
    assert_box l.find('Sokel'), x: 18, y: 50, z: 10, dx: 1964, dy: 18, dz: 90
    assert_empty l.hardware.select { |h| h.kind == :leg }
  end

  def test_floor_base_has_no_strip_and_full_corpus
    l = wardrobe(base_type: :floor)
    assert_nil l.find('Sokel')
    assert_box l.find('Dno'), x: 18, y: 18, z: 0, dx: 1964, dy: 582, dz: 18
  end

  def test_top_strip_and_gap_top
    l = wardrobe(gap_top: 80, top_strip: true, top_strip_setback: 5)
    assert_box l.find('Lišta horná'), x: 0, y: 5, z: 2320, dx: 2000, dy: 18, dz: 80
    assert_box l.find('Strop'), x: 18, y: 18, z: 2302, dx: 1964, dy: 582, dz: 18
  end

  def test_wall_gaps_and_fillers
    l = wardrobe(gap_left: 30, gap_right: 20, filler_left: true)
    assert_box l.find('Bok Ľ'), x: 30, y: 18, z: 100, dx: 18, dy: 582, dz: 2300
    assert_box l.find('Lišta zaslepovacia Ľ'), x: 0, y: 0, z: 100, dx: 30, dy: 18, dz: 2300
    assert_nil l.find('Lišta zaslepovacia P')
    assert_in_delta 1950, l.info[:corpus_w]
  end

  def test_back_groove
    l = wardrobe
    back = l.find('Zadná stena')
    assert_box back, x: 10, y: 585, z: 110, dx: 1980, dy: 3, dz: 2280
    assert_equal 3, back.thickness
    assert_equal :back, back.material
  end

  def test_back_overlay_shortens_body
    l = wardrobe(back_mode: :overlay)
    assert_box l.find('Zadná stena'), x: 0, y: 597, z: 100, dx: 2000, dy: 3, dz: 2300
    assert_box l.find('Bok Ľ'), x: 0, y: 18, z: 100, dx: 18, dy: 579, dz: 2300
    assert_in_delta 579, l.info[:inner_d]
  end

  def test_back_inset_uses_thick_panel_between_sides
    l = wardrobe(back_mode: :inset)
    assert_box l.find('Zadná stena'), x: 18, y: 582, z: 118, dx: 1964, dy: 18, dz: 2264
    assert_in_delta 564, l.info[:inner_d]
  end

  def test_depth_excluding_fronts
    l = wardrobe(depth_includes_fronts: false)
    assert_box l.find('Bok Ľ'), x: 0, y: 18, z: 100, dx: 18, dy: 600, dz: 2300
  end

  def test_invalid_params_produce_errors_not_parts
    l = wardrobe(width: 10)
    refute l.valid?
    assert_includes l.errors, 'width: min 200'
    assert_empty l.parts
  end

  def test_negative_inner_height_is_an_error
    l = wardrobe(height: 250, base_height: 200, gap_top: 60)
    refute l.valid?
    assert l.errors.any? { |e| e.include?('výška') }
  end
end
```

- [ ] **Step 2: Spusti – zlyhá** (`uninitialized constant Skrine::Wardrobe::Model`).

- [ ] **Step 3: Implementácia**

`src/skrine/wardrobe/model.rb`:
```ruby
require_relative '../core/layout'
require_relative '../core/sizing'
require_relative 'params'
require_relative 'corpus'
require_relative 'columns'
require_relative 'fronts'
require_relative 'drawers'
require_relative 'extras'

module Skrine
  module Wardrobe
    # Pure-Ruby wardrobe generator: params -> Core::Layout (mm). No SketchUp API.
    class Model
      include Corpus
      include Columns
      include Fronts
      include Drawers
      include Extras

      attr_reader :p, :f

      def initialize(params)
        @p = Params::SCHEMA.merge_defaults(params)
      end

      def layout
        @layout = Core::Layout.new
        Params::SCHEMA.validate(@p).each { |e| @layout.error(e) }
        return @layout unless @layout.valid?

        @f = compute_frame
        check_frame
        return @layout unless @layout.valid?

        build_corpus
        build_base
        build_strips
        build_back
        build_columns
        build_extras
        @layout.info.merge!(
          corpus_w: @f[:corpus_w].round(1), corpus_h: @f[:corpus_h].round(1), corpus_d: @f[:corpus_d].round(1),
          inner_w: @f[:inner_w].round(1), inner_h: @f[:inner_h].round(1), inner_d: @f[:inner_d].round(1)
        )
        @layout
      rescue Core::Sizing::Error => e
        @layout.error(e.message)
        @layout
      end

      # Edge flags from a rule (:none / :front / :all); +visible+ is the key of
      # the single visible edge used by the :front rule.
      def edges_for(rule, visible = :long_a)
        e = { long_a: false, long_b: false, short_a: false, short_b: false }
        case rule.to_s.to_sym
        when :all then e.transform_values! { true }
        when :front then e[visible] = true
        end
        e
      end

      def column_doors(col_params)
        col_params[:doors_override] ? col_params[:doors] : @p[:doors]
      end

      def column_handle(col_params)
        col_params[:handle_override] ? col_params[:handle] : @p[:handle]
      end

      def drilling_spec
        { pitch: @p[:drill_pitch], offset_front: @p[:drill_offset_front], offset_back: @p[:drill_offset_back],
          start: @p[:drill_start], end_offset: @p[:drill_end_offset] }
      end

      private

      attr_reader :layout

      def compute_frame
        f = {}
        f[:t_top] = p[:top][:thickness]
        f[:t_bot] = p[:bottom][:thickness]
        f[:fronts_protrude] = fronts_protrude
        f[:corpus_x0] = p[:gap_left].to_f
        f[:corpus_w] = p[:width] - p[:gap_left] - p[:gap_right]
        f[:base_h] = p[:base_type] == :floor ? 0.0 : p[:base_height].to_f
        f[:corpus_z0] = f[:base_h]
        f[:corpus_h] = p[:height] - f[:base_h] - p[:gap_top]
        f[:corpus_y0] = f[:fronts_protrude]
        f[:corpus_d] = p[:depth_includes_fronts] ? p[:depth] - f[:fronts_protrude] : p[:depth].to_f
        f[:body_d] = f[:corpus_d] - (p[:back_mode] == :overlay ? p[:back_thickness] : 0)
        f[:inner_x0] = f[:corpus_x0] + p[:side_left][:thickness]
        f[:inner_w] = f[:corpus_w] - p[:side_left][:thickness] - p[:side_right][:thickness]
        f[:inner_z0] = f[:corpus_z0] + f[:t_bot]
        f[:inner_h] = f[:corpus_h] - f[:t_bot] - f[:t_top]
        f[:back_clearance] = case p[:back_mode]
                             when :groove then p[:groove_offset] + p[:back_thickness]
                             when :inset then p[:back_inset_thickness]
                             else 0.0
                             end
        f[:inner_d] = f[:body_d] - f[:back_clearance]
        f
      end

      def check_frame
        layout.error("Vnútorná šírka korpusu je #{f[:inner_w].round} mm – zväčši šírku alebo zmenši odsadenia") if f[:inner_w] < 50
        layout.error("Vnútorná výška korpusu je #{f[:inner_h].round} mm – zväčši výšku alebo zmenši spodok/odsadenie od stropu") if f[:inner_h] < 50
        layout.error("Vnútorná hĺbka korpusu je #{f[:inner_d].round} mm") if f[:inner_d] < 50
      end

      def fronts_protrude
        return 0.0 unless any_fronts?

        mounts = p[:columns].map { |c| column_doors(c)[:mount] }
        mounts.any? { |m| m != :inset } ? p[:front_thickness].to_f : 0.0
      end

      def any_fronts?
        p[:columns].any? do |c|
          (p[:doors_enabled] && column_doors(c)[:type] != :none) || c[:cells].any? { |cell| cell[:content] == :drawers }
        end
      end
    end

    Core::Registry.register(:wardrobe, label: 'Skriňa', schema: Params::SCHEMA, model_class: Model)
  end
end
```

`src/skrine/wardrobe/corpus.rb`:
```ruby
module Skrine
  module Wardrobe
    # Corpus panels, base, cover strips, fillers and back panel.
    module Corpus
      def build_corpus
        build_side(:left)
        build_side(:right)
        build_horizontal(:top)
        build_horizontal(:bottom)
      end

      def build_side(which)
        sp = which == :left ? p[:side_left] : p[:side_right]
        corner = which == :left ? :corner_left : :corner_right
        t = sp[:thickness]
        x = which == :left ? f[:corpus_x0] : f[:corpus_x0] + f[:corpus_w] - t
        plinth = p[:base_type] == :plinth
        z0 = plinth ? 0.0 : f[:corpus_z0]
        z0 = f[:corpus_z0] + f[:t_bot] if !plinth && p[:bottom][corner] == :overlay
        z1 = f[:corpus_z0] + f[:corpus_h]
        z1 -= f[:t_top] if p[:top][corner] == :overlay
        y = f[:corpus_y0] + sp[:front_recess]
        dy = f[:body_d] - sp[:front_recess] - sp[:back_recess]
        part = layout.part(
          name: which == :left ? 'Bok Ľ' : 'Bok P', category: :corpus, material: :corpus,
          length: z1 - z0, width: dy, thickness: t, edges: edges_for(p[:edge_corpus], :long_a),
          box: Core::Box.new(x: x, y: y, z: z0, dx: t, dy: dy, dz: z1 - z0), meta: { side: which }
        )
        part.meta[:drilling] = drilling_spec if p[:line_drilling]
        part
      end

      def build_horizontal(which)
        pp = p[which]
        t = pp[:thickness]
        plinth_bottom = which == :bottom && p[:base_type] == :plinth
        corner_l = plinth_bottom ? :inset : pp[:corner_left]
        corner_r = plinth_bottom ? :inset : pp[:corner_right]
        x0 = corner_l == :overlay ? f[:corpus_x0] : f[:inner_x0] - pp[:engagement]
        x1 = corner_r == :overlay ? f[:corpus_x0] + f[:corpus_w] : f[:inner_x0] + f[:inner_w] + pp[:engagement]
        z = which == :top ? f[:corpus_z0] + f[:corpus_h] - t : f[:corpus_z0]
        y = f[:corpus_y0] + pp[:front_recess]
        dy = f[:body_d] - pp[:front_recess] - pp[:back_recess]
        layout.part(
          name: which == :top ? 'Strop' : 'Dno', category: :corpus, material: :corpus,
          length: x1 - x0, width: dy, thickness: t, edges: edges_for(p[:edge_corpus], :long_a),
          box: Core::Box.new(x: x0, y: y, z: z, dx: x1 - x0, dy: dy, dz: t)
        )
      end

      def build_base
        case p[:base_type]
        when :legs
          build_legs
          build_bottom_strip(f[:corpus_x0], f[:corpus_w]) if p[:bottom_strip]
        when :plinth
          build_bottom_strip(f[:inner_x0], f[:inner_w])
        end
      end

      def build_legs
        h = f[:base_h]
        return if h <= 0

        size = 40.0
        xs = [f[:corpus_x0] + 30, f[:corpus_x0] + f[:corpus_w] - 30 - size]
        # Legs are placed before partitions are laid out, so inner legs use even spacing.
        n_inner = p[:columns].size - 1
        n_inner.times { |i| xs << f[:corpus_x0] + f[:corpus_w] * (i + 1) / (n_inner + 1) - size / 2 }
        ys = [f[:corpus_y0] + 50, f[:corpus_y0] + f[:body_d] - 50 - size]
        xs.product(ys).each do |x, y|
          layout.hardware_item(kind: :leg, name: "Nožička #{h.round} mm", qty: 1, unit: :pcs,
                               box: Core::Box.new(x: x, y: y, z: 0.0, dx: size, dy: size, dz: h))
        end
      end

      def build_bottom_strip(x0, w)
        h = f[:base_h] - p[:strip_floor_clearance]
        return if h <= 0

        t = p[:strip_thickness]
        layout.part(
          name: 'Sokel', category: :strip, material: :strip, length: w, width: h, thickness: t,
          edges: edges_for(p[:edge_strip], :long_a),
          box: Core::Box.new(x: x0, y: p[:bottom_strip_setback].to_f, z: p[:strip_floor_clearance].to_f, dx: w, dy: t, dz: h)
        )
      end

      def build_strips
        build_top_strip if p[:top_strip]
        build_filler(:left) if p[:filler_left]
        build_filler(:right) if p[:filler_right]
      end

      def build_top_strip
        h = p[:top_strip_height].positive? ? p[:top_strip_height] : p[:gap_top]
        return layout.warn('Horná lišta: odsadenie od stropu je 0, lišta sa negeneruje') if h <= 0

        layout.warn("Horná lišta (#{h.round} mm) je vyššia než odsadenie od stropu (#{p[:gap_top].round} mm)") if h > p[:gap_top]
        t = p[:strip_thickness]
        layout.part(
          name: 'Lišta horná', category: :strip, material: :strip, length: f[:corpus_w], width: h, thickness: t,
          edges: edges_for(p[:edge_strip], :long_a),
          box: Core::Box.new(x: f[:corpus_x0], y: p[:top_strip_setback].to_f, z: f[:corpus_z0] + f[:corpus_h], dx: f[:corpus_w], dy: t, dz: h)
        )
      end

      def build_filler(which)
        gap = which == :left ? p[:gap_left] : p[:gap_right]
        return layout.warn("Zaslepovacia lišta #{which == :left ? 'vľavo' : 'vpravo'}: odsadenie od steny je 0") if gap <= 0

        t = p[:strip_thickness]
        z0 = p[:base_type] == :plinth ? 0.0 : f[:corpus_z0]
        h = f[:corpus_z0] + f[:corpus_h] - z0
        x = which == :left ? 0.0 : p[:width] - gap
        layout.part(
          name: "Lišta zaslepovacia #{which == :left ? 'Ľ' : 'P'}", category: :filler, material: :strip,
          length: h, width: gap, thickness: t, edges: edges_for(p[:edge_strip], :long_a),
          box: Core::Box.new(x: x, y: 0.0, z: z0, dx: gap, dy: t, dz: h)
        )
      end

      def build_back
        case p[:back_mode]
        when :groove
          t = p[:back_thickness]
          g = p[:groove_depth]
          box = Core::Box.new(x: f[:inner_x0] - g, y: f[:corpus_y0] + f[:body_d] - p[:groove_offset] - t,
                              z: f[:inner_z0] - g, dx: f[:inner_w] + 2 * g, dy: t, dz: f[:inner_h] + 2 * g)
        when :overlay
          t = p[:back_thickness]
          box = Core::Box.new(x: f[:corpus_x0], y: f[:corpus_y0] + f[:body_d], z: f[:corpus_z0],
                              dx: f[:corpus_w], dy: t, dz: f[:corpus_h])
        when :inset
          t = p[:back_inset_thickness]
          box = Core::Box.new(x: f[:inner_x0], y: f[:corpus_y0] + f[:body_d] - t, z: f[:inner_z0],
                              dx: f[:inner_w], dy: t, dz: f[:inner_h])
        end
        layout.part(name: 'Zadná stena', category: :back, material: :back, length: box.dz, width: box.dx,
                    thickness: t, edges: edges_for(:none), grain: :none, box: box)
      end
    end
  end
end
```

Prázdne moduly (naplnia sa v ďalších taskoch) – `src/skrine/wardrobe/columns.rb`:
```ruby
module Skrine
  module Wardrobe
    module Columns
      def build_columns; end
    end
  end
end
```
`src/skrine/wardrobe/fronts.rb`, `drawers.rb`, `extras.rb` rovnako s modulmi `Fronts`, `Drawers`, `Extras` (Extras s prázdnym `def build_extras; end`, Fronts a Drawers zatiaľ bez metód).

Do `src/skrine/core.rb` pridaj: `require_relative 'wardrobe/model'`

- [ ] **Step 4: Spusti testy** – PASS (columns zatiaľ nič negenerujú, testy tejto úlohy to nevyžadujú).

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(wardrobe): model frame, corpus panels, base, strips, fillers and back panel"
```

---

### Task 6: Stĺpce, polia, priečky, police, tyče

**Files:**
- Modify: `src/skrine/wardrobe/columns.rb`
- Test: `test/wardrobe/columns_test.rb`

**Interfaces:**
- Consumes: `Core::Sizing`, `@f`, `edges_for`, `column_doors`, `column_handle`, `drilling_spec` z Task 5.
- Produces: `Columns::Column` (Struct: `index x0 w left_boundary right_boundary params doors handle cells`), `Columns::Cell` (Struct: `index z0 h top_boundary bottom_boundary params`); `build_columns` volá pre každý stĺpec `build_cells`, `build_partition`, potom `build_doors(col)` (Task 7); `build_cell_content` volá `build_drawers(col, cell, inner:)` (Task 8). Boundaries: `:side | :partition` horizontálne, `:panel | :shelf` vertikálne. `layout.info[:columns]`.

- [ ] **Step 1: Failing test**

`test/wardrobe/columns_test.rb`:
```ruby
require 'test_helper'

class ColumnsTest < Minitest::Test
  def test_two_auto_columns_share_inner_width
    l = wardrobe
    cols = l.info[:columns]
    assert_equal 2, cols.size
    assert_in_delta 973, cols[0][:inner_w]     # (1964 - 18) / 2
    assert_box l.find('Priečka 1'), x: 991, y: 18, z: 118, dx: 18, dy: 567, dz: 2264
    assert_equal :partition, l.find('Priečka 1').category
  end

  def test_cells_are_laid_out_top_down_with_fixed_shelf
    l = wardrobe
    cells = l.info[:columns][0][:cells]
    assert_in_delta 1646, cells[0][:inner_h]    # 2264 - 18 shelf - 600
    assert_in_delta 600, cells[1][:inner_h]
    assert_box l.find('Polica pevná S1/1'), x: 18, y: 20, z: 718, dx: 973, dy: 565, dz: 18
    assert_equal 973, l.find('Polica pevná S1/1').length
    assert_equal 565, l.find('Polica pevná S1/1').width
  end

  def test_adjustable_shelves_are_spread_evenly_with_supports
    l = wardrobe
    first = l.find('Polica S2/P1-1')
    assert_box first, x: 1009, y: 20, z: 1050.8, dx: 973, dy: 565, dz: 18, delta: 0.05
    assert first.meta[:adjustable]
    supports = l.hardware.select { |h| h.kind == :shelf_support }
    assert_equal 16, supports.sum(&:qty)
  end

  def test_rod_is_hardware_with_box
    l = wardrobe
    rod = l.hardware.find { |h| h.kind == :rod }
    assert_in_delta 973, rod.meta[:length]
    assert_in_delta 2292, rod.box.z
    assert_in_delta 286.5, rod.box.y
  end

  def test_mm_and_ratio_columns
    cols = [
      { width_mode: :mm, width: 400, cells: [{ content: :shelves, shelves_count: 1 }] },
      { width_mode: :ratio, width: 1, cells: [{ content: :empty }] },
      { width_mode: :ratio, width: 2, cells: [{ content: :empty }] }
    ]
    l = wardrobe(columns: cols)
    assert l.valid?, l.errors.join('; ')
    w = l.info[:columns].map { |c| c[:inner_w] }
    assert_in_delta 400, w[0]
    assert_in_delta (1964 - 36 - 400) / 3.0, w[1], 0.05
    assert_in_delta (1964 - 36 - 400) * 2 / 3.0, w[2], 0.05
  end

  def test_fixed_widths_overflow_is_error
    cols = [{ width_mode: :mm, width: 1500, cells: [{}] }, { width_mode: :mm, width: 1500, cells: [{}] }]
    l = wardrobe(columns: cols)
    refute l.valid?
    assert l.errors.first.include?('presahujú')
  end

  def test_too_many_shelves_is_error
    cols = [{ cells: [{ height_mode: :mm, height: 100, content: :shelves, shelves_count: 5 }, { content: :empty }] }]
    l = wardrobe(columns: cols)
    refute l.valid?
    assert l.errors.any? { |e| e.include?('políc') }
  end

  def test_line_drilling_is_recorded_on_sides_and_partitions
    l = wardrobe(line_drilling: true)
    assert_equal 32, l.find('Bok Ľ').meta[:drilling][:pitch]
    assert_equal 32, l.find('Priečka 1').meta[:drilling][:pitch]
    assert_nil l.find('Strop').meta[:drilling]
  end
end
```

- [ ] **Step 2: Spusti – zlyhá** (chýbajú `info[:columns]`, `Priečka 1`).

- [ ] **Step 3: Implementácia** – nahraď obsah `src/skrine/wardrobe/columns.rb`:

```ruby
module Skrine
  module Wardrobe
    # Columns (vertical modules) and their cells (horizontal modules).
    module Columns
      Column = Struct.new(:index, :x0, :w, :left_boundary, :right_boundary, :params, :doors, :handle, :cells,
                          keyword_init: true)
      Cell = Struct.new(:index, :z0, :h, :top_boundary, :bottom_boundary, :params, keyword_init: true)

      def build_columns
        cols = p[:columns]
        return layout.error('Skriňa musí mať aspoň jeden stĺpec') if cols.empty?

        tp = p[:partition_thickness]
        widths = Core::Sizing.resolve(cols.map { |c| { mode: c[:width_mode], value: c[:width] } },
                                      f[:inner_w] - (cols.size - 1) * tp)
        layout.info[:columns] = []
        Core::Sizing.positions(widths, tp, f[:inner_x0]).each_with_index do |(x0, w), i|
          col = Column.new(index: i + 1, x0: x0, w: w,
                           left_boundary: i.zero? ? :side : :partition,
                           right_boundary: i == cols.size - 1 ? :side : :partition,
                           params: cols[i], doors: column_doors(cols[i]), handle: column_handle(cols[i]), cells: [])
          layout.error("Stĺpec #{col.index}: šírka #{w.round(1)} mm je príliš malá") if w < 50
          build_cells(col)
          build_partition(col) if i < cols.size - 1
          build_doors(col)
          layout.info[:columns] << {
            index: col.index, inner_w: w.round(1),
            cells: col.cells.map { |c| { index: c.index, inner_h: c.h.round(1), content: c.params[:content] } }
          }
        end
      end

      def build_partition(col)
        tp = p[:partition_thickness]
        dy = f[:inner_d]
        part = layout.part(
          name: "Priečka #{col.index}", category: :partition, material: :corpus,
          length: f[:inner_h], width: dy, thickness: tp, edges: edges_for(p[:edge_shelf], :long_a),
          box: Core::Box.new(x: col.x0 + col.w, y: f[:corpus_y0], z: f[:inner_z0], dx: tp, dy: dy, dz: f[:inner_h]),
          meta: { column: col.index }
        )
        part.meta[:drilling] = drilling_spec if p[:line_drilling]
        part
      end

      def build_cells(col)
        cells = col.params[:cells]
        return layout.error("Stĺpec #{col.index}: musí mať aspoň jedno pole") if cells.empty?

        ts = p[:shelf_thickness]
        heights = Core::Sizing.resolve(cells.map { |c| { mode: c[:height_mode], value: c[:height] } },
                                       f[:inner_h] - (cells.size - 1) * ts)
        z1 = f[:inner_z0] + f[:inner_h]
        cells.each_with_index do |cp, i|
          h = heights[i]
          cell = Cell.new(index: i + 1, z0: z1 - h, h: h,
                          top_boundary: i.zero? ? :panel : :shelf,
                          bottom_boundary: i == cells.size - 1 ? :panel : :shelf, params: cp)
          col.cells << cell
          build_cell_content(col, cell)
          shelf_part(col, cell.z0 - ts, "Polica pevná S#{col.index}/#{cell.index}") unless i == cells.size - 1
          z1 = cell.z0 - ts
        end
      end

      def shelf_part(col, z, name, adjustable: false)
        y = f[:corpus_y0] + p[:shelf_setback]
        dy = f[:inner_d] - p[:shelf_setback] - p[:shelf_back_clearance]
        layout.part(
          name: name, category: :shelf, material: :corpus, length: col.w, width: dy, thickness: p[:shelf_thickness],
          edges: edges_for(p[:edge_shelf], :long_a),
          box: Core::Box.new(x: col.x0, y: y, z: z, dx: col.w, dy: dy, dz: p[:shelf_thickness]),
          meta: { column: col.index, adjustable: adjustable }
        )
      end

      def build_cell_content(col, cell)
        case cell.params[:content]
        when :shelves then build_adjustable_shelves(col, cell)
        when :rod then build_rod(col, cell)
        when :drawers then build_drawers(col, cell, inner: false)
        when :inner_drawers then build_drawers(col, cell, inner: true)
        end
      end

      def build_adjustable_shelves(col, cell)
        n = cell.params[:shelves_count]
        return if n <= 0

        ts = p[:shelf_thickness]
        gap = (cell.h - n * ts) / (n + 1)
        return layout.error("S#{col.index}/P#{cell.index}: #{n} políc sa nezmestí do #{cell.h.round} mm") if gap < 20

        n.times do |k|
          shelf_part(col, cell.z0 + gap * (k + 1) + ts * k, "Polica S#{col.index}/P#{cell.index}-#{k + 1}", adjustable: true)
        end
        layout.hardware_item(kind: :shelf_support, name: 'Podpera police', qty: 4 * n, unit: :pcs)
      end

      def build_rod(col, cell)
        size = 30.0
        z = cell.z0 + cell.h - cell.params[:rod_offset_top] - size
        return layout.error("S#{col.index}/P#{cell.index}: šatníková tyč sa nezmestí do poľa") if z < cell.z0

        y = f[:corpus_y0] + f[:inner_d] / 2.0 - size / 2
        layout.hardware_item(
          kind: :rod, name: "Šatníková tyč #{col.w.round} mm", qty: 1, unit: :pcs,
          box: Core::Box.new(x: col.x0, y: y, z: z, dx: col.w, dy: size, dz: size),
          meta: { length: col.w.round(1), column: col.index, cell: cell.index }
        )
      end
    end
  end
end
```

Do `src/skrine/wardrobe/fronts.rb` a `drawers.rb` dočasne pridaj stub metódy, aby Task 6 prešiel samostatne (v Task 7/8 sa nahradia):
```ruby
def build_doors(_col); end            # fronts.rb
def build_drawers(_col, _cell, inner:); end   # drawers.rb
```

- [ ] **Step 4: Spusti testy** – PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(wardrobe): columns, cells, partitions, fixed/adjustable shelves and rods"
```

---

### Task 7: Dvere, uloženie čiel, úchytky, pánty, výklop, zobrazenie otvorených dverí

**Files:**
- Modify: `src/skrine/wardrobe/fronts.rb`
- Test: `test/wardrobe/fronts_test.rb`

**Interfaces:**
- Consumes: `Column`, `Cell` (Task 6), `@f`, `@p`.
- Produces: `front_rect(col, z0, z1, top_boundary, bottom_boundary, mount) -> Box`, `apply_handle(rect, handle, col) -> Box` (iba profil), `record_drilled_handle(handle, name)`, `hinge_count(height)`, `build_doors(col)`, `door_rotation(box, hinge) -> Hash|nil` (`{point: [x,y,z], axis: [..], angle: deg}`).

- [ ] **Step 1: Failing test**

`test/wardrobe/fronts_test.rb`:
```ruby
require 'test_helper'

class FrontsTest < Minitest::Test
  def test_double_overlay_doors_with_profile_handle
    l = wardrobe
    left = l.find('Dvere S1 Ľ')
    right = l.find('Dvere S1 P')
    # column 1: x0 18, w 973; overlap left side 18-2=16, partition 9-1.5=7.5 -> width 996.5, split (996.5-3)/2
    assert_box left, x: 2, y: 0, z: 728.5, dx: 496.75, dy: 18, dz: 1639.5
    assert_box right, x: 501.75, y: 0, z: 728.5, dx: 496.75, dy: 18, dz: 1639.5
    assert_equal 1639.5, left.length          # vertical grain
    assert_equal 496.75, left.width
    assert_equal '2D 2K', left.edge_code
    assert_equal :left, left.meta[:hinge]
    assert_nil left.rotation
  end

  def test_hinges_and_profile_hardware
    l = wardrobe
    hinges = l.hardware.select { |h| h.kind == :hinge }
    assert_equal 4, hinges.first.qty                       # 1639.5 mm -> 2100:4
    assert_equal 16, hinges.sum(&:qty)                     # 4 doors
    profile = l.hardware.select { |h| h.kind == :profile }
    assert_in_delta 996.5, profile.first.qty
    assert_equal :mm, profile.first.unit
  end

  def test_hinge_count_table
    m = Skrine::Wardrobe::Model.new(wardrobe_params)
    m.layout
    assert_equal 2, m.hinge_count(800)
    assert_equal 3, m.hinge_count(1600)
    assert_equal 5, m.hinge_count(2500)
  end

  def test_single_door_warns_when_too_wide
    l = wardrobe(doors: { type: :single_left, mount: :overlay })
    door = l.find('Dvere S1')
    assert_in_delta 996.5, door.box.dx
    assert l.warnings.any? { |w| w.include?('Dvere S1') && w.include?('600') }
  end

  def test_inset_doors_sit_inside_the_corpus
    l = wardrobe(doors: { type: :double, mount: :inset })
    assert_in_delta 0, l.find('Bok Ľ').box.y                 # fronts do not protrude
    door = l.find('Dvere S1 Ľ')
    # x: 18 + 1.5 ; total width 973 - 3 ; height 1646 - 3 - 30 profile ; y = inset_depth
    assert_box door, x: 19.5, y: 2, z: 737.5, dx: 483.5, dy: 18, dz: 1613
  end

  def test_half_overlay_on_outer_side
    l = wardrobe(doors: { type: :single_left, mount: :half_overlay })
    door = l.find('Dvere S1')
    assert_in_delta 18 - 9 + 1.5, door.box.x                 # side overlap t/2 - gap/2 = 7.5
    assert_in_delta 973 + 7.5 + 7.5, door.box.dx
  end

  def test_doors_disabled_gives_open_corpus_but_keeps_drawer_fronts
    l = wardrobe(doors_enabled: false)
    assert_nil l.find('Dvere S1 Ľ')
    assert l.parts.any? { |pt| pt.name.start_with?('Čelo Zásuvka S1') }
    assert_in_delta 18, l.find('Bok Ľ').box.y
  end

  def test_flap_door_uses_lift_hardware_and_top_hinge
    l = wardrobe(doors: { type: :flap_up, mount: :overlay })
    door = l.find('Dvere S1 výklop')
    assert_equal :top, door.meta[:hinge]
    assert l.hardware.any? { |h| h.kind == :lift }
    assert_empty l.warnings.select { |w| w.include?('Dvere S1') }
  end

  def test_open_display_adds_rotation
    l = wardrobe(door_display: :open, open_angle: 90)
    left = l.find('Dvere S1 Ľ')
    assert_equal [0, 0, 1], left.rotation[:axis]
    assert_equal(-90.0, left.rotation[:angle])
    assert_in_delta 2, left.rotation[:point][0]
    right = l.find('Dvere S1 P')
    assert_equal 90.0, right.rotation[:angle]
    assert_in_delta 998.5, right.rotation[:point][0]
  end

  def test_drawer_cell_splits_doors_into_runs
    cols = [{ cells: [{ content: :shelves }, { content: :drawers, height_mode: :mm, height: 400 }, { content: :shelves }] }]
    l = wardrobe(columns: cols, doors: { type: :single_left, mount: :overlay })
    assert l.find('Dvere S1/1')
    assert l.find('Dvere S1/2')
  end

  def test_drilled_handles_are_counted_per_door
    l = wardrobe(handle: { type: :drilled, hole_spacing: 128 })
    handles = l.hardware.select { |h| h.kind == :handle }
    assert_equal 4 + 6, handles.sum(&:qty)                   # 4 doors + 6 drawer fronts
    assert_empty l.hardware.select { |h| h.kind == :profile }
    assert_in_delta 1669.5, l.find('Dvere S1 Ľ').box.dz     # no profile reduction
  end

  def test_column_override_of_doors
    cols = wardrobe_params[:columns]
    cols[1] = cols[1].merge(doors_override: true, doors: { type: :none, mount: :overlay })
    l = wardrobe(columns: cols)
    assert l.find('Dvere S1 Ľ')
    assert_nil l.find('Dvere S2 Ľ')
  end
end
```

- [ ] **Step 2: Spusti – zlyhá.**

- [ ] **Step 3: Implementácia** – nahraď `src/skrine/wardrobe/fronts.rb`:

```ruby
module Skrine
  module Wardrobe
    # Door fronts: overlay geometry, handles, hinges, lifts and open display.
    module Fronts
      # Front rectangle for a column span [z0, z1] (cavity coordinates).
      def front_rect(col, z0, z1, top_boundary, bottom_boundary, mount)
        ol = overlap_h(col.left_boundary, :left, mount)
        orr = overlap_h(col.right_boundary, :right, mount)
        ot = overlap_v(top_boundary, :top, mount)
        ob = overlap_v(bottom_boundary, :bottom, mount)
        y = mount == :inset ? f[:corpus_y0] + p[:inset_depth] : f[:corpus_y0] - p[:front_thickness]
        Core::Box.new(x: col.x0 - ol, y: y, z: z0 - ob, dx: col.w + ol + orr, dy: p[:front_thickness],
                      dz: (z1 - z0) + ot + ob)
      end

      def overlap_h(boundary, side, mount)
        gh = p[:front_gap_h]
        return -gh / 2.0 if mount == :inset
        return p[:partition_thickness] / 2.0 - gh / 2.0 if boundary == :partition

        ts = side == :left ? p[:side_left][:thickness] : p[:side_right][:thickness]
        reveal = side == :left ? p[:reveal_left] : p[:reveal_right]
        mount == :overlay ? ts - reveal : ts / 2.0 - gh / 2.0
      end

      def overlap_v(boundary, side, mount)
        gv = p[:front_gap_v]
        return -gv / 2.0 if mount == :inset
        return p[:shelf_thickness] / 2.0 - gv / 2.0 if boundary == :shelf

        side == :top ? p[:top][:thickness] - p[:reveal_top] : p[:bottom][:thickness] - p[:reveal_bottom]
      end

      def build_doors(col)
        return unless p[:doors_enabled]

        d = col.doors
        return if d[:type] == :none

        runs = door_runs(col)
        runs.each_with_index do |run, ri|
          rect = front_rect(col, run.last.z0, run.first.z0 + run.first.h, run.first.top_boundary,
                            run.last.bottom_boundary, d[:mount])
          rect = apply_handle(rect, col.handle, col)
          prefix = "Dvere S#{col.index}#{runs.size > 1 ? "/#{ri + 1}" : ''}"
          case d[:type]
          when :single_left then add_door(rect, prefix, :left, col)
          when :single_right then add_door(rect, prefix, :right, col)
          when :double
            w = (rect.dx - p[:front_gap_h]) / 2.0
            add_door(Core::Box.new(x: rect.x, y: rect.y, z: rect.z, dx: w, dy: rect.dy, dz: rect.dz), "#{prefix} Ľ", :left, col)
            add_door(Core::Box.new(x: rect.x + w + p[:front_gap_h], y: rect.y, z: rect.z, dx: w, dy: rect.dy, dz: rect.dz),
                     "#{prefix} P", :right, col)
          when :flap_up then add_door(rect, "#{prefix} výklop", :top, col)
          end
        end
      end

      # Contiguous top-down runs of cells that are not external drawers.
      def door_runs(col)
        runs = []
        current = []
        col.cells.each do |cell|
          if cell.params[:content] == :drawers
            runs << current unless current.empty?
            current = []
          else
            current << cell
          end
        end
        runs << current unless current.empty?
        runs
      end

      def add_door(box, name, hinge, col)
        if hinge != :top && box.dx > p[:door_max_width]
          layout.warn("#{name}: šírka krídla #{box.dx.round} mm presahuje odporúčaných #{p[:door_max_width].round} mm")
        end
        vertical = p[:front_grain] == :vertical
        part = layout.part(
          name: name, category: :front, material: :front,
          length: vertical ? box.dz : box.dx, width: vertical ? box.dx : box.dz, thickness: p[:front_thickness],
          edges: edges_for(p[:edge_front], :long_a), box: box, rotation: door_rotation(box, hinge),
          meta: { column: col.index, hinge: hinge }
        )
        if hinge == :top
          layout.hardware_item(kind: :lift, name: 'Výklop (napr. Blum AVENTOS)', qty: 1, unit: :pcs, meta: { door: name })
        else
          layout.hardware_item(kind: :hinge, name: 'Pánt', qty: hinge_count(box.dz), unit: :pcs, meta: { door: name, side: hinge })
        end
        record_drilled_handle(col.handle, name)
        part
      end

      def door_rotation(box, hinge)
        return nil unless p[:door_display] == :open && p[:open_angle].positive?

        a = p[:open_angle].to_f
        case hinge
        when :left then { point: [box.x, box.y2, box.z], axis: [0, 0, 1], angle: -a }
        when :right then { point: [box.x2, box.y2, box.z], axis: [0, 0, 1], angle: a }
        when :top then { point: [box.x, box.y2, box.z2], axis: [1, 0, 0], angle: -a }
        end
      end

      # "max_height:count,..." -> count for the first entry whose max_height >= height.
      def hinge_count(height)
        table = p[:hinge_table].to_s.split(',').map { |pair| pair.split(':').map(&:to_f) }
                 .select { |e| e.size == 2 }.sort_by(&:first)
        entry = table.find { |max_h, _| height <= max_h } || table.last
        entry ? entry[1].to_i : 2
      end

      # Shrinks +rect+ for an integrated profile handle and books the profile length.
      def apply_handle(rect, handle, col)
        return rect unless handle[:type] == :profile

        ph = handle[:profile_height].to_f
        layout.hardware_item(kind: :profile, name: 'Úchytkový profil', qty: rect.dx.round(1), unit: :mm, meta: { column: col.index })
        if handle[:profile_position] == :top
          Core::Box.new(x: rect.x, y: rect.y, z: rect.z, dx: rect.dx, dy: rect.dy, dz: rect.dz - ph)
        else
          Core::Box.new(x: rect.x, y: rect.y, z: rect.z + ph, dx: rect.dx, dy: rect.dy, dz: rect.dz - ph)
        end
      end

      def record_drilled_handle(handle, front_name)
        return unless handle[:type] == :drilled

        layout.hardware_item(kind: :handle, name: "Úchytka rozteč #{handle[:hole_spacing].round}", qty: 1, unit: :pcs,
                             meta: { front: front_name, offset_edge: handle[:offset_edge], orientation: handle[:orientation] })
      end
    end
  end
end
```

- [ ] **Step 4: Spusti testy** – PASS (test `test_drilled_handles_are_counted_per_door` a `doors_disabled…` závisia od Task 8; ak Task 8 ešte nie je, dočasne ich označ `skip 'Task 8'` a odstráň skip v Task 8).

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(wardrobe): doors with overlay/inset geometry, handles, hinges, flaps and open display"
```

---

### Task 8: Zásuvky – čelá, systémy (front_only / drevený box / Blum), výsuvy

**Files:**
- Modify: `src/skrine/wardrobe/drawers.rb`
- Test: `test/wardrobe/drawers_test.rb`

**Interfaces:**
- Consumes: `front_rect`, `apply_handle`, `record_drilled_handle` (Task 7), `Column`/`Cell` (Task 6), `p[:drawer_systems]`.
- Produces: `build_drawers(col, cell, inner:)`, `drawer_system -> Hash`, `nominal_length(sys) -> Float|nil`.

- [ ] **Step 1: Failing test**

`test/wardrobe/drawers_test.rb`:
```ruby
require 'test_helper'

class DrawersTest < Minitest::Test
  def test_three_drawer_fronts_fill_the_cell_with_gaps_and_profile
    l = wardrobe
    f1 = l.find('Čelo Zásuvka S1/P2-1')
    f2 = l.find('Čelo Zásuvka S1/P2-2')
    f3 = l.find('Čelo Zásuvka S1/P2-3')
    # rect: z 100 (bottom panel overlay 18), height 600 + 7.5 + 18 = 625.5 -> 3 x 206.5 with 3 mm gaps
    assert_box f1, x: 2, y: 0, z: 519, dx: 996.5, dy: 18, dz: 176.5
    assert_box f2, x: 2, y: 0, z: 309.5, dx: 996.5, dy: 18, dz: 176.5
    assert_box f3, x: 2, y: 0, z: 100, dx: 996.5, dy: 18, dz: 176.5
    assert_equal :front, f1.category
    assert_equal 176.5, f1.length
  end

  def test_legrabox_picks_class_and_nominal_length
    l = wardrobe
    bottom = l.find('Dno Zásuvka S1/P2-1')
    assert_equal 886, bottom.length            # 973 - 87
    assert_equal 488, bottom.width             # NL 500 - 12
    assert_equal 16, bottom.thickness
    assert_equal 'K', bottom.meta[:class]
    back = l.find('Zadný diel Zásuvka S1/P2-1')
    assert_equal 886, back.length
    assert_equal 128.5, back.width
    slides = l.hardware.select { |h| h.kind == :slide }
    assert_equal 6, slides.size
    assert_equal 'Blum LEGRABOX K NL500 (sada)', slides.first.name
    sides = l.hardware.select { |h| h.kind == :drawer_side }
    assert_equal 12, sides.size
    assert sides.all?(&:box)
  end

  def test_wood_box_parts
    l = wardrobe(drawer_system: :wood_box)
    side = l.find('Box bok Ľ Zásuvka S1/P2-1')
    assert_equal 500, side.length
    assert_equal 151.5, side.width             # 176.5 - 25
    assert_equal 16, side.thickness
    back = l.find('Box zadný Zásuvka S1/P2-1')
    assert_equal 915, back.length              # 973 - 26 - 32
    bottom = l.find('Box dno Zásuvka S1/P2-1')
    assert_equal 480, bottom.length            # 500 - 32 + 12
    assert_equal 927, bottom.width             # 915 + 12
    assert_equal 3, bottom.thickness
    assert_equal :back, bottom.material
    assert l.hardware.any? { |h| h.kind == :slide && h.name.include?('NL500') }
  end

  def test_front_only_has_no_box_parts
    l = wardrobe(drawer_system: :front_only)
    assert_empty l.by_category(:drawer_box)
    assert_equal 6, l.hardware.count { |h| h.kind == :slide }
  end

  def test_custom_front_heights
    cols = wardrobe_params[:columns]
    cols[0][:cells][1] = cols[0][:cells][1].merge(drawer_heights: '250, 200, 169.5')
    l = wardrobe(columns: cols)
    assert l.valid?, l.errors.join('; ')
    assert_in_delta 250 - 30, l.find('Čelo Zásuvka S1/P2-1').box.dz
    assert_in_delta 169.5 - 30, l.find('Čelo Zásuvka S1/P2-3').box.dz
  end

  def test_custom_front_heights_mismatch_is_error
    cols = wardrobe_params[:columns]
    cols[0][:cells][1] = cols[0][:cells][1].merge(drawer_heights: '100,100,100')
    l = wardrobe(columns: cols)
    refute l.valid?
    assert l.errors.any? { |e| e.include?('S1/P2') }
  end

  def test_inner_drawers_sit_behind_doors_without_handles
    cols = [{ cells: [{ content: :inner_drawers, drawers_count: 2 }] }]
    l = wardrobe(columns: cols, doors: { type: :double, mount: :overlay })
    front = l.find('Čelo Vnút. zásuvka S1/P1-1')
    assert_in_delta 18 + 3, front.box.x
    assert_in_delta 18 + 30, front.box.y
    assert_in_delta 1964 - 6, front.box.dx
    assert l.find('Dvere S1 Ľ')
    assert_equal 1, l.hardware.count { |h| h.kind == :profile }   # only the doors
  end

  def test_too_shallow_for_any_runner_is_error
    l = wardrobe(depth: 250)
    refute l.valid?
    assert l.errors.any? { |e| e.include?('výsuv') }
  end

  def test_low_front_warns_about_class
    cols = [{ cells: [{ content: :drawers, height_mode: :mm, height: 40, drawers_count: 1 }, { content: :empty }] }]
    l = wardrobe(columns: cols, handle: { type: :none })
    assert l.warnings.any? { |w| w.include?('trieda') }
  end
end
```

- [ ] **Step 2: Spusti – zlyhá.**

- [ ] **Step 3: Implementácia** – nahraď `src/skrine/wardrobe/drawers.rb`:

```ruby
module Skrine
  module Wardrobe
    # Drawer fronts and boxes (front only / wooden box / metal systems such as Blum).
    module Drawers
      METAL_SIDE_THICKNESS = 13.0

      def build_drawers(col, cell, inner:)
        cp = cell.params
        n = cp[:drawers_count]
        if inner
          g = p[:inner_drawer_side_gap]
          rect = Core::Box.new(x: col.x0 + g, y: f[:corpus_y0] + p[:inner_drawer_setback], z: cell.z0,
                               dx: col.w - 2 * g, dy: p[:front_thickness], dz: cell.h)
        else
          rect = front_rect(col, cell.z0, cell.z0 + cell.h, cell.top_boundary, cell.bottom_boundary, col.doors[:mount])
        end
        gv = p[:front_gap_v]
        heights = drawer_front_heights(cp, n, rect.dz, gv, col, cell)
        return unless heights

        z_top = rect.z2
        heights.each_with_index do |h, k|
          fbox = Core::Box.new(x: rect.x, y: rect.y, z: z_top - h, dx: rect.dx, dy: rect.dy, dz: h)
          name = "#{inner ? 'Vnút. zásuvka' : 'Zásuvka'} S#{col.index}/P#{cell.index}-#{k + 1}"
          unless inner
            fbox = apply_handle(fbox, col.handle, col)
            record_drilled_handle(col.handle, "Čelo #{name}")
          end
          add_drawer_front(fbox, name, col)
          build_drawer_box(col, cell, fbox, name)
          z_top -= h + gv
        end
      end

      def drawer_front_heights(cp, n, span, gv, col, cell)
        custom = cp[:drawer_heights].to_s.split(',').map(&:strip).reject(&:empty?).map(&:to_f)
        if custom.empty?
          h = (span - (n - 1) * gv) / n
          return layout.error("S#{col.index}/P#{cell.index}: čelá zásuviek by mali len #{h.round} mm") if h < 40

          return Array.new(n, h)
        end
        return layout.error("S#{col.index}/P#{cell.index}: zadaných #{custom.size} výšok, zásuviek je #{n}") if custom.size != n

        total = custom.sum + (n - 1) * gv
        if (total - span).abs > 0.5
          return layout.error("S#{col.index}/P#{cell.index}: súčet výšok čiel + špár je #{total.round(1)} mm, k dispozícii je #{span.round(1)} mm")
        end

        custom
      end

      def add_drawer_front(box, name, col)
        vertical = p[:front_grain] == :vertical
        layout.part(
          name: "Čelo #{name}", category: :front, material: :front,
          length: vertical ? box.dz : box.dx, width: vertical ? box.dx : box.dz, thickness: p[:front_thickness],
          edges: edges_for(p[:edge_front], :long_a), box: box, meta: { column: col.index }
        )
      end

      def drawer_system
        key = p[:drawer_system]
        { key: key }.merge(p[:drawer_systems][key])
      end

      # Largest nominal runner length that fits the usable depth, or nil.
      def nominal_length(sys)
        lengths = sys[:lengths].to_s.split(',').map(&:to_f).select(&:positive?)
        avail = f[:inner_d] - p[:drawer_depth_reserve]
        lengths.select { |l| l <= avail }.max
      end

      def build_drawer_box(col, cell, fbox, name)
        sys = drawer_system
        nl = nominal_length(sys)
        return layout.error("#{name}: žiadna nominálna dĺžka výsuvu (#{sys[:lengths]}) sa nezmestí do hĺbky #{f[:inner_d].round} mm") unless nl

        y0 = fbox.y2 + 2
        z0 = [fbox.z, cell.z0].max + 12
        case sys[:box]
        when :wood then build_wood_box(col, fbox, name, sys, nl, y0, z0)
        when :metal then build_metal_box(col, fbox, name, sys, nl, y0, z0)
        else
          layout.hardware_item(kind: :slide, name: "Výsuv #{sys[:label]} NL#{nl.round}", qty: 1, unit: :pair, meta: { drawer: name })
        end
      end

      def build_wood_box(col, fbox, name, sys, nl, y0, z0)
        t = p[:drawer_box_thickness]
        tb = p[:drawer_bottom_thickness]
        gr = p[:drawer_bottom_groove]
        outer_w = col.w - 2 * sys[:side_clearance]
        h = fbox.dz - sys[:height_clearance]
        return layout.error("#{name}: drevený box by mal výšku len #{h.round} mm") if h < 40

        edges = edges_for(p[:edge_drawer_box], :long_a)
        x0 = col.x0 + sys[:side_clearance]
        [[x0, 'Ľ'], [x0 + outer_w - t, 'P']].each do |x, s|
          layout.part(name: "Box bok #{s} #{name}", category: :drawer_box, material: :drawer_box, length: nl, width: h,
                      thickness: t, edges: edges, box: Core::Box.new(x: x, y: y0, z: z0, dx: t, dy: nl, dz: h), meta: { drawer: name })
        end
        inner_w = outer_w - 2 * t
        layout.part(name: "Box zadný #{name}", category: :drawer_box, material: :drawer_box, length: inner_w, width: h, thickness: t,
                    edges: edges, box: Core::Box.new(x: x0 + t, y: y0 + nl - t, z: z0, dx: inner_w, dy: t, dz: h), meta: { drawer: name })
        layout.part(name: "Box predný #{name}", category: :drawer_box, material: :drawer_box, length: inner_w, width: h, thickness: t,
                    edges: edges, box: Core::Box.new(x: x0 + t, y: y0, z: z0, dx: inner_w, dy: t, dz: h), meta: { drawer: name })
        bw = inner_w + 2 * gr
        bl = nl - 2 * t + 2 * gr
        layout.part(name: "Box dno #{name}", category: :drawer_box, material: :back, length: bl, width: bw, thickness: tb,
                    edges: edges_for(:none), grain: :none,
                    box: Core::Box.new(x: x0 + t - gr, y: y0 + t - gr, z: z0 + 10, dx: bw, dy: bl, dz: tb), meta: { drawer: name })
        layout.hardware_item(kind: :slide, name: "Výsuv drevený box NL#{nl.round}", qty: 1, unit: :pair, meta: { drawer: name })
      end

      def build_metal_box(col, fbox, name, sys, nl, y0, z0)
        classes = sys[:heights].to_s.split(',').map { |s| k, v = s.split(':'); [k.to_s.strip, v.to_f] }
                     .select { |_, v| v.positive? }.sort_by(&:last)
        return layout.error("#{name}: systém #{sys[:label]} nemá výškové triedy") if classes.empty?

        usable = classes.select { |_, hgt| hgt + sys[:front_min_extra] <= fbox.dz }
        cls, ch = usable.last || classes.first
        layout.warn("#{name}: čelo #{fbox.dz.round} mm je nižšie než najnižšia trieda #{cls} (#{ch} mm)") if usable.empty?

        tb = p[:metal_box_bottom_thickness]
        tback = p[:drawer_box_thickness]
        bw = col.w - sys[:bottom_width_deduction]
        bl = nl - sys[:bottom_length_deduction]
        layout.part(name: "Dno #{name}", category: :drawer_box, material: :drawer_box, length: bw, width: bl, thickness: tb,
                    edges: edges_for(:none), box: Core::Box.new(x: col.x0 + (col.w - bw) / 2, y: y0, z: z0, dx: bw, dy: bl, dz: tb),
                    meta: { drawer: name, system: sys[:label], class: cls })
        back_w = col.w - sys[:back_width_deduction]
        back_h = ch - sys[:back_height_deduction]
        layout.part(name: "Zadný diel #{name}", category: :drawer_box, material: :drawer_box, length: back_w, width: back_h,
                    thickness: tback, edges: edges_for(:none),
                    box: Core::Box.new(x: col.x0 + (col.w - back_w) / 2, y: y0 + bl - tback, z: z0 + tb, dx: back_w, dy: tback, dz: back_h),
                    meta: { drawer: name, system: sys[:label], class: cls })
        [col.x0 + sys[:side_clearance], col.x0 + col.w - sys[:side_clearance] - METAL_SIDE_THICKNESS].each do |x|
          layout.hardware_item(kind: :drawer_side, name: "#{sys[:label]} #{cls} bok", qty: 1, unit: :pcs,
                               box: Core::Box.new(x: x, y: y0, z: z0, dx: METAL_SIDE_THICKNESS, dy: nl, dz: ch), meta: { drawer: name })
        end
        layout.hardware_item(kind: :slide, name: "#{sys[:label]} #{cls} NL#{nl.round} (sada)", qty: 1, unit: :set, meta: { drawer: name })
      end
    end
  end
end
```

- [ ] **Step 4: Spusti testy** – PASS (odstráň prípadné `skip` z Task 7).

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(wardrobe): drawer fronts, wooden and metal (Blum) boxes, runner selection"
```

---

### Task 9: Spojovací materiál, závesy, presety a validácia presetov

**Files:**
- Modify: `src/skrine/wardrobe/extras.rb`
- Create: `presets/satnik-2-stlpce.json`, `presets/regal-otvoreny.json`, `presets/horna-skrinka-vyklop.json`
- Test: `test/wardrobe/extras_test.rb`, `test/presets_test.rb`

**Interfaces:**
- Produces: `build_extras` (joinery + brackets). Presety = JSON s **čiastočnými** parametrami (merge_defaults doplní zvyšok).

- [ ] **Step 1: Failing testy**

`test/wardrobe/extras_test.rb`:
```ruby
require 'test_helper'

class ExtrasTest < Minitest::Test
  def test_confirmat_count_from_fixed_joints
    l = wardrobe
    j = l.hardware.find { |h| h.kind == :joinery }
    # top+bottom: 2 panels x 2 joints x 2 = 8 ; partition: 2 joints x 2 = 4 ; 2 fixed shelves x 2 joints x 2 = 8
    assert_equal 'Konfirmát', j.name
    assert_equal 20, j.qty
  end

  def test_joinery_none_and_brackets
    l = wardrobe(joinery: :none, wall_brackets: 2)
    assert_nil l.hardware.find { |h| h.kind == :joinery }
    assert_equal 2, l.hardware.find { |h| h.kind == :bracket }.qty
  end

  def test_pitch_increases_count_for_long_joints
    l = wardrobe(joinery: :dowels, joinery_pitch: 150)
    j = l.hardware.find { |h| h.kind == :joinery }
    assert_equal 'Kolík', j.name
    assert_equal 4 * 4 + 4 * 2 + 4 * 4, j.qty     # 582 -> 4, 567 -> 4, 565 -> 4 per joint
  end
end
```

`test/presets_test.rb`:
```ruby
require 'test_helper'

class PresetsTest < Minitest::Test
  PRESETS = Dir[File.expand_path('../presets/*.json', __dir__)]

  def test_presets_exist
    assert_operator PRESETS.size, :>=, 3
  end

  def test_each_preset_builds_a_valid_layout
    PRESETS.each do |file|
      params = JSON.parse(File.read(file))
      l = Skrine::Wardrobe::Model.new(params).layout
      assert l.valid?, "#{File.basename(file)}: #{l.errors.join('; ')}"
      assert_operator l.parts.size, :>, 4, File.basename(file)
    end
  end
end
```

- [ ] **Step 2: Spusti – zlyhá.**

- [ ] **Step 3: Implementácia**

`src/skrine/wardrobe/extras.rb`:
```ruby
module Skrine
  module Wardrobe
    # Joinery and mounting hardware derived from the generated parts.
    module Extras
      JOINERY_LABELS = { dowels: 'Kolík', confirmat: 'Konfirmát', cam_lock: 'Excenter' }.freeze

      def build_extras
        build_joinery
        if p[:wall_brackets].positive?
          layout.hardware_item(kind: :bracket, name: 'Závesné kovanie', qty: p[:wall_brackets], unit: :pcs)
        end
      end

      def build_joinery
        return if p[:joinery] == :none

        count = 0
        layout.parts.each do |part|
          case part.category
          when :corpus then count += 2 * per_joint(part.width) if %w[Strop Dno].include?(part.name)
          when :partition then count += 2 * per_joint(part.width)
          when :shelf then count += 2 * per_joint(part.width) unless part.meta[:adjustable]
          end
        end
        layout.hardware_item(kind: :joinery, name: JOINERY_LABELS[p[:joinery]], qty: count, unit: :pcs)
      end

      def per_joint(length)
        [2, (length / p[:joinery_pitch]).ceil].max
      end
    end
  end
end
```

`presets/satnik-2-stlpce.json`:
```json
{
  "width": 2000, "height": 2400, "depth": 600,
  "base_type": "legs", "base_height": 100,
  "doors": { "type": "double", "mount": "overlay" },
  "handle": { "type": "profile", "profile_height": 30, "profile_position": "top" },
  "drawer_system": "blum_legrabox",
  "columns": [
    { "cells": [ { "content": "rod" }, { "content": "drawers", "height_mode": "mm", "height": 600, "drawers_count": 3 } ] },
    { "cells": [ { "content": "shelves", "shelves_count": 4 }, { "content": "drawers", "height_mode": "mm", "height": 600, "drawers_count": 3 } ] }
  ]
}
```

`presets/regal-otvoreny.json`:
```json
{
  "width": 1200, "height": 2000, "depth": 350,
  "base_type": "floor", "bottom_strip": false,
  "doors_enabled": false,
  "back_mode": "inset",
  "columns": [
    { "cells": [ { "content": "shelves", "shelves_count": 5 } ] },
    { "cells": [ { "content": "shelves", "shelves_count": 5 } ] },
    { "cells": [ { "content": "shelves", "shelves_count": 5 } ] }
  ]
}
```

`presets/horna-skrinka-vyklop.json`:
```json
{
  "width": 1200, "height": 500, "depth": 350,
  "base_type": "floor", "bottom_strip": false,
  "doors": { "type": "flap_up", "mount": "overlay" },
  "handle": { "type": "none" },
  "wall_brackets": 2,
  "columns": [ { "cells": [ { "content": "shelves", "shelves_count": 1 } ] } ]
}
```

- [ ] **Step 4: Spusti testy** – PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(wardrobe): joinery and bracket hardware, sample presets with validation test"
```

---

### Task 10: Nárezový plán (čistý Ruby) – zlučovanie, CSV, CutList Optimizer, HTML

**Files:**
- Create: `src/skrine/export/cutlist.rb`
- Modify: `src/skrine/core.rb`
- Test: `test/export/cutlist_test.rb`

**Interfaces:**
- Produces: `Skrine::Export::Cutlist.new(parts, hardware, materials: {})` s metódami `rows -> [Row]` (`Row`: `material material_label thickness name qty length width edge_code edges grain category`), `by_material -> {label => [Row]}`, `edge_meters -> {label => Float}`, `area_m2 -> {label => Float}`, `hardware_rows -> [HwRow(kind name qty unit)]`, `to_csv -> String`, `to_optimizer_csv -> String`, `to_html -> String`. `materials` = `params[:materials]` (`{corpus: {name:, color:}, ...}`).

- [ ] **Step 1: Failing test**

`test/export/cutlist_test.rb`:
```ruby
require 'test_helper'

class CutlistTest < Minitest::Test
  def cutlist(**over)
    params = wardrobe_params(**over)
    l = Skrine::Wardrobe::Model.new(params).layout
    assert l.valid?, l.errors.join('; ')
    Skrine::Export::Cutlist.new(l.parts, l.hardware, materials: params[:materials])
  end

  def test_identical_parts_are_merged_with_material_labels
    c = cutlist
    sides = c.rows.find { |r| r.name.start_with?('Bok') }
    assert_equal 2, sides.qty
    assert_equal 'Bok Ľ (+1)', sides.name
    assert_equal 'DTD 18 biela', sides.material_label
    assert_equal 18, sides.thickness
    doors = c.rows.find { |r| r.name.start_with?('Dvere') }
    assert_equal 4, doors.qty
    assert_equal 'DTD 18 dekor', doors.material_label
  end

  def test_by_material_groups_and_sorts_by_area
    groups = cutlist.by_material
    assert_includes groups.keys, 'DTD 18 biela 18 mm'
    assert_includes groups.keys, 'HDF 3 biela 3 mm'
    rows = groups['DTD 18 biela 18 mm']
    assert_equal 'Bok Ľ (+1)', rows.first.name          # largest area first
  end

  def test_edge_meters_and_area
    c = cutlist
    edges = c.edge_meters
    assert_operator edges['DTD 18 dekor 18 mm'], :>, 20      # fronts banded on 4 edges
    assert_operator c.area_m2['DTD 18 biela 18 mm'], :>, 5
  end

  def test_hardware_rows_merge_and_skip_draw_only
    hw = cutlist.hardware_rows
    slides = hw.find { |r| r.kind == :slide }
    assert_equal 6, slides.qty
    assert_nil hw.find { |r| r.kind == :drawer_side }
    legs = hw.find { |r| r.kind == :leg }
    assert_equal 6, legs.qty
    profile = hw.find { |r| r.kind == :profile }
    assert_equal :mm, profile.unit
  end

  def test_csv_has_header_and_semicolons
    csv = cutlist.to_csv
    lines = csv.lines
    assert lines.first.start_with?("﻿Materiál;Hrúbka;Názov;Ks;Dĺžka;Šírka;Hrany;Dekor")
    assert lines.any? { |l| l.include?('Bok Ľ (+1);2;2300;582;1D;') }
  end

  def test_optimizer_csv_format
    csv = cutlist.to_optimizer_csv
    assert_equal 'Length;Width;Qty;Label;Enabled;Grain', csv.lines.first.strip
    assert csv.lines.any? { |l| l.start_with?('2300;582;2;Bok') }
  end

  def test_html_contains_sections
    html = cutlist.to_html
    assert_includes html, '<h2>DTD 18 biela 18 mm</h2>'
    assert_includes html, 'Kovanie'
    assert_includes html, 'Hranovanie'
  end
end
```

- [ ] **Step 2: Spusti – zlyhá.**

- [ ] **Step 3: Implementácia**

`src/skrine/export/cutlist.rb`:
```ruby
require 'cgi'

module Skrine
  module Export
    # Cut list and hardware summary built from parts/hardware (pure Ruby).
    class Cutlist
      DRAW_ONLY = %i[drawer_side].freeze
      CSV_SEP = ';'

      Row = Struct.new(:material, :material_label, :thickness, :name, :qty, :length, :width, :edge_code, :edges,
                       :grain, :category, keyword_init: true)
      HwRow = Struct.new(:kind, :name, :qty, :unit, keyword_init: true)

      def initialize(parts, hardware, materials: {})
        @parts = parts
        @hardware = hardware
        @materials = materials || {}
      end

      def rows
        @rows ||= @parts
                  .group_by { |pt| [pt.material.to_s, pt.thickness.round(1), pt.length.round(1), pt.width.round(1), pt.edge_code, pt.grain.to_s] }
                  .map do |(mat, t, l, w, code, grain), pts|
                    names = pts.map(&:name).uniq
                    Row.new(material: mat, material_label: label_for(mat), thickness: t,
                            name: names.size == 1 ? names.first : "#{names.first} (+#{names.size - 1})",
                            qty: pts.size, length: l, width: w, edge_code: code, edges: pts.first.edges,
                            grain: grain, category: pts.first.category)
                  end
                  .sort_by { |r| [r.material_label, r.thickness, -(r.length * r.width), r.name] }
      end

      def group_label(row)
        "#{row.material_label} #{fmt(row.thickness)} mm"
      end

      def by_material
        rows.group_by { |r| group_label(r) }
      end

      def edge_meters
        rows.each_with_object(Hash.new(0.0)) do |r, h|
          e = r.edges
          len = (e[:long_a] ? r.length : 0) + (e[:long_b] ? r.length : 0) + (e[:short_a] ? r.width : 0) + (e[:short_b] ? r.width : 0)
          h[group_label(r)] += len * r.qty / 1000.0
        end
      end

      def area_m2
        rows.each_with_object(Hash.new(0.0)) { |r, h| h[group_label(r)] += r.length * r.width * r.qty / 1_000_000.0 }
      end

      def hardware_rows
        @hardware.reject { |h| DRAW_ONLY.include?(h.kind) }
                 .group_by { |h| [h.kind, h.name, h.unit] }
                 .map { |(kind, name, unit), items| HwRow.new(kind: kind, name: name, qty: items.sum(&:qty), unit: unit) }
                 .sort_by { |r| [r.kind.to_s, r.name] }
      end

      def to_csv
        out = +"﻿"
        out << %w[Materiál Hrúbka Názov Ks Dĺžka Šírka Hrany Dekor].join(CSV_SEP) << "\n"
        rows.each do |r|
          out << [r.material_label, fmt(r.thickness), r.name, r.qty, fmt(r.length), fmt(r.width), r.edge_code,
                  r.grain == 'none' ? 'nie' : 'áno'].join(CSV_SEP) << "\n"
        end
        out << "\n" << %w[Kovanie Názov Množstvo Jednotka].join(CSV_SEP) << "\n"
        hardware_rows.each { |h| out << [h.kind, h.name, fmt(h.qty), unit_label(h.unit)].join(CSV_SEP) << "\n" }
        out
      end

      # Format understood by CutList Optimizer (cutlistoptimizer.com) CSV import.
      def to_optimizer_csv
        out = +"Length;Width;Qty;Label;Enabled;Grain\n"
        rows.each do |r|
          out << [fmt(r.length), fmt(r.width), r.qty, "#{r.name} [#{r.material_label} #{fmt(r.thickness)}]", 'true',
                  r.grain == 'none' ? 'false' : 'true'].join(CSV_SEP) << "\n"
        end
        out
      end

      def to_html
        h = +'<!DOCTYPE html><html lang="sk"><head><meta charset="utf-8"><title>Nárezový plán</title>'
        h << '<style>body{font-family:-apple-system,Helvetica,Arial,sans-serif;font-size:13px;margin:20px}'
        h << 'table{border-collapse:collapse;margin-bottom:18px;width:100%}th,td{border:1px solid #ccc;padding:4px 8px;text-align:left}'
        h << 'th{background:#f0f0f0}td.n{text-align:right}h2{margin:18px 0 6px}@media print{button{display:none}}</style></head><body>'
        h << '<h1>Nárezový plán</h1>'
        by_material.each do |label, list|
          h << "<h2>#{esc(label)}</h2><table><tr><th>Názov</th><th>Ks</th><th>Dĺžka</th><th>Šírka</th><th>Hrany</th><th>Dekor</th></tr>"
          list.each do |r|
            h << "<tr><td>#{esc(r.name)}</td><td class=n>#{r.qty}</td><td class=n>#{fmt(r.length)}</td><td class=n>#{fmt(r.width)}</td>"
            h << "<td>#{r.edge_code}</td><td>#{r.grain == 'none' ? 'nie' : 'áno'}</td></tr>"
          end
          h << "<tr><th colspan=6>Plocha #{fmt(area_m2[label], 2)} m² · Hranovanie #{fmt(edge_meters[label], 1)} m</th></tr></table>"
        end
        h << '<h2>Hranovanie</h2><table><tr><th>Materiál</th><th>Metre</th></tr>'
        edge_meters.each { |label, m| h << "<tr><td>#{esc(label)}</td><td class=n>#{fmt(m, 1)}</td></tr>" }
        h << '</table><h2>Kovanie</h2><table><tr><th>Druh</th><th>Názov</th><th>Množstvo</th></tr>'
        hardware_rows.each { |r| h << "<tr><td>#{r.kind}</td><td>#{esc(r.name)}</td><td class=n>#{fmt(r.qty)} #{unit_label(r.unit)}</td></tr>" }
        h << '</table></body></html>'
        h
      end

      private

      def label_for(mat)
        name = @materials.dig(mat.to_sym, :name).to_s
        name.empty? ? mat.to_s : name
      end

      def unit_label(unit)
        { pcs: 'ks', pair: 'pár', set: 'sada', mm: 'mm' }[unit.to_sym] || unit.to_s
      end

      def fmt(num, decimals = 1)
        rounded = num.to_f.round(decimals)
        rounded == rounded.to_i ? rounded.to_i.to_s : rounded.to_s
      end

      def esc(s)
        CGI.escapeHTML(s.to_s)
      end
    end
  end
end
```

Do `src/skrine/core.rb` pridaj: `require_relative 'export/cutlist'`

- [ ] **Step 4: Spusti testy** – PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(export): cut list with material grouping, edge banding, hardware, CSV/optimizer/HTML output"
```

---

### Task 11: SketchUp vrstva – Units, Builder, Storage, Selection, Commands, smoke test

**Files:**
- Create: `src/skrine/sketchup/units.rb`, `src/skrine/sketchup/storage.rb`, `src/skrine/sketchup/builder.rb`, `src/skrine/sketchup/selection.rb`, `src/skrine/sketchup/commands.rb`, `scripts/smoke.rb`
- Modify: `src/skrine/loader.rb`

**Interfaces:**
- Consumes: `Core::Registry`, `Core::Layout`, `Part#to_attrs`, `HardwareItem#to_attrs`.
- Produces: `Skrine::SU::Units.mm(x) -> Float(in)`, `SU::Storage.write(group, type_key, params, hardware:)`, `Storage.read(group) -> {type:, params:}|nil`, `Storage.hardware(group) -> [HardwareItem]`, `Storage.wardrobe?(entity)`, `SU::Builder.create(model, type_key, params) -> {group:, errors:, warnings:, info:}`, `Builder.rebuild(group, params) -> {errors:, warnings:, info:}`, `SU::Selection.current_object(model) -> Group|nil`, `SU::Commands.new_object(type_key)`, `Commands.edit_selected`.
- Tento task sa testuje **manuálne v SketchUpe** (Ruby Console), nie minitestom.

- [ ] **Step 1: Implementácia**

`src/skrine/sketchup/units.rb`:
```ruby
module Skrine
  module SU
    module Units
      MM_PER_INCH = 25.4

      # Millimetres -> SketchUp internal inches (Float).
      def self.mm(value)
        value.to_f / MM_PER_INCH
      end

      def self.point(x, y, z)
        Geom::Point3d.new(mm(x), mm(y), mm(z))
      end
    end
  end
end
```

`src/skrine/sketchup/storage.rb`:
```ruby
require 'json'

module Skrine
  module SU
    # Persists object type + params on the top-level group as attributes.
    module Storage
      DICT = 'Skrine'
      PART_DICT = 'Skrine::Part'
      HW_DICT = 'Skrine::Hardware'
      VERSION = 1

      # +hardware+ (Core::HardwareItem list) is stored too, because most fittings
      # (hinges, runners, joinery) are not drawn and would otherwise be lost.
      def self.write(group, type_key, params, hardware: [])
        group.set_attribute(DICT, 'type', type_key.to_s)
        group.set_attribute(DICT, 'version', VERSION)
        group.set_attribute(DICT, 'params', JSON.generate(params))
        group.set_attribute(DICT, 'hardware', JSON.generate(hardware.map(&:to_attrs)))
      end

      def self.read(group)
        return nil unless wardrobe?(group)

        type = group.get_attribute(DICT, 'type')
        params = JSON.parse(group.get_attribute(DICT, 'params') || '{}')
        { type: type.to_sym, params: params }
      end

      def self.hardware(group)
        JSON.parse(group.get_attribute(DICT, 'hardware') || '[]').map { |a| Core::HardwareItem.from_attrs(a) }
      end

      def self.wardrobe?(entity)
        entity.is_a?(Sketchup::Group) && !entity.get_attribute(DICT, 'type').nil?
      end
    end
  end
end
```

`src/skrine/sketchup/builder.rb`:
```ruby
require_relative 'units'
require_relative 'storage'

module Skrine
  module SU
    # Turns a Core::Layout into SketchUp geometry inside a group.
    module Builder
      module_function

      def create(model, type_key, params)
        type = Core::Registry.fetch(type_key)
        layout = type.model_class.new(params).layout
        return result(layout) unless layout.valid?

        model.start_operation("Skrine: nová #{type.label}", true)
        group = model.active_entities.add_group
        group.name = type.label
        build_into(group, layout, params)
        Storage.write(group, type.key, params, hardware: layout.hardware)
        model.commit_operation
        model.selection.clear
        model.selection.add(group)
        result(layout).merge(group: group)
      rescue StandardError => e
        model.abort_operation
        { errors: ["Chyba pri generovaní: #{e.message}"], warnings: [], info: {} }
      end

      def rebuild(group, params)
        data = Storage.read(group)
        type = Core::Registry.fetch(data[:type])
        layout = type.model_class.new(params).layout
        return result(layout) unless layout.valid?

        model = group.model
        model.start_operation("Skrine: úprava #{type.label}", true)
        group.entities.clear!
        build_into(group, layout, params)
        Storage.write(group, type.key, params, hardware: layout.hardware)
        model.commit_operation
        result(layout)
      rescue StandardError => e
        model&.abort_operation
        { errors: ["Chyba pri generovaní: #{e.message}"], warnings: [], info: {} }
      end

      def result(layout)
        { errors: layout.errors, warnings: layout.warnings, info: layout.info }
      end

      def build_into(group, layout, params)
        materials = params[:materials] || {}
        layout.parts.each do |part|
          g = add_box(group.entities, part.box, part.name, material_for(group.model, part.material, materials))
          part.to_attrs.each { |k, v| g.set_attribute(Storage::PART_DICT, k, v) }
          apply_rotation(g, part.rotation) if part.rotation
        end
        layout.hardware.each do |hw|
          next unless hw.box

          g = add_box(group.entities, hw.box, hw.name, material_for(group.model, :hardware, materials))
          hw.to_attrs.each { |k, v| g.set_attribute(Storage::HW_DICT, k, v) }
        end
      end

      def add_box(entities, box, name, material)
        g = entities.add_group
        g.name = name
        pts = [
          Units.point(box.x, box.y, box.z), Units.point(box.x2, box.y, box.z),
          Units.point(box.x2, box.y2, box.z), Units.point(box.x, box.y2, box.z)
        ]
        face = g.entities.add_face(pts)
        face.reverse! if face.normal.z < 0
        face.pushpull(Units.mm(box.dz))
        g.material = material if material
        g
      end

      def apply_rotation(group, rot)
        point = Units.point(*rot[:point])
        axis = Geom::Vector3d.new(*rot[:axis])
        group.transform!(Geom::Transformation.rotation(point, axis, rot[:angle].degrees))
      end

      HARDWARE_COLOR = '#8a8a8a'.freeze

      def material_for(model, key, materials)
        name = "Skrine/#{key}"
        mat = model.materials[name] || model.materials.add(name)
        hex = key == :hardware ? HARDWARE_COLOR : (materials.dig(key.to_sym, :color) || '#ffffff')
        rgb = hex.to_s.delete('#').scan(/../).map { |c| c.to_i(16) }
        mat.color = Sketchup::Color.new(*rgb) if rgb.size == 3
        mat
      end
    end
  end
end
```

`src/skrine/sketchup/selection.rb`:
```ruby
require_relative 'storage'

module Skrine
  module SU
    module Selection
      # The selected Skrine object, or the one whose interior is being edited.
      def self.current_object(model)
        sel = model.selection.grep(Sketchup::Group).find { |g| Storage.wardrobe?(g) }
        return sel if sel

        model.active_path&.reverse&.find { |e| Storage.wardrobe?(e) }
      end

      def self.all_objects(model)
        model.entities.grep(Sketchup::Group).select { |g| Storage.wardrobe?(g) }
      end
    end
  end
end
```

`src/skrine/sketchup/commands.rb` (dialóg sa doplní v Task 12 – tu volá `Dialog.instance.open_for(group)`, ktorý ešte neexistuje; kým Task 12 nie je hotový, `edit_selected` zobrazí messagebox):
```ruby
require_relative 'builder'
require_relative 'selection'

module Skrine
  module SU
    module Commands
      module_function

      def new_object(type_key = :wardrobe)
        model = Sketchup.active_model
        type = Core::Registry.fetch(type_key)
        res = Builder.create(model, type.key, type.schema.defaults)
        if res[:errors].any?
          UI.messagebox("Skriňa sa nevytvorila:\n#{res[:errors].join("\n")}")
        else
          open_editor(res[:group])
        end
      end

      def edit_selected
        group = Selection.current_object(Sketchup.active_model)
        return UI.messagebox('Označ skriňu vytvorenú pluginom Skrine.') unless group

        open_editor(group)
      end

      def open_editor(group)
        if defined?(Skrine::SU::Dialog)
          Dialog.instance.open_for(group)
        else
          UI.messagebox('Editor ešte nie je k dispozícii (Task 12).')
        end
      end
    end
  end
end
```

`scripts/smoke.rb` (spustiť v Ruby Console: `load '/Users/milos/Git/sketchup-skrine/scripts/smoke.rb'`):
```ruby
# Smoke test for the SketchUp layer. Builds every preset side by side and prints counts.
model = Sketchup.active_model
x = 0.0
Dir[File.expand_path('../presets/*.json', __dir__)].sort.each do |file|
  params = Skrine::Wardrobe::Params::SCHEMA.merge_defaults(JSON.parse(File.read(file)))
  res = Skrine::SU::Builder.create(model, :wardrobe, params)
  if res[:errors].any?
    puts "#{File.basename(file)}: ERRORS #{res[:errors].join('; ')}"
    next
  end
  g = res[:group]
  g.transform!(Geom::Transformation.translation(Geom::Vector3d.new(Skrine::SU::Units.mm(x), 0, 0)))
  x += params[:width] + 300
  parts = g.entities.grep(Sketchup::Group).count { |e| e.get_attribute('Skrine::Part', 'name') }
  puts "#{File.basename(file)}: #{parts} parts, warnings: #{res[:warnings].size}"
end
model.active_view.zoom_extents
```

Do `src/skrine/loader.rb` pridaj za `require_relative 'core'`:
```ruby
require_relative 'sketchup/units'
require_relative 'sketchup/storage'
require_relative 'sketchup/builder'
require_relative 'sketchup/selection'
require_relative 'sketchup/commands'
```

- [ ] **Step 2: Nainštaluj a over v SketchUpe**

Run: `scripts/install_dev.sh`, spusti SketchUp 2026 (alebo v Ruby Console `load "#{ENV['HOME']}/Git/sketchup-skrine/src/skrine.rb"`), potom v Ruby Console:
```ruby
load '/Users/milos/Git/sketchup-skrine/scripts/smoke.rb'
```
Expected: v modeli 3 skrine vedľa seba, výpis `satnik-2-stlpce.json: N parts, warnings: 0` pre každý preset, bez výnimky. Vizuálne skontroluj: boky, strop/dno, priečka, police, 3 zásuvky dole v oboch stĺpcoch, dvojkrídlové dvere, sokel, nožičky; regál bez dverí; horná skrinka s výklopom.

Potom over pregenerovanie:
```ruby
g = Skrine::SU::Selection.all_objects(Sketchup.active_model).first
d = Skrine::SU::Storage.read(g)
p2 = Skrine::Wardrobe::Params::SCHEMA.merge_defaults(d[:params]).merge(width: 2400, door_display: :open)
Skrine::SU::Builder.rebuild(g, p2)
```
Expected: prvá skriňa sa rozšíri na 2400 mm na tom istom mieste, dvere sú otvorené; Undo (Cmd+Z) vráti pôvodný stav.

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat(sketchup): builder, attribute storage, selection helpers, commands and smoke script"
```

---

### Task 12: HtmlDialog editor (Ruby most + HTML/JS/CSS) a presety

**Files:**
- Create: `src/skrine/ui/dialog.rb`, `src/skrine/ui/html/index.html`, `src/skrine/ui/html/app.js`, `src/skrine/ui/html/style.css`, `src/skrine/sketchup/presets.rb`
- Modify: `src/skrine/loader.rb`

**Interfaces:**
- Consumes: `Builder.rebuild`, `Storage.read`, `Registry.fetch`, `schema.to_h`, `Commands.new_object`, `CutlistCommand.run(model, groups)` (Task 13 – kým neexistuje, tlačidlo Nárezový plán vypíše messagebox).
- Produces: `SU::Dialog.instance.open_for(group)`, `SU::Presets.save(json)`, `SU::Presets.load -> Hash|nil`. JS API: `Skrine.init(payload)`, `Skrine.setResult(result)`; callbacky do Ruby: `ready`, `apply(json)`, `save_preset(json)`, `load_preset`, `cutlist`, `new_object`.

- [ ] **Step 1: Ruby most a presety**

`src/skrine/sketchup/presets.rb`:
```ruby
require 'json'

module Skrine
  module SU
    module Presets
      # Repo-level presets/ (works with the dev symlink; packaged builds copy presets next to src).
      DIR = [File.expand_path('../../../presets', __dir__), File.expand_path('../presets', __dir__)].find { |d| Dir.exist?(d) }

      def self.save(json)
        path = UI.savepanel('Uložiť preset', DIR, 'skrina.json')
        return unless path

        path += '.json' unless path.end_with?('.json')
        File.write(path, JSON.pretty_generate(JSON.parse(json)))
      end

      def self.load
        path = UI.openpanel('Načítať preset', DIR, 'JSON|*.json||')
        return nil unless path

        JSON.parse(File.read(path))
      rescue JSON::ParserError => e
        UI.messagebox("Preset sa nedá načítať: #{e.message}")
        nil
      end
    end
  end
end
```

`src/skrine/ui/dialog.rb`:
```ruby
require 'json'
require_relative '../sketchup/builder'
require_relative '../sketchup/storage'
require_relative '../sketchup/presets'

module Skrine
  module SU
    # Parameter editor window. One instance; open_for(group) rebinds it to an object.
    class Dialog
      HTML = File.join(__dir__, 'html', 'index.html')

      def self.instance
        @instance ||= new
      end

      def open_for(group)
        @group = group
        data = Storage.read(group)
        @type = Core::Registry.fetch(data[:type])
        @params = @type.schema.merge_defaults(data[:params])
        @last = nil
        if dialog.visible?
          push_state
        else
          dialog.show
        end
      end

      def dialog
        @dialog ||= build_dialog
      end

      private

      def build_dialog
        d = UI::HtmlDialog.new(dialog_title: 'Skrine', preferences_key: 'sk.skrine.editor', width: 560, height: 920,
                               resizable: true, style: UI::HtmlDialog::STYLE_DIALOG)
        d.set_file(HTML)
        d.add_action_callback('ready') { push_state }
        d.add_action_callback('apply') { |_, json| apply(JSON.parse(json)) }
        d.add_action_callback('save_preset') { |_, json| Presets.save(json) }
        d.add_action_callback('load_preset') { load_preset }
        d.add_action_callback('cutlist') { run_cutlist }
        d.add_action_callback('new_object') { Commands.new_object(@type ? @type.key : :wardrobe) }
        d
      end

      def push_state
        return unless @params

        payload = { type: @type.key, label: @type.label, schema: @type.schema.to_h, state: @params, result: @last || {} }
        dialog.execute_script("Skrine.init(#{JSON.generate(payload)})")
      end

      def apply(values)
        @params = @type.schema.merge_defaults(values)
        @last = if @group.nil? || @group.deleted?
                  { errors: ['Skriňa v modeli už neexistuje – vytvor novú (tlačidlo Nová skriňa).'], warnings: [], info: {} }
                else
                  Builder.rebuild(@group, @params)
                end
        dialog.execute_script("Skrine.setResult(#{JSON.generate(@last)})")
      end

      def load_preset
        params = Presets.load
        return unless params

        apply(params)
        push_state
      end

      def run_cutlist
        if defined?(Skrine::SU::CutlistCommand)
          CutlistCommand.run(Sketchup.active_model, [@group].compact)
        else
          UI.messagebox('Nárezový plán ešte nie je k dispozícii (Task 13).')
        end
      end
    end
  end
end
```

Do `src/skrine/loader.rb` pridaj za `require_relative 'sketchup/commands'`:
```ruby
require_relative 'sketchup/presets'
require_relative 'ui/dialog'
```

- [ ] **Step 2: HTML, CSS, JS**

`src/skrine/ui/html/index.html`:
```html
<!DOCTYPE html>
<html lang="sk">
<head>
  <meta charset="utf-8">
  <title>Skrine</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <header>
    <h1 id="title">Skriňa</h1>
    <div class="actions">
      <button id="btn-apply" class="primary" type="button">Použiť</button>
      <label class="auto"><input type="checkbox" id="chk-auto"> Auto</label>
      <button id="btn-cutlist" type="button">Nárezový plán</button>
      <button id="btn-save" type="button">Uložiť preset</button>
      <button id="btn-load" type="button">Načítať preset</button>
      <button id="btn-new" type="button">Nová skriňa</button>
    </div>
  </header>
  <nav id="tabs"></nav>
  <main id="panels"></main>
  <footer>
    <div id="messages"></div>
    <div id="info"></div>
  </footer>
  <script src="app.js"></script>
</body>
</html>
```

`src/skrine/ui/html/style.css`:
```css
* { box-sizing: border-box; }
html, body { height: 100%; margin: 0; }
body { font: 13px -apple-system, "Segoe UI", Helvetica, Arial, sans-serif; color: #222; background: #f6f6f6; display: flex; flex-direction: column; }
header { padding: 8px 12px; background: #fff; border-bottom: 1px solid #ddd; }
header h1 { font-size: 15px; margin: 0 0 6px; }
.actions { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; }
button { font: inherit; padding: 4px 10px; border: 1px solid #bbb; border-radius: 4px; background: #fafafa; cursor: pointer; }
button:hover { background: #eee; }
button.primary { background: #2f6fdb; border-color: #2f6fdb; color: #fff; }
button.primary:hover { background: #245cb8; }
nav { display: flex; flex-wrap: wrap; gap: 2px; padding: 6px 12px 0; background: #fff; border-bottom: 1px solid #ddd; }
nav button { border-radius: 4px 4px 0 0; border-bottom: none; background: #eee; }
nav button.active { background: #fff; font-weight: 600; }
main { flex: 1; overflow: auto; padding: 10px 12px; }
.panel { display: none; }
.panel.active { display: block; }
.row { display: grid; grid-template-columns: 1fr 120px 28px; align-items: center; gap: 6px; padding: 3px 0; }
.row span { color: #333; }
.row em { color: #888; font-style: normal; font-size: 11px; }
.row input[type=number], .row input[type=text], .row select { width: 100%; font: inherit; padding: 3px 5px; border: 1px solid #bbb; border-radius: 3px; }
.row input[type=checkbox] { justify-self: start; }
fieldset { border: 1px solid #ddd; border-radius: 4px; margin: 8px 0; padding: 6px 10px; background: #fff; }
legend { font-weight: 600; padding: 0 4px; }
.list { margin: 8px 0; }
.list-head { font-weight: 600; margin: 6px 0; }
.item { border: 1px solid #ccc; border-radius: 4px; background: #fff; padding: 6px 10px; margin-bottom: 8px; }
.item .item { background: #f9f9f9; }
.item-bar { display: flex; gap: 4px; align-items: center; margin-bottom: 4px; }
.item-bar strong { flex: 1; }
.item-bar button { padding: 1px 7px; }
button.add { margin: 2px 0 8px; }
footer { border-top: 1px solid #ddd; background: #fff; padding: 6px 12px; max-height: 32%; overflow: auto; }
.msg { padding: 4px 8px; border-radius: 3px; margin-bottom: 3px; }
.msg.error { background: #fde8e8; color: #9b1c1c; }
.msg.warn { background: #fff4e0; color: #8a5300; }
#info { font-size: 12px; color: #444; line-height: 1.5; }
```

`src/skrine/ui/html/app.js`:
```javascript
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

window.addEventListener('DOMContentLoaded', () => {
  document.getElementById('btn-apply').onclick = () => Skrine.apply();
  document.getElementById('chk-auto').onchange = (e) => { Skrine.auto = e.target.checked; if (Skrine.auto) Skrine.apply(); };
  document.getElementById('btn-save').onclick = () => sketchup.save_preset(JSON.stringify(Skrine.state));
  document.getElementById('btn-load').onclick = () => sketchup.load_preset();
  document.getElementById('btn-cutlist').onclick = () => sketchup.cutlist();
  document.getElementById('btn-new').onclick = () => sketchup.new_object();
  if (window.sketchup) sketchup.ready();
});
```

- [ ] **Step 3: Over v SketchUpe**

V Ruby Console: `load "#{ENV['HOME']}/Git/sketchup-skrine/src/skrine.rb"` (alebo reštart SketchUpu), potom `Skrine::SU::Commands.new_object(:wardrobe)`.
Expected: vznikne skriňa z defaultov a otvorí sa dialóg so záložkami Rozmery … Kovanie a hrany. Zmeň Šírka na 2400 → Použiť → skriňa sa prekreslí, dole sa zobrazia vnútorné rozmery. Zapni Auto, zmeň hrúbku korpusu na 25 → prekreslí sa do 0,5 s. V záložke Stĺpce pridaj tretí stĺpec, zmeň obsah poľa na „vnorené zásuvky“. Zadaj nezmysel (šírka 10) → červená chyba, model sa nemení. Uložiť preset → JSON; Načítať preset `regal-otvoreny.json` → regál.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat(ui): HtmlDialog editor generated from the parameter schema, presets"
```

---

### Task 13: Nárezový plán v SketchUpe (zber z modelu, dialóg, exporty)

**Files:**
- Create: `src/skrine/sketchup/cutlist_command.rb`
- Modify: `src/skrine/loader.rb`

**Interfaces:**
- Consumes: `Export::Cutlist`, `Storage.read/hardware`, `Selection.all_objects`, `Core::Part.from_attrs`.
- Produces: `SU::CutlistCommand.run(model, groups = [])` (prázdne → označené skrine, inak všetky), `CutlistCommand.collect(groups) -> Export::Cutlist`.

- [ ] **Step 1: Implementácia**

`src/skrine/sketchup/cutlist_command.rb`:
```ruby
require_relative 'storage'
require_relative 'selection'

module Skrine
  module SU
    # Builds the cut list from what is actually in the model: parts are read from
    # the part groups' attributes (so manual edits count), hardware from the
    # object's stored list.
    module CutlistCommand
      module_function

      def run(model, groups = [])
        groups = model.selection.grep(Sketchup::Group).select { |g| Storage.wardrobe?(g) } if groups.empty?
        groups = Selection.all_objects(model) if groups.empty?
        return UI.messagebox('V modeli nie je žiadna skriňa vytvorená pluginom Skrine.') if groups.empty?

        show(collect(groups))
      end

      def collect(groups)
        parts = []
        hardware = []
        materials = {}
        groups.each do |g|
          data = Storage.read(g)
          type = Core::Registry.fetch(data[:type])
          params = type.schema.merge_defaults(data[:params])
          params[:materials].each { |k, v| materials[k] ||= v }
          g.entities.grep(Sketchup::Group).each do |e|
            dict = e.attribute_dictionary(Storage::PART_DICT)
            next unless dict

            parts << Core::Part.from_attrs(dict.to_h)
          end
          hardware.concat(Storage.hardware(g))
        end
        Export::Cutlist.new(parts, hardware, materials: materials)
      end

      def show(cutlist)
        buttons = '<p><button onclick="sketchup.export_csv()">Export CSV</button> ' \
                  '<button onclick="sketchup.export_optimizer()">Export pre CutList Optimizer</button> ' \
                  '<button onclick="sketchup.export_html()">Uložiť HTML</button> ' \
                  '<button onclick="window.print()">Tlač</button></p>'
        @dialog = UI::HtmlDialog.new(dialog_title: 'Nárezový plán', preferences_key: 'sk.skrine.cutlist',
                                     width: 900, height: 720, resizable: true)
        @dialog.set_html(cutlist.to_html.sub('<h1>Nárezový plán</h1>', "<h1>Nárezový plán</h1>#{buttons}"))
        @dialog.add_action_callback('export_csv') { save_file('narezovy-plan.csv', cutlist.to_csv) }
        @dialog.add_action_callback('export_optimizer') { save_file('cutlist-optimizer.csv', cutlist.to_optimizer_csv) }
        @dialog.add_action_callback('export_html') { save_file('narezovy-plan.html', cutlist.to_html) }
        @dialog.show
      end

      def save_file(default_name, content)
        path = UI.savepanel('Uložiť', nil, default_name)
        return unless path

        File.write(path, content)
        UI.messagebox("Uložené: #{path}")
      end
    end
  end
end
```

`AttributeDictionary#to_h` – ak v SketchUp 2026 nie je dostupné, nahraď `dict.to_h` za `dict.each_pair.to_h`.

Do `src/skrine/loader.rb` pridaj: `require_relative 'sketchup/cutlist_command'` (pred `ui/dialog`).

- [ ] **Step 2: Over v SketchUpe**

Označ jednu skriňu → v dialógu „Nárezový plán“ (alebo `Skrine::SU::CutlistCommand.run(Sketchup.active_model)`).
Expected: okno s tabuľkami podľa materiálu (DTD 18 biela, DTD 18 dekor, HDF 3, DTD 16), plocha a hranovanie pod každou, sekcie Hranovanie a Kovanie (pánty 16, LEGRABOX K NL500 sady 6, nožičky 6, konfirmáty 20, profil v mm). Export CSV uloží súbor s BOM; Export pre CutList Optimizer sa dá importovať na cutlistoptimizer.com.
Ručne v SketchUpe zmeň jednu policu (Scale) → nárezový plán ju stále uvedie s pôvodnými atribútmi (dokumentované správanie: rozmery idú z atribútov, nie z geometrie).

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat(sketchup): cut list command reading parts and hardware from the model"
```

---

### Task 14: Menu, kontextové menu, dokumentácia a overenie na reálnom modeli

**Files:**
- Modify: `src/skrine/loader.rb`, `README.md`

- [ ] **Step 1: Menu a kontextové menu**

Do `src/skrine/loader.rb` na koniec modulu pridaj:
```ruby
module Skrine
  unless file_loaded?(__FILE__)
    menu = UI.menu('Extensions').add_submenu('Skrine')
    menu.add_item('Nová skriňa') { SU::Commands.new_object(:wardrobe) }
    menu.add_item('Upraviť označenú skriňu') { SU::Commands.edit_selected }
    menu.add_item('Nárezový plán (označené / všetky)') { SU::CutlistCommand.run(Sketchup.active_model) }

    UI.add_context_menu_handler do |context_menu|
      group = SU::Selection.current_object(Sketchup.active_model)
      if group
        context_menu.add_separator
        context_menu.add_item('Upraviť skriňu (Skrine)') { SU::Commands.open_editor(group) }
        context_menu.add_item('Nárezový plán skrine') { SU::CutlistCommand.run(Sketchup.active_model, [group]) }
      end
    end
    file_loaded(__FILE__)
  end
end
```

- [ ] **Step 2: README – použitie**

Doplň do `README.md` sekciu:
```markdown
## Použitie
1. Extensions › Skrine › **Nová skriňa** – vloží skriňu na počiatok a otvorí editor.
2. Uprav parametre (záložky Rozmery, Konštrukcia, Čelá a špáry, Dvere, Úchytky, Zásuvky, Stĺpce, Materiály, Kovanie a hrany) → **Použiť** alebo zapni **Auto**.
3. Skriňu presuň štandardným nástrojom Move; pravý klik na skriňu → **Upraviť skriňu**.
4. **Nárezový plán** – tabuľky podľa materiálu, hranovanie, kovanie; export CSV / CutList Optimizer / HTML.
5. Presety: `presets/*.json` – čiastočné JSON parametre, načítajú sa cez Načítať preset.

Rozmery dielcov sú uložené v atribútoch (`Skrine::Part`) každej groupy; nárezový plán číta atribúty, nie geometriu.
Tabuľky zásuvkových systémov (Blum LEGRABOX / TANDEMBOX / MERIVOBOX) sú predvolené hodnoty – over ich v aktuálnom katalógu a uprav v záložke Zásuvky.
```

- [ ] **Step 3: Overenie na `~/Downloads/Skrine.skp`**

Otvor `~/Downloads/Skrine.skp`, cez menu vytvor novú skriňu s parametrami zodpovedajúcimi existujúcemu modelu (2 stĺpce, 3 zásuvky dole, profilové úchytky, nožičky) a postav ju vedľa pôvodnej. Porovnaj: rovnaká výška čiel zásuviek, rovnaké delenie dverí, nožičky. Rozdiely zapíš do `docs/superpowers/specs/2026-09-19-skrine-plugin-design.md` do novej sekcie „Overenie“ (ak treba, oprav defaulty).

- [ ] **Step 4: Finálne testy a commit**

Run: `/opt/homebrew/opt/ruby/bin/ruby -Isrc -Itest test/run_all.rb`
Expected: 0 failures.

```bash
git add -A && git commit -m "feat: menu and context menu, usage docs, verification notes"
```

---

## Self-review (vykonané pri písaní plánu)

- **Pokrytie specu:** rozmery/osadenie (T5), per-panel konštrukcia + zapustenie (T5), zadná stena 3 režimy (T5), spodok/lišty/zaslepovanie (T5), stĺpce/polia/police/tyče (T6), dvere 5 typov × 3 uloženia + pánty/výklop + otvorené zobrazenie + otvorený korpus (T7), úchytky 3 typy (T7), zásuvky 5 systémov + vnorené (T8), rad otvorov (T6, ako meta), kovanie/spojovací materiál/závesy (T9), materiály (T4/T10), hranovanie (T4 pravidlá, T10 metráž), nárezový plán + exporty (T10/T13), atribúty/pregenerovanie/undo (T11), dialóg + presety (T12), register typov (T3/T5), chybové stavy (T5–T8 errors/warnings, T11 abort_operation, T12 zobrazenie).
- **Mimo v1 (podľa specu):** nestovanie, polia cez viac stĺpcov, SPACE STEP, kreslenie vŕtania, toolbar (ikony).
- **Konzistencia názvov:** `build_drawers(col, cell, inner:)` (T6→T8), `front_rect/apply_handle/record_drilled_handle` (T7→T8), `Storage.write(..., hardware:)` (T11→T13), `Part#to_attrs/from_attrs` (T3→T11/T13), `Cutlist#to_html` obsahuje `<h1>Nárezový plán</h1>` (T10→T13).
