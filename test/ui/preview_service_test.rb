require 'test_helper'

class PreviewServiceTest < Minitest::Test
  TYPE = Skrine::Core::Registry.fetch(:wardrobe)
  PS = Skrine::Editor::PreviewService

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
