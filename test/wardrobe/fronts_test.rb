require 'test_helper'

class FrontsTest < Minitest::Test
  def test_double_overlay_doors_with_profile_handle
    l = wardrobe
    left = l.find('Dvere S1 Ľ')
    right = l.find('Dvere S1 P')
    # column 1: x0 18, w 973; overlap left side 18-2=16, partition 9-1.5=7.5 -> width 996.5, split (996.5-3)/2
    assert_box left, x: 2, y: 0, z: 728.5, dx: 496.75, dy: 18, dz: 1639.5
    assert_box right, x: 501.75, y: 0, z: 728.5, dx: 496.75, dy: 18, dz: 1639.5
    assert_equal 1639.5, left.length          # vertical grain
    assert_equal 496.75, left.width
    assert_equal '2D 2K', left.edge_code
    assert_equal :left, left.meta[:hinge]
    assert_nil left.rotation
  end

  def test_hinges_and_profile_hardware
    l = wardrobe
    hinges = l.hardware.select { |h| h.kind == :hinge }
    assert_equal 4, hinges.first.qty                       # 1639.5 mm -> 2100:4
    assert_equal 16, hinges.sum(&:qty)                     # 4 doors
    profile = l.hardware.select { |h| h.kind == :profile }
    assert_in_delta 996.5, profile.first.qty
    assert_equal :mm, profile.first.unit
  end

  def test_hinge_count_table
    m = Skrine::Wardrobe::Model.new(wardrobe_params)
    m.layout
    assert_equal 2, m.hinge_count(800)
    assert_equal 3, m.hinge_count(1600)
    assert_equal 5, m.hinge_count(2500)
  end

  def test_single_door_warns_when_too_wide
    l = wardrobe(doors: { type: :single_left, mount: :overlay })
    door = l.find('Dvere S1')
    assert_in_delta 996.5, door.box.dx
    assert l.warnings.any? { |w| w.include?('Dvere S1') && w.include?('600') }
  end

  def test_inset_doors_sit_inside_the_corpus
    l = wardrobe(doors: { type: :double, mount: :inset })
    assert_in_delta 0, l.find('Bok Ľ').box.y                 # fronts do not protrude
    door = l.find('Dvere S1 Ľ')
    # x: 18 + 1.5 ; total width 973 - 3 ; height 1646 - 3 - 30 profile ; y = inset_depth
    assert_box door, x: 19.5, y: 2, z: 737.5, dx: 483.5, dy: 18, dz: 1613
  end

  def test_half_overlay_on_outer_side
    l = wardrobe(doors: { type: :single_left, mount: :half_overlay })
    door = l.find('Dvere S1')
    assert_in_delta 18 - 9 + 1.5, door.box.x                 # side overlap t/2 - gap/2 = 7.5
    assert_in_delta 973 + 7.5 + 7.5, door.box.dx
  end

  def test_doors_disabled_gives_open_corpus_but_keeps_drawer_fronts
    l = wardrobe(doors_enabled: false)
    assert_nil l.find('Dvere S1 Ľ')
    assert l.parts.any? { |pt| pt.name.start_with?('Čelo Zásuvka S1') }
    assert_in_delta 18, l.find('Bok Ľ').box.y
  end

  def test_flap_door_uses_lift_hardware_and_top_hinge
    l = wardrobe(doors: { type: :flap_up, mount: :overlay })
    door = l.find('Dvere S1 výklop')
    assert_equal :top, door.meta[:hinge]
    assert l.hardware.any? { |h| h.kind == :lift }
    assert_empty l.warnings.select { |w| w.include?('Dvere S1') }
  end

  def test_open_display_adds_rotation
    l = wardrobe(door_display: :open, open_angle: 90)
    left = l.find('Dvere S1 Ľ')
    assert_equal [0, 0, 1], left.rotation[:axis]
    assert_equal(-90.0, left.rotation[:angle])
    assert_in_delta 2, left.rotation[:point][0]
    right = l.find('Dvere S1 P')
    assert_equal 90.0, right.rotation[:angle]
    assert_in_delta 998.5, right.rotation[:point][0]
  end

  def test_drawer_cell_splits_doors_into_runs
    cols = [{ cells: [{ content: :shelves }, { content: :drawers, height_mode: :mm, height: 400 }, { content: :shelves }] }]
    l = wardrobe(columns: cols, doors: { type: :single_left, mount: :overlay })
    assert l.find('Dvere S1/1')
    assert l.find('Dvere S1/2')
  end

  def test_drilled_handles_are_counted_per_door
    l = wardrobe(handle: { type: :drilled, hole_spacing: 128 })
    handles = l.hardware.select { |h| h.kind == :handle }
    assert_equal 4 + 6, handles.sum(&:qty)                   # 4 doors + 6 drawer fronts
    assert_empty l.hardware.select { |h| h.kind == :profile }
    assert_in_delta 1669.5, l.find('Dvere S1 Ľ').box.dz     # no profile reduction
  end

  def test_column_override_of_doors
    cols = wardrobe_params[:columns]
    cols[1] = cols[1].merge(doors_override: true, doors: { type: :none, mount: :overlay })
    l = wardrobe(columns: cols)
    assert l.find('Dvere S1 Ľ')
    assert_nil l.find('Dvere S2 Ľ')
  end
end
