module Skrine
  module Wardrobe
    # Door fronts: overlay geometry, handles, hinges, lifts and open display.
    module Fronts
      # Depth the fronts of +col+ occupy in front of the cavity, i.e. how far
      # shelves/partitions must stay clear of the door/drawer-front plane.
      # Zero unless the column actually has inset doors.
      def front_clearance(col)
        return 0.0 unless p[:doors_enabled] && col.doors[:type] != :none
        return 0.0 unless col.doors[:mount] == :inset

        p[:inset_depth] + p[:front_thickness]
      end

      # Front rectangle for a column span [z0, z1] (cavity coordinates).
      def front_rect(col, z0, z1, top_boundary, bottom_boundary, mount)
        ol = overlap_h(col.left_boundary, :left, mount)
        orr = overlap_h(col.right_boundary, :right, mount)
        ot = overlap_v(top_boundary, :top, mount)
        ob = overlap_v(bottom_boundary, :bottom, mount)
        y = mount == :inset ? f[:corpus_y0] + p[:inset_depth] : f[:corpus_y0] - p[:front_thickness]
        Core::Box.new(x: col.x0 - ol, y: y, z: z0 - ob, dx: col.w + ol + orr, dy: p[:front_thickness],
                      dz: (z1 - z0) + ot + ob)
      end

      def overlap_h(boundary, side, mount)
        gh = p[:front_gap_h]
        return -gh / 2.0 if mount == :inset
        return p[:partition_thickness] / 2.0 - gh / 2.0 if boundary == :partition

        ts = side == :left ? p[:side_left][:thickness] : p[:side_right][:thickness]
        reveal = side == :left ? p[:reveal_left] : p[:reveal_right]
        mount == :overlay ? ts - reveal : ts / 2.0 - gh / 2.0
      end

      def overlap_v(boundary, side, mount)
        gv = p[:front_gap_v]
        return -gv / 2.0 if mount == :inset
        return p[:shelf_thickness] / 2.0 - gv / 2.0 if boundary == :shelf

        side == :top ? p[:top][:thickness] - p[:reveal_top] : p[:bottom][:thickness] - p[:reveal_bottom]
      end

      def build_doors(col)
        return unless p[:doors_enabled]

        d = col.doors
        return if d[:type] == :none

        runs = door_runs(col)
        runs.each_with_index do |run, ri|
          rect = front_rect(col, run.last.z0, run.first.z0 + run.first.h, run.first.top_boundary,
                            run.last.bottom_boundary, d[:mount])
          rect = apply_handle(rect, col.handle, col)
          prefix = "Dvere S#{col.index}#{runs.size > 1 ? "/#{ri + 1}" : ''}"
          case d[:type]
          when :single_left then add_door(rect, prefix, :left, col)
          when :single_right then add_door(rect, prefix, :right, col)
          when :double
            w = (rect.dx - p[:front_gap_h]) / 2.0
            add_door(Core::Box.new(x: rect.x, y: rect.y, z: rect.z, dx: w, dy: rect.dy, dz: rect.dz), "#{prefix} Ľ", :left, col)
            add_door(Core::Box.new(x: rect.x + w + p[:front_gap_h], y: rect.y, z: rect.z, dx: w, dy: rect.dy, dz: rect.dz),
                     "#{prefix} P", :right, col)
          when :flap_up then add_door(rect, "#{prefix} výklop", :top, col)
          end
        end
      end

      # Contiguous top-down runs of cells that are not external drawers.
      def door_runs(col)
        runs = []
        current = []
        col.cells.each do |cell|
          if cell.params[:content] == :drawers
            runs << current unless current.empty?
            current = []
          else
            current << cell
          end
        end
        runs << current unless current.empty?
        runs
      end

      def add_door(box, name, hinge, col)
        if hinge != :top && box.dx > p[:door_max_width]
          layout.warn("#{name}: šírka krídla #{box.dx.round} mm presahuje odporúčaných #{p[:door_max_width].round} mm")
        end
        vertical = p[:front_grain] == :vertical
        part = layout.part(
          name: name, category: :front, material: :front,
          length: vertical ? box.dz : box.dx, width: vertical ? box.dx : box.dz, thickness: p[:front_thickness],
          edges: edges_for(p[:edge_front], :long_a), box: box, rotation: door_rotation(box, hinge),
          meta: { column: col.index, hinge: hinge }
        )
        if hinge == :top
          layout.hardware_item(kind: :lift, name: 'Výklop (napr. Blum AVENTOS)', qty: 1, unit: :pcs, meta: { door: name })
        else
          layout.hardware_item(kind: :hinge, name: 'Pánt', qty: hinge_count(box.dz), unit: :pcs, meta: { door: name, side: hinge })
        end
        record_drilled_handle(col.handle, name)
        part
      end

      def door_rotation(box, hinge)
        return nil unless p[:door_display] == :open && p[:open_angle].positive?

        a = p[:open_angle].to_f
        case hinge
        when :left then { point: [box.x, box.y2, box.z], axis: [0, 0, 1], angle: -a }
        when :right then { point: [box.x2, box.y2, box.z], axis: [0, 0, 1], angle: a }
        when :top then { point: [box.x, box.y2, box.z2], axis: [1, 0, 0], angle: -a }
        end
      end

      # "max_height:count,..." -> count for the first entry whose max_height >= height.
      def hinge_count(height)
        table = p[:hinge_table].to_s.split(',').map { |pair| pair.split(':').map(&:to_f) }
                 .select { |e| e.size == 2 }.sort_by(&:first)
        entry = table.find { |max_h, _| height <= max_h } || table.last
        entry ? entry[1].to_i : 2
      end

      # Shrinks +rect+ for an integrated profile handle and books the profile length.
      def apply_handle(rect, handle, col)
        return rect unless handle[:type] == :profile

        ph = handle[:profile_height].to_f
        layout.hardware_item(kind: :profile, name: 'Úchytkový profil', qty: rect.dx.round(1), unit: :mm, meta: { column: col.index })
        if handle[:profile_position] == :top
          Core::Box.new(x: rect.x, y: rect.y, z: rect.z, dx: rect.dx, dy: rect.dy, dz: rect.dz - ph)
        else
          Core::Box.new(x: rect.x, y: rect.y, z: rect.z + ph, dx: rect.dx, dy: rect.dy, dz: rect.dz - ph)
        end
      end

      def record_drilled_handle(handle, front_name)
        return unless handle[:type] == :drilled

        layout.hardware_item(kind: :handle, name: "Úchytka rozteč #{handle[:hole_spacing].round}", qty: 1, unit: :pcs,
                             meta: { front: front_name, offset_edge: handle[:offset_edge], orientation: handle[:orientation] })
      end
    end
  end
end
