require 'test_helper'
require 'tmpdir'

class PresetStoreTest < Minitest::Test
  S = Skrine::Core::PresetStore

  def test_builtin_presets_listed_with_names
    Dir.mktmpdir do |dir|
      all = S.all(user_dir: dir)
      names = all.map { |p| p[:name] }
      assert_includes names, 'Satnik 2 stlpce'
      assert all.all? { |p| p[:params].is_a?(Hash) }
      refute all.first[:params].key?('_name')
    end
  end

  # I4: PresetStore.slug of a name with no ASCII letters/digits (e.g. "—") is "";
  # writing to "<user_dir>/.json" would be wrong, so save_named must reject it
  # instead of silently clobbering a stray file. The dialog rescues this into a
  # messagebox instead of a window.prompt (HtmlDialog/CEF does not implement it).
  def test_save_named_rejects_a_name_that_slugifies_to_empty
    Dir.mktmpdir do |dir|
      assert_raises(ArgumentError) { S.save_named({ 'width' => 1500 }, '—', user_dir: dir) }
      assert_empty Dir[File.join(dir, '*.json')]
    end
  end

  def test_save_named_writes_slug_file_and_lists_it
    Dir.mktmpdir do |dir|
      path = S.save_named({ 'width' => 1500 }, 'Moja skriňa – detská', user_dir: dir)
      assert_equal File.join(dir, 'moja-skrina-detska.json'), path
      entry = S.all(user_dir: dir).find { |p| p[:file] == path }
      assert_equal 'Moja skriňa – detská', entry[:name]
      assert_equal 1500, entry[:params]['width']
      assert_equal 1500, S.read(path, user_dir: dir)['width']
    end
  end

  def test_read_rejects_a_file_outside_the_preset_folders
    assert_raises(ArgumentError) { S.read('/tmp/x.json') }
  end

  def test_read_accepts_a_builtin_preset_path
    Dir.mktmpdir do |dir|
      entry = S.all(user_dir: dir).first
      assert_equal entry[:params]['width'], S.read(entry[:file])['width']
    end
  end

  def test_allowed_resolves_a_preset_reached_through_a_symlinked_folder
    Dir.mktmpdir do |real_dir|
      path = S.save_named({ 'width' => 1500 }, 'Sym preset', user_dir: real_dir)
      Dir.mktmpdir do |link_parent|
        link_dir = File.join(link_parent, 'link')
        File.symlink(real_dir, link_dir)
        symlinked_file = File.join(link_dir, File.basename(path))
        assert S.allowed?(symlinked_file, user_dir: real_dir)
      end
    end
  end
end
