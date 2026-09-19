$LOAD_PATH.unshift File.expand_path('../src', __dir__)
require 'minitest/autorun'
require 'json'
require 'skrine/core'

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
