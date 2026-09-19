require 'test_helper'

class ExtrasTest < Minitest::Test
  def test_confirmat_count_from_fixed_joints
    l = wardrobe
    j = l.hardware.find { |h| h.kind == :joinery }
    # top+bottom: 2 panels x 2 joints x 2 = 8 ; partition: 2 joints x 2 = 4 ; 2 fixed shelves x 2 joints x 2 = 8
    assert_equal 'Konfirmát', j.name
    assert_equal 20, j.qty
  end

  def test_joinery_none_and_brackets
    l = wardrobe(joinery: :none, wall_brackets: 2)
    assert_nil l.hardware.find { |h| h.kind == :joinery }
    assert_equal 2, l.hardware.find { |h| h.kind == :bracket }.qty
  end

  def test_pitch_increases_count_for_long_joints
    l = wardrobe(joinery: :dowels, joinery_pitch: 150)
    j = l.hardware.find { |h| h.kind == :joinery }
    assert_equal 'Kolík', j.name
    assert_equal 4 * 4 + 4 * 2 + 4 * 4, j.qty     # 582 -> 4, 567 -> 4, 565 -> 4 per joint
  end
end
