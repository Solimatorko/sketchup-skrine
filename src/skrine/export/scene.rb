module Skrine
  module Export
    # Serialisable drawing of a layout for the dialog (front/side/plan views are
    # projected in JS). Pure Ruby.
    module Scene
      module_function

      def build(layout, params)
        boxes = []
        layout.parts.each_with_index do |pt, i|
          boxes << box_hash("p#{i}", pt.box, kind_for(pt), pt.meta, pt.name, pt.category.to_s)
        end
        layout.hardware.each_with_index do |hw, i|
          next unless hw.box

          boxes << box_hash("h#{i}", hw.box, hardware_kind(hw), hw.meta, hw.name, 'hardware')
        end
        info_columns = layout.info[:columns] || []
        columns = info_columns.map { |c| { index: c[:index], x: c[:x], w: c[:inner_w] } }
        cells = info_columns.flat_map do |c|
          c[:cells].map do |cell|
            { column: c[:index], cell: cell[:index], x: cell[:x], z: cell[:z], w: cell[:w], h: cell[:h], content: cell[:content].to_s }
          end
        end
        {
          size: { w: params[:width].to_f, h: params[:height].to_f, d: params[:depth].to_f },
          boxes: boxes, columns: columns, cells: cells,
          dims: dims(params, columns, cells)
        }
      end

      def box_hash(id, b, kind, meta, name, category)
        { id: id, kind: kind, column: meta[:column], cell: meta[:cell], name: name, category: category,
          x: r(b.x), y: r(b.y), z: r(b.z), dx: r(b.dx), dy: r(b.dy), dz: r(b.dz) }
      end

      def kind_for(part)
        case part.category
        when :corpus then part.meta[:panel] ? part.meta[:panel].to_s : 'side'
        when :shelf then 'shelf'
        when :partition then 'partition'
        when :back then 'back'
        when :strip then part.meta[:strip] == :top ? 'top_strip' : 'plinth'
        when :filler then 'filler'
        when :front then part.meta[:hinge] ? 'door' : 'drawer_front'
        when :drawer_box then 'drawer_box'
        else part.category.to_s
        end
      end

      def hardware_kind(hw)
        case hw.kind
        when :rod then 'rod'
        when :leg then 'leg'
        when :drawer_side then 'drawer_box'
        else 'hardware'
        end
      end

      def dims(params, columns, cells)
        w = params[:width].to_f
        h = params[:height].to_f
        top = h - params[:gap_top].to_f
        list = [
          { id: 'width', axis: 'x', from: 0.0, to: w, at: h + 120.0, value: w, edit: 'width' },
          { id: 'height', axis: 'z', from: 0.0, to: h, at: -140.0, value: h, edit: 'height' },
          { id: 'depth', axis: 'y', from: 0.0, to: params[:depth].to_f, at: -140.0, value: params[:depth].to_f, edit: 'depth' }
        ]
        columns.each do |c|
          list << { id: "col-#{c[:index]}", axis: 'x', from: c[:x], to: r(c[:x] + c[:w]), at: top + 50.0, value: c[:w],
                    edit: "columns.#{c[:index] - 1}.width" }
        end
        cells.each do |c|
          list << { id: "cell-#{c[:column]}-#{c[:cell]}", axis: 'z', from: c[:z], to: r(c[:z] + c[:h]), at: c[:x] + 60.0,
                    value: c[:h], edit: "columns.#{c[:column] - 1}.cells.#{c[:cell] - 1}.height" }
        end
        list
      end

      def r(v)
        v.to_f.round(2)
      end
    end
  end
end
