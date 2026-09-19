module Skrine
  module Wardrobe
    # Columns (vertical modules) and their cells (horizontal modules).
    module Columns
      Column = Struct.new(:index, :x0, :w, :left_boundary, :right_boundary, :params, :doors, :handle, :cells,
                          keyword_init: true)
      Cell = Struct.new(:index, :z0, :h, :top_boundary, :bottom_boundary, :params, keyword_init: true)

      def build_columns
        cols = p[:columns]
        return layout.error('Skriňa musí mať aspoň jeden stĺpec') if cols.empty?

        tp = p[:partition_thickness]
        widths = Core::Sizing.resolve(cols.map { |c| { mode: c[:width_mode], value: c[:width] } },
                                      f[:inner_w] - (cols.size - 1) * tp)
        layout.info[:columns] = []
        Core::Sizing.positions(widths, tp, f[:inner_x0]).each_with_index do |(x0, w), i|
          col = Column.new(index: i + 1, x0: x0, w: w,
                           left_boundary: i.zero? ? :side : :partition,
                           right_boundary: i == cols.size - 1 ? :side : :partition,
                           params: cols[i], doors: column_doors(cols[i]), handle: column_handle(cols[i]), cells: [])
          if w < 50
            layout.error("Stĺpec #{col.index}: šírka #{w.round(1)} mm je príliš malá")
            next
          end

          build_cells(col)
          build_partition(col) if i < cols.size - 1
          build_doors(col)
          layout.info[:columns] << {
            index: col.index, inner_w: w.round(1),
            cells: col.cells.map { |c| { index: c.index, inner_h: c.h.round(1), content: c.params[:content] } }
          }
        end
      end

      def build_partition(col)
        tp = p[:partition_thickness]
        dy = f[:inner_d]
        part = layout.part(
          name: "Priečka #{col.index}", category: :partition, material: :corpus,
          length: f[:inner_h], width: dy, thickness: tp, edges: edges_for(p[:edge_shelf], :long_a),
          box: Core::Box.new(x: col.x0 + col.w, y: f[:corpus_y0], z: f[:inner_z0], dx: tp, dy: dy, dz: f[:inner_h]),
          meta: { column: col.index }
        )
        part.meta[:drilling] = drilling_spec if p[:line_drilling]
        part
      end

      def build_cells(col)
        cells = col.params[:cells]
        return layout.error("Stĺpec #{col.index}: musí mať aspoň jedno pole") if cells.empty?

        ts = p[:shelf_thickness]
        heights = Core::Sizing.resolve(cells.map { |c| { mode: c[:height_mode], value: c[:height] } },
                                       f[:inner_h] - (cells.size - 1) * ts)
        z1 = f[:inner_z0] + f[:inner_h]
        cells.each_with_index do |cp, i|
          h = heights[i]
          cell = Cell.new(index: i + 1, z0: z1 - h, h: h,
                          top_boundary: i.zero? ? :panel : :shelf,
                          bottom_boundary: i == cells.size - 1 ? :panel : :shelf, params: cp)
          col.cells << cell
          build_cell_content(col, cell)
          shelf_part(col, cell.z0 - ts, "Polica pevná S#{col.index}/#{cell.index}") unless i == cells.size - 1
          z1 = cell.z0 - ts
        end
      end

      def shelf_part(col, z, name, adjustable: false)
        y = f[:corpus_y0] + p[:shelf_setback]
        dy = f[:inner_d] - p[:shelf_setback] - p[:shelf_back_clearance]
        layout.part(
          name: name, category: :shelf, material: :corpus, length: col.w, width: dy, thickness: p[:shelf_thickness],
          edges: edges_for(p[:edge_shelf], :long_a),
          box: Core::Box.new(x: col.x0, y: y, z: z, dx: col.w, dy: dy, dz: p[:shelf_thickness]),
          meta: { column: col.index, adjustable: adjustable }
        )
      end

      def build_cell_content(col, cell)
        case cell.params[:content]
        when :shelves then build_adjustable_shelves(col, cell)
        when :rod then build_rod(col, cell)
        when :drawers then build_drawers(col, cell, inner: false)
        when :inner_drawers then build_drawers(col, cell, inner: true)
        end
      end

      def build_adjustable_shelves(col, cell)
        n = cell.params[:shelves_count]
        return if n <= 0

        ts = p[:shelf_thickness]
        gap = (cell.h - n * ts) / (n + 1)
        return layout.error("S#{col.index}/P#{cell.index}: #{n} políc sa nezmestí do #{cell.h.round} mm") if gap < 20

        n.times do |k|
          shelf_part(col, cell.z0 + gap * (k + 1) + ts * k, "Polica S#{col.index}/P#{cell.index}-#{k + 1}", adjustable: true)
        end
        layout.hardware_item(kind: :shelf_support, name: 'Podpera police', qty: 4 * n, unit: :pcs)
      end

      def build_rod(col, cell)
        size = 30.0
        z = cell.z0 + cell.h - cell.params[:rod_offset_top] - size
        return layout.error("S#{col.index}/P#{cell.index}: šatníková tyč sa nezmestí do poľa") if z < cell.z0

        y = f[:corpus_y0] + f[:inner_d] / 2.0 - size / 2
        layout.hardware_item(
          kind: :rod, name: "Šatníková tyč #{col.w.round} mm", qty: 1, unit: :pcs,
          box: Core::Box.new(x: col.x0, y: y, z: z, dx: col.w, dy: size, dz: size),
          meta: { length: col.w.round(1), column: col.index, cell: cell.index }
        )
      end
    end
  end
end
