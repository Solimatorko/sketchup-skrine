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
