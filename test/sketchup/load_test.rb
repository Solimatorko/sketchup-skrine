require 'test_helper'

# These files only touch the SketchUp API inside method bodies, so they load fine
# in plain Ruby. We require them directly here (not src/skrine.rb or loader.rb,
# which pull in 'sketchup.rb' and need a real SketchUp host).
require 'skrine/sketchup/units'
require 'skrine/sketchup/storage'
require 'skrine/sketchup/builder'
require 'skrine/sketchup/selection'
require 'skrine/sketchup/commands'

class SketchupLoadTest < Minitest::Test
  def test_modules_are_defined
    assert defined?(Skrine::SU::Units)
    assert defined?(Skrine::SU::Storage)
    assert defined?(Skrine::SU::Builder)
    assert defined?(Skrine::SU::Selection)
    assert defined?(Skrine::SU::Commands)
  end

  def test_units_mm_conversion
    assert_in_delta 1.0, Skrine::SU::Units.mm(25.4), 1e-9
  end
end
