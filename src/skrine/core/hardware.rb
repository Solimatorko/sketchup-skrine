require 'json'

module Skrine
  module Core
    # Hardware / fittings entry. Items with a +box+ are drawn schematically.
    # unit: :pcs, :pair, :set or :mm (qty is then a length).
    HardwareItem = Struct.new(:kind, :name, :qty, :unit, :box, :meta, keyword_init: true) do
      def initialize(**kw)
        kw[:unit] ||= :pcs
        kw[:meta] ||= {}
        super(**kw)
      end

      def to_attrs
        { 'kind' => kind.to_s, 'name' => name, 'qty' => qty.to_f, 'unit' => unit.to_s, 'meta' => JSON.generate(meta) }
      end

      def self.from_attrs(a)
        new(kind: a['kind'].to_sym, name: a['name'], qty: a['qty'].to_f, unit: (a['unit'] || 'pcs').to_sym,
            meta: JSON.parse(a['meta'] || '{}', symbolize_names: true))
      end
    end
  end
end
