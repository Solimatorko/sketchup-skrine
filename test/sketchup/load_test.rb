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
end
