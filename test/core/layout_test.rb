require 'test_helper'

class LayoutTest < Minitest::Test
  Core = Skrine::Core

  def test_part_edge_code_and_attr_roundtrip
    part = Core::Part.new(name: 'Bok Ľ', category: :corpus, material: :corpus, length: 2300, width: 582, thickness: 18,
                          edges: { long_a: true, long_b: false, short_a: true, short_b: true },
                          box: Core::Box.new(x: 0, y: 18, z: 100, dx: 18, dy: 582, dz: 2300), meta: { side: :left })
    assert_equal '1D 2K', part.edge_code
    attrs = part.to_attrs
    assert_equal 'corpus', attrs['category']
    assert_kind_of String, attrs['edges']
    back = Core::Part.from_attrs(attrs)
    assert_equal :corpus, back.category
    assert_equal part.edges, back.edges
    assert_equal 'left', back.meta[:side]
    assert_nil back.box
  end

  def test_part_defaults
    part = Core::Part.new(name: 'X', category: :shelf, material: :corpus, length: 1, width: 1, thickness: 1)
    assert_equal '-', part.edge_code
    assert_equal :length, part.grain
    assert_equal({}, part.meta)
  end

  def test_layout_collects_parts_hardware_and_messages
    l = Core::Layout.new
    l.part(name: 'Strop', category: :corpus, material: :corpus, length: 1, width: 1, thickness: 18)
    l.hardware_item(kind: :hinge, name: 'Pánt', qty: 2, unit: :pcs)
    l.warn('w')
    assert l.valid?
    l.error('e')
    refute l.valid?
    assert_equal 'Strop', l.find('Strop').name
    assert_equal 1, l.by_category(:corpus).size
    assert_equal ['w'], l.warnings
    assert_equal 2, l.hardware.first.qty
  end

  def test_registry
    schema = Core::ParamSchema.new { number :w, 1, label: 'w' }
    klass = Class.new
    Core::Registry.register(:demo, label: 'Demo', schema: schema, model_class: klass)
    t = Core::Registry.fetch('demo')
    assert_equal :demo, t.key
    assert_equal klass, t.model_class
    assert_raises(Skrine::Core::Registry::UnknownType) { Core::Registry.fetch(:nope) }
  end
end
