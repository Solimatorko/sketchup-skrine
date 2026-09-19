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
