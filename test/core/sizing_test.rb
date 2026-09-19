require 'test_helper'

class SizingTest < Minitest::Test
  Sizing = Skrine::Core::Sizing

  def test_auto_splits_evenly
    assert_equal [500.0, 500.0], Sizing.resolve([{ mode: :auto, value: 1 }, { mode: :auto, value: 1 }], 1000)
  end

  def test_mm_fixed_then_ratio_shares_rest
    sizes = Sizing.resolve([{ mode: :mm, value: 400 }, { mode: :ratio, value: 1 }, { mode: :ratio, value: 2 }], 1000)
    assert_equal [400.0, 200.0, 400.0], sizes
  end

  def test_string_modes_are_accepted
    assert_equal [300.0, 700.0], Sizing.resolve([{ mode: 'mm', value: '300' }, { mode: 'auto', value: 1 }], 1000)
  end

  def test_fixed_overflow_raises
    assert_raises(Sizing::Error) { Sizing.resolve([{ mode: :mm, value: 1200 }], 1000) }
  end

  def test_all_fixed_must_match_total
    assert_raises(Sizing::Error) { Sizing.resolve([{ mode: :mm, value: 400 }], 1000) }
    assert_equal [1000.0], Sizing.resolve([{ mode: :mm, value: 1000 }], 1000)
  end

  def test_positions_with_separator
    assert_equal [[10.0, 100.0], [128.0, 200.0]], Sizing.positions([100.0, 200.0], 18, 10.0)
  end
end
