require 'test_helper'

class DrawersTest < Minitest::Test
  def test_three_drawer_fronts_fill_the_cell_with_gaps_and_profile
    l = wardrobe
    f1 = l.find('Čelo Zásuvka S1/P2-1')
    f2 = l.find('Čelo Zásuvka S1/P2-2')
    f3 = l.find('Čelo Zásuvka S1/P2-3')
    # rect: z 100 (bottom panel overlay 18), height 600 + 7.5 + 18 = 625.5 -> 3 x 206.5 with 3 mm gaps
    assert_box f1, x: 2, y: 0, z: 519, dx: 996.5, dy: 18, dz: 176.5
    assert_box f2, x: 2, y: 0, z: 309.5, dx: 996.5, dy: 18, dz: 176.5
    assert_box f3, x: 2, y: 0, z: 100, dx: 996.5, dy: 18, dz: 176.5
    assert_equal :front, f1.category
    assert_equal 176.5, f1.length
  end

  def test_legrabox_picks_class_and_nominal_length
    l = wardrobe
    bottom = l.find('Dno Zásuvka S1/P2-1')
    assert_equal 886, bottom.length            # 973 - 87
    assert_equal 488, bottom.width             # NL 500 - 12
    assert_equal 16, bottom.thickness
    assert_equal 'K', bottom.meta[:class]
    back = l.find('Zadný diel Zásuvka S1/P2-1')
    assert_equal 886, back.length
    assert_equal 128.5, back.width
    slides = l.hardware.select { |h| h.kind == :slide }
    assert_equal 6, slides.size
    assert_equal 'Blum LEGRABOX K NL500 (sada)', slides.first.name
    sides = l.hardware.select { |h| h.kind == :drawer_side }
    assert_equal 12, sides.size
    assert sides.all?(&:box)
    assert_equal :none, bottom.grain
    assert_equal :none, back.grain
  end

  def test_wood_box_parts
    l = wardrobe(drawer_system: :wood_box)
    side = l.find('Box bok Ľ Zásuvka S1/P2-1')
    assert_equal 500, side.length
    assert_equal 151.5, side.width             # 176.5 - 25; front-limited (share is bounded by the drawer above, not its own front)
    assert_equal 16, side.thickness
    back = l.find('Box zadný Zásuvka S1/P2-1')
    assert_equal 915, back.length              # 973 - 26 - 32
    bottom = l.find('Box dno Zásuvka S1/P2-1')
    assert_equal 480, bottom.length            # 500 - 32 + 12
    assert_equal 927, bottom.width             # 915 + 12
    assert_equal 3, bottom.thickness
    assert_equal :back, bottom.material
    assert l.hardware.any? { |h| h.kind == :slide && h.name.include?('NL500') }
  end

  def test_front_only_has_no_box_parts
    l = wardrobe(drawer_system: :front_only)
    assert_empty l.by_category(:drawer_box)
    assert_equal 6, l.hardware.count { |h| h.kind == :slide }
  end

  def test_custom_front_heights
    cols = wardrobe_params[:columns]
    cols[0][:cells][1] = cols[0][:cells][1].merge(drawer_heights: '250, 200, 169.5')
    l = wardrobe(columns: cols)
    assert l.valid?, l.errors.join('; ')
    assert_in_delta 250 - 30, l.find('Čelo Zásuvka S1/P2-1').box.dz
    assert_in_delta 169.5 - 30, l.find('Čelo Zásuvka S1/P2-3').box.dz
  end

  def test_custom_front_heights_mismatch_is_error
    cols = wardrobe_params[:columns]
    cols[0][:cells][1] = cols[0][:cells][1].merge(drawer_heights: '100,100,100')
    l = wardrobe(columns: cols)
    refute l.valid?
    assert l.errors.any? { |e| e.include?('S1/P2') }
  end

  def test_inner_drawers_sit_behind_doors_without_handles
    cols = [{ cells: [{ content: :inner_drawers, drawers_count: 2 }] }]
    l = wardrobe(columns: cols, doors: { type: :double, mount: :overlay })
    front = l.find('Čelo Vnút. zásuvka S1/P1-1')
    assert_in_delta 18 + 3, front.box.x
    assert_in_delta 18 + 30, front.box.y
    assert_in_delta 1964 - 6, front.box.dx
    assert l.find('Dvere S1 Ľ')
    assert_equal 1, l.hardware.count { |h| h.kind == :profile }   # only the doors
  end

  def test_inner_drawer_runner_length_accounts_for_the_box_start
    cols = [{ cells: [{ content: :inner_drawers, drawers_count: 2 }] }]
    l = wardrobe(columns: cols, depth: 560)
    assert l.valid?, l.errors.join('; ')
    limit = 18 + l.info[:inner_d]
    boxes = l.by_category(:drawer_box) + l.hardware.select { |h| h.kind == :drawer_side }
    assert boxes.any?
    boxes.each { |b| assert_operator b.box.y2, :<=, limit, b.name }
  end

  def test_too_shallow_for_any_runner_is_error
    l = wardrobe(depth: 250)
    refute l.valid?
    assert l.errors.any? { |e| e.include?('výsuv') }
  end

  def test_low_front_warns_about_class
    cols = [{ cells: [{ content: :drawers, height_mode: :mm, height: 40, drawers_count: 1 }, { content: :empty }] }]
    l = wardrobe(columns: cols, handle: { type: :none })
    assert l.warnings.any? { |w| w.include?('trieda') }
  end

  def test_single_drawer_wood_box_fits_the_cavity_not_the_front
    cols = [{ cells: [{ content: :drawers, height_mode: :mm, height: 200, drawers_count: 1 }, { content: :empty }] }]
    l = wardrobe(columns: cols, handle: { type: :none }, drawer_system: :wood_box)
    assert l.valid?, l.errors.join('; ')
    # first cell of column 1 spans z[2182..2382] (inner_z0 118 + inner_h 2264, minus the 200 mm cell height)
    boxes = l.by_category(:drawer_box).select { |pt| pt.meta[:drawer]&.include?('S1/P1') }
    assert boxes.any?
    boxes.each do |pt|
      assert_operator pt.box.z, :>=, 2182, pt.name
      assert_operator pt.box.z2, :<=, 2382, pt.name
    end
  end

  def test_single_drawer_legrabox_picks_a_class_that_fits_the_cavity
    cols = [{ cells: [{ content: :drawers, height_mode: :mm, height: 170, drawers_count: 1 }, { content: :empty }] }]
    l = wardrobe(columns: cols, handle: { type: :none })
    assert l.valid?, l.errors.join('; ')
    back = l.find('Zadný diel Zásuvka S1/P1-1')
    refute_equal 'C', back.meta[:class]
    sides = l.hardware.select { |h| h.kind == :drawer_side }
    sides.each do |hw|
      assert_operator hw.box.z, :>=, 2182, hw.name
      assert_operator hw.box.z2, :<=, 2382, hw.name
    end
  end
end
