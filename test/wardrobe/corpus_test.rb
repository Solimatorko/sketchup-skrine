require 'test_helper'

class CorpusTest < Minitest::Test
  def test_default_layout_is_valid
    l = wardrobe
    assert l.valid?, l.errors.join('; ')
  end

  def test_frame_info
    l = wardrobe
    assert_in_delta 1964, l.info[:inner_w]
    assert_in_delta 2264, l.info[:inner_h]     # 2300 corpus - 18 - 18
    assert_in_delta 567, l.info[:inner_d]      # 582 - (12 groove offset + 3 HDF)
  end

  def test_sides_full_height_between_inset_top_and_bottom
    l = wardrobe
    left = l.find('Bok Ľ')
    assert_box left, x: 0, y: 18, z: 100, dx: 18, dy: 582, dz: 2300
    assert_equal 2300, left.length
    assert_equal 582, left.width
    assert_equal '1D', left.edge_code
    right = l.find('Bok P')
    assert_box right, x: 1982, y: 18, z: 100, dx: 18, dy: 582, dz: 2300
  end

  def test_top_and_bottom_inset_between_sides
    l = wardrobe
    assert_box l.find('Strop'), x: 18, y: 18, z: 2382, dx: 1964, dy: 582, dz: 18
    assert_box l.find('Dno'), x: 18, y: 18, z: 100, dx: 1964, dy: 582, dz: 18
  end

  def test_top_overlay_shortens_sides
    top = wardrobe_params[:top].merge(corner_left: :overlay, corner_right: :overlay)
    l = wardrobe(top: top)
    assert_box l.find('Strop'), x: 0, y: 18, z: 2382, dx: 2000, dy: 582, dz: 18
    assert_box l.find('Bok Ľ'), x: 0, y: 18, z: 100, dx: 18, dy: 582, dz: 2282
  end

  def test_engagement_extends_bottom_into_sides
    bottom = wardrobe_params[:bottom].merge(engagement: 6)
    l = wardrobe(bottom: bottom)
    assert_box l.find('Dno'), x: 12, y: 18, z: 100, dx: 1976, dy: 582, dz: 18
  end

  def test_side_recess_and_custom_thickness
    l = wardrobe(side_left: { thickness: 25, front_recess: 10, back_recess: 5 })
    assert_box l.find('Bok Ľ'), x: 0, y: 28, z: 100, dx: 25, dy: 567, dz: 2300
    assert_in_delta 1957, l.info[:inner_w]
  end

  def test_legs_and_bottom_strip
    l = wardrobe
    legs = l.hardware.select { |h| h.kind == :leg }
    assert_equal 6, legs.sum(&:qty)                 # 4 + 2 per partition (1 partition)
    assert legs.all?(&:box)
    strip = l.find('Sokel')
    assert_box strip, x: 0, y: 50, z: 10, dx: 2000, dy: 18, dz: 90
    assert_equal :strip, strip.category
  end

  def test_plinth_sides_reach_floor_and_plinth_sits_between_sides
    l = wardrobe(base_type: :plinth)
    assert_box l.find('Bok Ľ'), x: 0, y: 18, z: 0, dx: 18, dy: 582, dz: 2400
    assert_box l.find('Sokel'), x: 18, y: 50, z: 10, dx: 1964, dy: 18, dz: 90
    assert_empty l.hardware.select { |h| h.kind == :leg }
  end

  def test_floor_base_has_no_strip_and_full_corpus
    l = wardrobe(base_type: :floor)
    assert_nil l.find('Sokel')
    assert_box l.find('Dno'), x: 18, y: 18, z: 0, dx: 1964, dy: 582, dz: 18
  end

  def test_top_strip_and_gap_top
    l = wardrobe(gap_top: 80, top_strip: true, top_strip_setback: 5)
    assert_box l.find('Lišta horná'), x: 0, y: 5, z: 2320, dx: 2000, dy: 18, dz: 80
    assert_box l.find('Strop'), x: 18, y: 18, z: 2302, dx: 1964, dy: 582, dz: 18
  end

  def test_wall_gaps_and_fillers
    l = wardrobe(gap_left: 30, gap_right: 20, filler_left: true)
    assert_box l.find('Bok Ľ'), x: 30, y: 18, z: 100, dx: 18, dy: 582, dz: 2300
    assert_box l.find('Lišta zaslepovacia Ľ'), x: 0, y: 0, z: 100, dx: 30, dy: 18, dz: 2300
    assert_nil l.find('Lišta zaslepovacia P')
    assert_in_delta 1950, l.info[:corpus_w]
  end

  def test_back_groove
    l = wardrobe
    back = l.find('Zadná stena')
    assert_box back, x: 10, y: 585, z: 110, dx: 1980, dy: 3, dz: 2280
    assert_equal 3, back.thickness
    assert_equal :back, back.material
  end

  def test_back_overlay_shortens_body
    l = wardrobe(back_mode: :overlay)
    assert_box l.find('Zadná stena'), x: 0, y: 597, z: 100, dx: 2000, dy: 3, dz: 2300
    assert_box l.find('Bok Ľ'), x: 0, y: 18, z: 100, dx: 18, dy: 579, dz: 2300
    assert_in_delta 579, l.info[:inner_d]
  end

  def test_back_inset_uses_thick_panel_between_sides
    l = wardrobe(back_mode: :inset)
    assert_box l.find('Zadná stena'), x: 18, y: 582, z: 118, dx: 1964, dy: 18, dz: 2264
    assert_in_delta 564, l.info[:inner_d]
    assert_equal :corpus, l.find('Zadná stena').material
  end

  def test_plinth_with_overlay_top_corners
    top = wardrobe_params[:top].merge(corner_left: :overlay, corner_right: :overlay)
    l = wardrobe(base_type: :plinth, top: top)
    assert l.valid?, l.errors.join('; ')
    left = l.find('Bok Ľ')
    assert_in_delta 0, left.box.z
    assert_in_delta 2382, left.box.dz
    strop = l.find('Strop')
    assert_in_delta 0, strop.box.x
    assert_in_delta 2000, strop.box.dx
  end

  def test_legs_with_overlay_bottom_corners
    bottom = wardrobe_params[:bottom].merge(corner_left: :overlay, corner_right: :overlay)
    l = wardrobe(base_type: :legs, bottom: bottom)
    assert l.valid?, l.errors.join('; ')
    left = l.find('Bok Ľ')
    assert_in_delta 118, left.box.z
    assert_in_delta 2282, left.box.dz
    dno = l.find('Dno')
    assert_in_delta 0, dno.box.x
    assert_in_delta 2000, dno.box.dx
  end

  def test_depth_excluding_fronts
    l = wardrobe(depth_includes_fronts: false)
    assert_box l.find('Bok Ľ'), x: 0, y: 18, z: 100, dx: 18, dy: 600, dz: 2300
  end

  def test_invalid_params_produce_errors_not_parts
    l = wardrobe(width: 10)
    refute l.valid?
    assert_includes l.errors, 'width: min 200'
    assert_empty l.parts
  end

  def test_negative_inner_height_is_an_error
    l = wardrobe(height: 250, base_height: 200, gap_top: 60)
    refute l.valid?
    assert l.errors.any? { |e| e.include?('výška') }
  end
end
