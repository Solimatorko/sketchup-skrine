require 'test_helper'

class ColumnsTest < Minitest::Test
  def test_two_auto_columns_share_inner_width
    l = wardrobe
    cols = l.info[:columns]
    assert_equal 2, cols.size
    assert_in_delta 973, cols[0][:inner_w]     # (1964 - 18) / 2
    assert_box l.find('Priečka 1'), x: 991, y: 18, z: 118, dx: 18, dy: 567, dz: 2264
    assert_equal :partition, l.find('Priečka 1').category
  end

  def test_cells_are_laid_out_top_down_with_fixed_shelf
    l = wardrobe
    cells = l.info[:columns][0][:cells]
    assert_in_delta 1646, cells[0][:inner_h]    # 2264 - 18 shelf - 600
    assert_in_delta 600, cells[1][:inner_h]
    assert_box l.find('Polica pevná S1/1'), x: 18, y: 20, z: 718, dx: 973, dy: 565, dz: 18
    assert_equal 973, l.find('Polica pevná S1/1').length
    assert_equal 565, l.find('Polica pevná S1/1').width
  end

  def test_adjustable_shelves_are_spread_evenly_with_supports
    l = wardrobe
    first = l.find('Polica S2/P1-1')
    assert_box first, x: 1009, y: 20, z: 1050.8, dx: 973, dy: 565, dz: 18, delta: 0.05
    assert first.meta[:adjustable]
    supports = l.hardware.select { |h| h.kind == :shelf_support }
    assert_equal 16, supports.sum(&:qty)
  end

  def test_rod_is_hardware_with_box
    l = wardrobe
    rod = l.hardware.find { |h| h.kind == :rod }
    assert_in_delta 973, rod.meta[:length]
    assert_in_delta 2292, rod.box.z
    assert_in_delta 286.5, rod.box.y
  end

  def test_mm_and_ratio_columns
    cols = [
      { width_mode: :mm, width: 400, cells: [{ content: :shelves, shelves_count: 1 }] },
      { width_mode: :ratio, width: 1, cells: [{ content: :empty }] },
      { width_mode: :ratio, width: 2, cells: [{ content: :empty }] }
    ]
    l = wardrobe(columns: cols)
    assert l.valid?, l.errors.join('; ')
    w = l.info[:columns].map { |c| c[:inner_w] }
    assert_in_delta 400, w[0]
    assert_in_delta (1964 - 36 - 400) / 3.0, w[1], 0.05
    assert_in_delta (1964 - 36 - 400) * 2 / 3.0, w[2], 0.05
  end

  def test_fixed_widths_overflow_is_error
    cols = [{ width_mode: :mm, width: 1500, cells: [{}] }, { width_mode: :mm, width: 1500, cells: [{}] }]
    l = wardrobe(columns: cols)
    refute l.valid?
    assert l.errors.first.include?('presahujú')
  end

  def test_too_many_shelves_is_error
    cols = [{ cells: [{ height_mode: :mm, height: 100, content: :shelves, shelves_count: 5 }, { content: :empty }] }]
    l = wardrobe(columns: cols)
    refute l.valid?
    assert l.errors.any? { |e| e.include?('políc') }
  end

  def test_too_narrow_column_is_skipped_instead_of_building_garbage_parts
    cols = [
      { width_mode: :mm, width: 1900, cells: [{}] },
      { width_mode: :auto, width: 1, cells: [{}] }
    ]
    l = wardrobe(columns: cols)
    refute l.valid?
    assert l.errors.any? { |e| e.include?('Stĺpec 2') }
    refute l.find('Polica pevná S2/1')
    refute l.parts.any? { |part| part.meta[:column] == 2 }
  end

  def test_line_drilling_is_recorded_on_sides_and_partitions
    l = wardrobe(line_drilling: true)
    assert_equal 32, l.find('Bok Ľ').meta[:drilling][:pitch]
    assert_equal 32, l.find('Priečka 1').meta[:drilling][:pitch]
    assert_nil l.find('Strop').meta[:drilling]
  end
end
