require 'json'

module Skrine
  module Core
    # One sheet part. +length+ runs along the grain; +edges+ marks banded
    # edges: long_a/long_b are the two edges of size +length+, short_a/short_b
    # the two of size +width+.
    Part = Struct.new(:name, :category, :material, :length, :width, :thickness,
                      :edges, :grain, :box, :rotation, :meta, keyword_init: true) do
      NO_EDGES = { long_a: false, long_b: false, short_a: false, short_b: false }.freeze

      def initialize(**kw)
        kw[:edges] = NO_EDGES.merge(kw[:edges] || {})
        kw[:grain] ||= :length
        kw[:meta] ||= {}
        super(**kw)
      end

      # "2D 1K" – D = long edges (dlhé), K = short edges (krátke).
      def edge_code
        long = [edges[:long_a], edges[:long_b]].count(true)
        short = [edges[:short_a], edges[:short_b]].count(true)
        code = []
        code << "#{long}D" if long.positive?
        code << "#{short}K" if short.positive?
        code.empty? ? '-' : code.join(' ')
      end

      def edge_length
        (edges[:long_a] ? length : 0) + (edges[:long_b] ? length : 0) +
          (edges[:short_a] ? width : 0) + (edges[:short_b] ? width : 0)
      end

      # Flat, attribute-safe representation (strings/numbers only).
      def to_attrs
        {
          'name' => name, 'category' => category.to_s, 'material' => material.to_s,
          'length' => length.to_f, 'width' => width.to_f, 'thickness' => thickness.to_f,
          'edges' => JSON.generate(edges), 'grain' => grain.to_s, 'meta' => JSON.generate(meta)
        }
      end

      def self.from_attrs(a)
        new(name: a['name'], category: a['category'].to_sym, material: a['material'].to_sym,
            length: a['length'].to_f, width: a['width'].to_f, thickness: a['thickness'].to_f,
            edges: JSON.parse(a['edges'] || '{}', symbolize_names: true),
            grain: (a['grain'] || 'length').to_sym,
            meta: JSON.parse(a['meta'] || '{}', symbolize_names: true))
      end
    end
  end
end
