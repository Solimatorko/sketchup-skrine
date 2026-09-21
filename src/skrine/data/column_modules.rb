require_relative '../wardrobe/params'

module Skrine
  module Data
    # Ready-made interior layouts for one column (top → bottom cells).
    module ColumnModules
      MODULES = [
        { key: :hanging_drawers, label: 'Vešanie + 3 zásuvky',
          cells: [{ content: :rod }, { content: :drawers, height_mode: :mm, height: 600, drawers_count: 3 }] },
        { key: :hanging_only, label: 'Dlhé vešanie', cells: [{ content: :rod }] },
        { key: :double_hanging, label: '2× krátke vešanie', cells: [{ content: :rod }, { content: :rod }] },
        { key: :shelves_5, label: '5 políc', cells: [{ content: :shelves, shelves_count: 5 }] },
        { key: :shelves_drawers, label: 'Police + 3 zásuvky',
          cells: [{ content: :shelves, shelves_count: 4 }, { content: :drawers, height_mode: :mm, height: 600, drawers_count: 3 }] },
        { key: :hanging_top_shelves, label: 'Vešanie hore, police dole',
          cells: [{ content: :rod, height_mode: :mm, height: 1100 }, { content: :shelves, shelves_count: 3 }] },
        { key: :shelves_drawers_4, label: 'Police + 4 zásuvky',
          cells: [{ content: :shelves, shelves_count: 2 }, { content: :drawers, height_mode: :mm, height: 900, drawers_count: 4 }] },
        { key: :hanging_inner_drawers, label: 'Vešanie + vnorené zásuvky',
          cells: [{ content: :rod }, { content: :inner_drawers, height_mode: :mm, height: 500, drawers_count: 2 }] },
        { key: :empty, label: 'Prázdny', cells: [{ content: :empty }] }
      ].freeze

      def self.find(key)
        MODULES.find { |m| m[:key] == key.to_s.to_sym } || raise(ArgumentError, "neznámy modul: #{key}")
      end

      # Returns a deep copy of +params+ with column +index+ (0-based) filled by the module.
      def self.apply(params, index, key)
        mod = find(key)
        copy = Marshal.load(Marshal.dump(params))
        column = copy[:columns][index] || raise(ArgumentError, "stĺpec #{index + 1} neexistuje")
        column[:cells] = mod[:cells].map { |c| Wardrobe::Params::CELL.merge_defaults(c) }
        copy
      end

      def self.to_h
        MODULES.map { |m| { key: m[:key], label: m[:label], cells: Marshal.load(Marshal.dump(m[:cells])) } }
      end
    end
  end
end
