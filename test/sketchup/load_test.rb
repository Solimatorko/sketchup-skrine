require 'test_helper'

# These files only touch the SketchUp API inside method bodies, so they load fine
# in plain Ruby. We require them directly here (not src/skrine.rb or loader.rb,
# which pull in 'sketchup.rb' and need a real SketchUp host).
require 'skrine/sketchup/units'
require 'skrine/sketchup/storage'
require 'skrine/sketchup/builder'
require 'skrine/sketchup/selection'
require 'skrine/sketchup/commands'
require 'skrine/sketchup/presets'
require 'skrine/sketchup/cutlist_command'
require 'skrine/ui/preview_service'
require 'skrine/ui/dialog'

class SketchupLoadTest < Minitest::Test
  def test_modules_are_defined
    assert defined?(Skrine::SU::Units)
    assert defined?(Skrine::SU::Storage)
    assert defined?(Skrine::SU::Builder)
    assert defined?(Skrine::SU::Selection)
    assert defined?(Skrine::SU::Commands)
    assert defined?(Skrine::SU::Presets)
    assert defined?(Skrine::SU::Dialog)
    assert defined?(Skrine::SU::CutlistCommand)
    assert defined?(Skrine::Editor::PreviewService)
  end

  def test_commands_expose_new_from_preset
    assert_respond_to Skrine::SU::Commands, :new_from_preset
  end

  def test_presets_dir_exists_and_has_presets
    dir = Skrine::SU::Presets::DIR
    refute_nil dir
    assert Dir.exist?(dir)
    assert_operator Dir[File.join(dir, '*.json')].size, :>, 0
  end

  # U+2028/U+2029 are valid JSON but break execute_script's generated JS source in
  # some WebViews; js_json must escape them to the literal  /  sequence.
  def test_dialog_js_json_escapes_line_and_paragraph_separators
    result = Skrine::SU::Dialog.js_json({ s: "a b" })
    assert_includes result, '\\u2028'
    refute_includes result, " "
  end

  def test_units_mm_conversion
    assert_in_delta 1.0, Skrine::SU::Units.mm(25.4), 1e-9
  end

  # Minimal double: only what Builder.create touches before it would fail on an
  # unknown type. Records which operation-lifecycle methods were called.
  FakeModel = Struct.new(:calls) do
    def initialize
      super([])
    end

    def start_operation(*) = calls << :start_operation
    def abort_operation = calls << :abort_operation
    def commit_operation = calls << :commit_operation
  end

  # Fails loudly if touched: add_box must raise before reaching the SketchUp API
  # for a degenerate box (dx/dy/dz <= 0), not fall through to a cryptic error.
  FakeEntitiesNeverCalled = Class.new do
    def method_missing(*) = raise('entities should not be touched for a degenerate box')
    def respond_to_missing?(*) = true
  end

  def test_add_box_raises_a_readable_error_for_a_degenerate_box
    box = Skrine::Core::Box.new(x: 0.0, y: 0.0, z: 0.0, dx: 100.0, dy: 0.0, dz: 50.0)
    err = assert_raises(RuntimeError) do
      Skrine::SU::Builder.add_box(FakeEntitiesNeverCalled.new, box, 'Polica', nil)
    end
    assert_includes err.message, "'Polica'"
    assert_includes err.message, '100.0'
  end

  def test_create_with_unknown_type_does_not_abort_unstarted_operation
    fake_model = FakeModel.new
    res = Skrine::SU::Builder.create(fake_model, :no_such_type, {})

    assert_equal 1, res[:errors].size
    assert_match(/neznámy typ/, res[:errors].first)
    refute_includes fake_model.calls, :abort_operation
  end

  # Minimal doubles for CutlistCommand.collect. Plain Ruby has no Sketchup::Group,
  # so Storage.wardrobe? and CutlistCommand's part lookup fall back to duck typing
  # (see storage.rb#wardrobe? and cutlist_command.rb#part_groups).
  FakePartDict = Struct.new(:attrs) do
    def to_h = attrs
  end

  FakePartEntity = Struct.new(:part) do
    def attribute_dictionary(name)
      FakePartDict.new(part.to_attrs) if name == Skrine::SU::Storage::PART_DICT
    end
  end

  FakeWardrobeGroup = Struct.new(:part_entities) do
    def get_attribute(dict, key)
      return nil unless dict == Skrine::SU::Storage::DICT

      { 'type' => 'wardrobe', 'params' => '{}', 'hardware' => hardware_json }[key]
    end

    def hardware_json
      JSON.generate([{ 'kind' => 'hinge', 'name' => 'Pánt 16', 'qty' => 2.0, 'unit' => 'pcs', 'meta' => '{}' }])
    end

    def entities = part_entities
  end

  # A dictionary without #to_h (as on some SketchUp/Ruby combinations), forcing
  # CutlistCommand.collect onto the dict.keys.to_h { ... } fallback. A plain
  # class (not a Struct, which would supply its own #to_h) so respond_to?(:to_h)
  # is really false, like SketchUp's own AttributeDictionary on older builds.
  class FakePartDictNoToH
    def initialize(attrs) = @attrs = attrs
    def keys = @attrs.keys
    def [](key) = @attrs[key]
  end

  FakePartEntityNoToH = Struct.new(:part) do
    def attribute_dictionary(name)
      FakePartDictNoToH.new(part.to_attrs) if name == Skrine::SU::Storage::PART_DICT
    end
  end

  def test_cutlist_command_collect_falls_back_when_attribute_dictionary_has_no_to_h
    sample_part = Skrine::Core::Part.new(name: 'Bok P', category: :side, material: :corpus,
                                          length: 2300, width: 582, thickness: 18,
                                          edges: { long_a: true }, grain: :length)
    group = FakeWardrobeGroup.new([FakePartEntityNoToH.new(sample_part)])

    cutlist = Skrine::SU::CutlistCommand.collect([group])

    row = cutlist.rows.find { |r| r.name == 'Bok P' }
    refute_nil row
    assert_equal 2300, row.length
    assert_equal 582, row.width
  end

  def test_cutlist_command_collect_reads_parts_and_hardware_from_fake_groups
    sample_part = Skrine::Core::Part.new(name: 'Bok Ľ', category: :side, material: :corpus,
                                          length: 2300, width: 582, thickness: 18,
                                          edges: { long_a: true }, grain: :length)
    group = FakeWardrobeGroup.new([FakePartEntity.new(sample_part)])

    cutlist = Skrine::SU::CutlistCommand.collect([group])

    row = cutlist.rows.find { |r| r.name == 'Bok Ľ' }
    refute_nil row
    assert_equal 1, row.qty
    assert_equal 2300, row.length
    assert_equal 582, row.width

    hw = cutlist.hardware_rows.find { |r| r.kind == :hinge }
    refute_nil hw
    assert_equal 2, hw.qty
  end
end

# R1 (final-review.md C1/C2): SketchUp defines a global `::UI` module; a
# `Skrine::UI` constant would shadow it for every unqualified `UI` inside
# `module Skrine ... end` (menu registration, HtmlDialog, messagebox, …) and
# break the whole plugin at load time. Plain Ruby has no `::UI`, so nothing
# above this point would ever catch that regression. Stub just enough of
# `::UI`/`::Sketchup` to drive `Dialog#build_dialog` and its callbacks the way
# SketchUp would, so a reintroduced `Skrine::UI` (or an unqualified
# `PreviewService` reference, C2) fails here instead of only inside SketchUp.
unless defined?(::UI)
  module ::UI
    class HtmlDialog
      STYLE_DIALOG = :dialog

      attr_reader :callbacks

      def initialize(**_opts)
        @callbacks = {}
        @executed = []
        @visible = false
      end

      def set_file(_path); end
      def set_html(_html); end

      # Records name -> block so a test can invoke a callback the way the
      # WebView bridge would.
      def add_action_callback(name, &block)
        @callbacks[name] = block
      end

      def execute_script(js)
        @executed << js
      end

      attr_reader :executed

      def show
        @visible = true
      end

      def visible?
        @visible
      end

      def close
        @visible = false
      end
    end

    def self.menu(_name)
      Object.new.tap do |m|
        def m.add_submenu(*) = self
        def m.add_item(*) = self
      end
    end

    def self.add_context_menu_handler(&_block); end
    def self.messagebox(*_args); end
    def self.start_timer(*_args); end
    def self.openpanel(*_args); end
    def self.savepanel(*_args); end
  end
end

unless defined?(::Sketchup)
  module ::Sketchup
    def self.active_model = nil
  end
end

class SketchupUiShapeTest < Minitest::Test
  def test_skrine_never_defines_a_ui_constant
    refute Skrine.const_defined?(:UI, false)
  end

  def test_build_dialog_returns_the_stub_html_dialog_with_registered_callbacks
    dialog = Skrine::SU::Dialog.new
    d = dialog.send(:build_dialog)

    assert_kind_of ::UI::HtmlDialog, d
    assert d.callbacks.key?('preview')
    assert d.callbacks.key?('apply')
    assert d.callbacks.key?('gallery')
  end

  # Exercises the real `Editor::PreviewService.preview` call through the callback
  # (not a mock), so an unqualified `PreviewService` (C2) or a reintroduced
  # `Skrine::UI` (C1) would raise NameError here instead of only in SketchUp.
  def test_preview_callback_executes_a_set_preview_script
    dialog = Skrine::SU::Dialog.new
    dialog.instance_variable_set(:@type, Skrine::Core::Registry.fetch(:wardrobe))
    d = dialog.send(:build_dialog)
    # send_js resolves the dialog via the memoizing `dialog` accessor; wire it to
    # the same stub instance the callback below is registered on.
    dialog.instance_variable_set(:@dialog, d)

    d.callbacks['preview'].call(nil, '{"width":1500}')

    assert_equal 1, d.executed.size
    assert d.executed.first.start_with?('Skrine.setPreview('), d.executed.first
  end
end
