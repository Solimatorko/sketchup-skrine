require 'test_helper'

class ColumnModulesTest < Minitest::Test
  M = Skrine::Data::ColumnModules

  def test_every_module_builds_a_valid_column
    M::MODULES.each do |mod|
      params = M.apply(wardrobe_params, 0, mod[:key])
      l = Skrine::Wardrobe::Model.new(params).layout
      assert l.valid?, "#{mod[:key]}: #{l.errors.join('; ')}"
    end
  end

  def test_apply_replaces_cells_and_keeps_other_columns
    before = wardrobe_params
    after = M.apply(before, 1, :shelves_5)
    assert_equal %i[rod drawers], before[:columns][0][:cells].map { |c| c[:content] }   # untouched (deep copy)
    assert_equal [:shelves], after[:columns][1][:cells].map { |c| c[:content] }
    assert_equal 5, after[:columns][1][:cells][0][:shelves_count]
    assert_equal :auto, after[:columns][1][:cells][0][:height_mode]                    # CELL defaults filled
    assert_equal %i[rod drawers], after[:columns][0][:cells].map { |c| c[:content] }
  end

  def test_unknown_module_raises
    assert_raises(ArgumentError) { M.apply(wardrobe_params, 0, :nope) }
  end

  def test_to_h_is_json_friendly
    h = M.to_h
    assert_equal M::MODULES.size, h.size
    assert h.first.key?(:label)
  end
end
