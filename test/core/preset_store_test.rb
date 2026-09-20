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
