require 'test_helper'

class SceneTest < Minitest::Test
  def scene(**over)
    params = wardrobe_params(**over)
    l = Skrine::Wardrobe::Model.new(params).layout
    assert l.valid?, l.errors.join('; ')
    Skrine::Export::Scene.build(l, params)
  end

  def test_size_and_kinds
    s = scene
    assert_equal({ w: 2000.0, h: 2400.0, d: 600.0 }, s[:size])
    kinds = s[:boxes].map { |b| b[:kind] }.uniq
    %w[side top bottom partition shelf back plinth door drawer_front drawer_box leg rod].each { |k| assert_includes kinds, k }
    door = s[:boxes].find { |b| b[:name] == 'Dvere S1 Ľ' }
    assert_equal 'door', door[:kind]
    assert_equal 1, door[:column]
    assert_in_delta 496.75, door[:dx]
  end

  def test_cells_and_columns
    s = scene
    assert_equal [1, 2], s[:columns].map { |c| c[:index] }
    assert_in_delta 973, s[:columns][0][:w]
    c = s[:cells].find { |x| x[:column] == 1 && x[:cell] == 2 }
    assert_equal 'drawers', c[:content]
    assert_in_delta 118, c[:z]
    assert_in_delta 600, c[:h]
  end

  def test_dims_are_editable_paths
    s = scene
    ids = s[:dims].map { |d| d[:id] }
    assert_includes ids, 'width'
    assert_includes ids, 'col-1'
    assert_includes ids, 'cell-1-1'
    col = s[:dims].find { |d| d[:id] == 'col-2' }
    assert_equal 'columns.1.width', col[:edit]
    assert_in_delta 973, col[:value]
    assert_in_delta 2400 + 50, col[:at]          # above the corpus top (gap_top 0)
    cell = s[:dims].find { |d| d[:id] == 'cell-2-1' }
    assert_equal 'columns.1.cells.0.height', cell[:edit]
    assert_equal 'z', cell[:axis]
  end

  def test_strips_and_hardware_kinds
    s = scene(gap_top: 80, top_strip: true)
    assert s[:boxes].any? { |b| b[:kind] == 'top_strip' }
    assert s[:boxes].any? { |b| b[:kind] == 'plinth' }
    assert_equal 6, s[:boxes].count { |b| b[:kind] == 'leg' }
  end

  def test_json_serialisable
    assert JSON.generate(scene).size > 1000
  end
end
