require 'test_helper'

class SceneMetaTest < Minitest::Test
  def test_column_and_cell_geometry_in_info
    l = wardrobe
    col = l.info[:columns][0]
    assert_in_delta 18, col[:x]
    cell = col[:cells][0]
    assert_in_delta 18, cell[:x]
    assert_in_delta 736, cell[:z]
    assert_in_delta 973, cell[:w]
    assert_in_delta 1646, cell[:h]
  end

  def test_cell_contents_carry_column_and_cell_meta
    l = wardrobe
    assert_equal({ column: 2, cell: 1 }, l.find('Polica S2/P1-1').meta.slice(:column, :cell))
    assert_equal 2, l.find('Čelo Zásuvka S1/P2-1').meta[:cell]
    assert_equal 2, l.find('Dno Zásuvka S1/P2-1').meta[:cell]
    rod = l.hardware.find { |h| h.kind == :rod }
    assert_equal 1, rod.meta[:cell]
    assert_equal 1, l.find('Polica pevná S1/1').meta[:cell]
  end

  def test_strip_meta
    l = wardrobe(gap_top: 80, top_strip: true, gap_left: 30, filler_left: true)
    assert_equal :plinth, l.find('Sokel').meta[:strip]
    assert_equal :top, l.find('Lišta horná').meta[:strip]
    assert_equal :filler, l.find('Lišta zaslepovacia Ľ').meta[:strip]
  end

  def test_placement_param_exists_and_is_ignored_by_geometry
    d = Skrine::Wardrobe::Params::SCHEMA.defaults
    assert_equal :between_walls, d[:placement]
    assert_equal :placement, Skrine::Wardrobe::Params::SCHEMA.params.keys.first
    assert wardrobe(placement: :free).valid?
  end
end
