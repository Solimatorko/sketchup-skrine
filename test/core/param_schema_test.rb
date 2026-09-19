require 'test_helper'

class ParamSchemaTest < Minitest::Test
  S = Skrine::Core::ParamSchema

  INNER = S.new do
    number :thickness, 18, label: 'Hrúbka', min: 3, max: 60
    enum :corner, :inset, options: %i[inset overlay], label: 'Roh'
  end

  SCHEMA = S.new do
    group :dims, 'Rozmery' do
      number :width, 2000, label: 'Šírka', min: 200, max: 10000
      integer :count, 2, label: 'Počet', min: 1
      boolean :flag, true, label: 'Prepínač'
      string :note, '', label: 'Poznámka'
    end
    group :parts, 'Diely' do
      object :top, INNER, label: 'Strop', default: { thickness: 25 }
      list :columns, INNER, label: 'Stĺpce', default: [{ corner: :overlay }]
    end
  end

  def test_defaults_include_nested_objects_and_lists
    d = SCHEMA.defaults
    assert_equal 2000, d[:width]
    assert_equal({ thickness: 25, corner: :inset }, d[:top])
    assert_equal [{ thickness: 18, corner: :overlay }], d[:columns]
  end

  def test_merge_defaults_fills_missing_coerces_and_drops_unknown
    m = SCHEMA.merge_defaults('width' => '1500', 'count' => '3', 'flag' => 'false',
                              'top' => { 'corner' => 'overlay' }, 'columns' => [{}, { 'thickness' => 16 }],
                              'bogus' => 1)
    assert_equal 1500.0, m[:width]
    assert_equal 3, m[:count]
    assert_equal false, m[:flag]
    assert_equal({ thickness: 25, corner: :overlay }, m[:top])
    assert_equal [{ thickness: 18, corner: :inset }, { thickness: 16.0, corner: :inset }], m[:columns]
    refute m.key?(:bogus)
  end

  def test_validate_reports_range_enum_and_nested_paths
    v = SCHEMA.merge_defaults(width: 100, top: { corner: :weird }, columns: [{ thickness: 1 }])
    errors = SCHEMA.validate(v)
    assert_includes errors, 'width: min 200'
    assert_includes errors, "top.corner: neplatná hodnota 'weird'"
    assert_includes errors, 'columns[1].thickness: min 3'
  end

  def test_validate_is_empty_for_defaults
    assert_equal [], SCHEMA.validate(SCHEMA.defaults)
  end

  def test_to_h_exposes_groups_params_and_defaults
    h = SCHEMA.to_h
    assert_equal %i[dims parts], h[:groups].map { |g| g[:key] }
    width = h[:params].find { |p| p[:key] == :width }
    assert_equal :dims, width[:group]
    cols = h[:params].find { |p| p[:key] == :columns }
    assert_equal 18, cols[:item_schema][:defaults][:thickness]
    assert_equal 2000, h[:defaults][:width]
  end

  def test_duplicate_key_raises
    assert_raises(ArgumentError) { S.new { number :a, 1, label: 'a'; number :a, 2, label: 'b' } }
  end
end
