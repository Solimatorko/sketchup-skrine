require 'test_helper'

class WardrobeParamsTest < Minitest::Test
  SCHEMA = Skrine::Wardrobe::Params::SCHEMA

  def test_defaults_are_valid
    assert_equal [], SCHEMA.validate(SCHEMA.defaults)
  end

  def test_default_layout_has_two_columns_with_two_cells
    d = SCHEMA.defaults
    assert_equal 2, d[:columns].size
    assert_equal %i[rod drawers], d[:columns][0][:cells].map { |c| c[:content] }
    assert_equal 600, d[:columns][0][:cells][1][:height]
    assert_equal :mm, d[:columns][0][:cells][1][:height_mode]
    assert_equal :double, d[:columns][0][:doors][:type]
  end

  def test_drawer_systems_are_editable_tables
    d = SCHEMA.defaults
    assert_equal 'Blum LEGRABOX', d[:drawer_systems][:blum_legrabox][:label]
    assert_match(/N:/, d[:drawer_systems][:blum_legrabox][:heights])
    assert_equal :blum_legrabox, d[:drawer_system]
  end

  def test_materials_have_names_and_colors
    d = SCHEMA.defaults
    assert_equal 'DTD 18 biela', d[:materials][:corpus][:name]
    assert_match(/\A#[0-9a-f]{6}\z/, d[:materials][:front][:color])
  end

  def test_json_roundtrip_keeps_symbols
    json = JSON.generate(SCHEMA.defaults)
    back = SCHEMA.merge_defaults(JSON.parse(json))
    assert_equal SCHEMA.defaults, back
  end
end
