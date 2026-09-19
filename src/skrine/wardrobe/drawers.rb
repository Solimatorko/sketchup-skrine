module Skrine
  module Wardrobe
    # Drawer fronts and boxes (front only / wooden box / metal systems such as Blum).
    module Drawers
      METAL_SIDE_THICKNESS = 13.0

      def build_drawers(col, cell, inner:)
        cp = cell.params
        n = cp[:drawers_count]
        if inner
          g = p[:inner_drawer_side_gap]
          rect = Core::Box.new(x: col.x0 + g, y: f[:corpus_y0] + p[:inner_drawer_setback], z: cell.z0,
                               dx: col.w - 2 * g, dy: p[:front_thickness], dz: cell.h)
        else
          rect = front_rect(col, cell.z0, cell.z0 + cell.h, cell.top_boundary, cell.bottom_boundary, col.doors[:mount])
        end
        gv = p[:front_gap_v]
        heights = drawer_front_heights(cp, n, rect.dz, gv, col, cell)
        return unless heights

        z_top = rect.z2
        heights.each_with_index do |h, k|
          fbox = Core::Box.new(x: rect.x, y: rect.y, z: z_top - h, dx: rect.dx, dy: rect.dy, dz: h)
          name = "#{inner ? 'Vnút. zásuvka' : 'Zásuvka'} S#{col.index}/P#{cell.index}-#{k + 1}"
          unless inner
            fbox = apply_handle(fbox, col.handle, col)
            record_drilled_handle(col.handle, "Čelo #{name}")
          end
          add_drawer_front(fbox, name, col)
          build_drawer_box(col, cell, fbox, name)
          z_top -= h + gv
        end
      end

      def drawer_front_heights(cp, n, span, gv, col, cell)
        custom = cp[:drawer_heights].to_s.split(',').map(&:strip).reject(&:empty?).map(&:to_f)
        if custom.empty?
          h = (span - (n - 1) * gv) / n
          return layout.error("S#{col.index}/P#{cell.index}: čelá zásuviek by mali len #{h.round} mm") if h < 40

          return Array.new(n, h)
        end
        return layout.error("S#{col.index}/P#{cell.index}: zadaných #{custom.size} výšok, zásuviek je #{n}") if custom.size != n

        total = custom.sum + (n - 1) * gv
        if (total - span).abs > 0.5
          return layout.error("S#{col.index}/P#{cell.index}: súčet výšok čiel + špár je #{total.round(1)} mm, k dispozícii je #{span.round(1)} mm")
        end

        custom
      end

      def add_drawer_front(box, name, col)
        vertical = p[:front_grain] == :vertical
        layout.part(
          name: "Čelo #{name}", category: :front, material: :front,
          length: vertical ? box.dz : box.dx, width: vertical ? box.dx : box.dz, thickness: p[:front_thickness],
          edges: edges_for(p[:edge_front], :long_a), box: box, meta: { column: col.index }
        )
      end

      def drawer_system
        key = p[:drawer_system]
        { key: key }.merge(p[:drawer_systems][key])
      end

      # Largest nominal runner length that fits the usable depth behind the
      # front/box start +y0+, or nil.
      def nominal_length(sys, y0)
        lengths = sys[:lengths].to_s.split(',').map(&:to_f).select(&:positive?)
        avail = f[:inner_d] - (y0 - f[:corpus_y0]) - p[:drawer_depth_reserve]
        lengths.select { |l| l <= avail }.max
      end

      def build_drawer_box(col, cell, fbox, name)
        sys = drawer_system
        y0 = fbox.y2 + 2
        nl = nominal_length(sys, y0)
        return layout.error("#{name}: žiadna nominálna dĺžka výsuvu (#{sys[:lengths]}) sa nezmestí do hĺbky #{f[:inner_d].round} mm") unless nl

        z0 = [fbox.z, cell.z0].max + 12
        # Vertical room actually available in the cavity for this drawer's box,
        # as opposed to the (possibly taller, due to overlay overlap) front.
        share_h = [fbox.z2, cell.z0 + cell.h].min - z0
        case sys[:box]
        when :wood then build_wood_box(col, fbox, name, sys, nl, y0, z0, share_h)
        when :metal then build_metal_box(col, fbox, name, sys, nl, y0, z0, share_h)
        else
          layout.hardware_item(kind: :slide, name: "Výsuv #{sys[:label]} NL#{nl.round}", qty: 1, unit: :pair, meta: { drawer: name })
        end
      end

      def build_wood_box(col, fbox, name, sys, nl, y0, z0, share_h)
        t = p[:drawer_box_thickness]
        tb = p[:drawer_bottom_thickness]
        gr = p[:drawer_bottom_groove]
        outer_w = col.w - 2 * sys[:side_clearance]
        h = [fbox.dz - sys[:height_clearance], share_h - sys[:height_clearance]].min
        return layout.error("#{name}: drevený box by mal výšku len #{h.round} mm") if h < 40

        edges = edges_for(p[:edge_drawer_box], :long_a)
        x0 = col.x0 + sys[:side_clearance]
        [[x0, 'Ľ'], [x0 + outer_w - t, 'P']].each do |x, s|
          layout.part(name: "Box bok #{s} #{name}", category: :drawer_box, material: :drawer_box, length: nl, width: h,
                      thickness: t, edges: edges, box: Core::Box.new(x: x, y: y0, z: z0, dx: t, dy: nl, dz: h), meta: { drawer: name })
        end
        inner_w = outer_w - 2 * t
        layout.part(name: "Box zadný #{name}", category: :drawer_box, material: :drawer_box, length: inner_w, width: h, thickness: t,
                    edges: edges, box: Core::Box.new(x: x0 + t, y: y0 + nl - t, z: z0, dx: inner_w, dy: t, dz: h), meta: { drawer: name })
        layout.part(name: "Box predný #{name}", category: :drawer_box, material: :drawer_box, length: inner_w, width: h, thickness: t,
                    edges: edges, box: Core::Box.new(x: x0 + t, y: y0, z: z0, dx: inner_w, dy: t, dz: h), meta: { drawer: name })
        bw = inner_w + 2 * gr
        bl = nl - 2 * t + 2 * gr
        layout.part(name: "Box dno #{name}", category: :drawer_box, material: :back, length: bl, width: bw, thickness: tb,
                    edges: edges_for(:none), grain: :none,
                    box: Core::Box.new(x: x0 + t - gr, y: y0 + t - gr, z: z0 + 10, dx: bw, dy: bl, dz: tb), meta: { drawer: name })
        layout.hardware_item(kind: :slide, name: "Výsuv drevený box NL#{nl.round}", qty: 1, unit: :pair, meta: { drawer: name })
      end

      def build_metal_box(col, fbox, name, sys, nl, y0, z0, share_h)
        classes = sys[:heights].to_s.split(',').map { |s| k, v = s.split(':'); [k.to_s.strip, v.to_f] }
                     .select { |_, v| v.positive? }.sort_by(&:last)
        return layout.error("#{name}: systém #{sys[:label]} nemá výškové triedy") if classes.empty?

        # A class must both fit under the front (+ its minimum extra reveal) and
        # fit its own height plus a 5 mm top clearance inside the cavity share.
        usable = classes.select { |_, hgt| hgt + sys[:front_min_extra] <= fbox.dz && hgt + 5 <= share_h }
        cls, ch = usable.last || classes.first
        layout.warn("#{name}: čelo #{fbox.dz.round} mm je nižšie než najnižšia trieda #{cls} (#{ch} mm)") if usable.empty?

        tb = p[:metal_box_bottom_thickness]
        tback = p[:drawer_box_thickness]
        bw = col.w - sys[:bottom_width_deduction]
        bl = nl - sys[:bottom_length_deduction]
        layout.part(name: "Dno #{name}", category: :drawer_box, material: :drawer_box, length: bw, width: bl, thickness: tb,
                    edges: edges_for(:none), grain: :none,
                    box: Core::Box.new(x: col.x0 + (col.w - bw) / 2, y: y0, z: z0, dx: bw, dy: bl, dz: tb),
                    meta: { drawer: name, system: sys[:label], class: cls })
        back_w = col.w - sys[:back_width_deduction]
        back_h = ch - sys[:back_height_deduction]
        layout.part(name: "Zadný diel #{name}", category: :drawer_box, material: :drawer_box, length: back_w, width: back_h,
                    thickness: tback, edges: edges_for(:none), grain: :none,
                    box: Core::Box.new(x: col.x0 + (col.w - back_w) / 2, y: y0 + bl - tback, z: z0 + tb, dx: back_w, dy: tback, dz: back_h),
                    meta: { drawer: name, system: sys[:label], class: cls })
        [col.x0 + sys[:side_clearance], col.x0 + col.w - sys[:side_clearance] - METAL_SIDE_THICKNESS].each do |x|
          layout.hardware_item(kind: :drawer_side, name: "#{sys[:label]} #{cls} bok", qty: 1, unit: :pcs,
                               box: Core::Box.new(x: x, y: y0, z: z0, dx: METAL_SIDE_THICKNESS, dy: nl, dz: ch), meta: { drawer: name })
        end
        layout.hardware_item(kind: :slide, name: "#{sys[:label]} #{cls} NL#{nl.round} (sada)", qty: 1, unit: :set, meta: { drawer: name })
      end
    end
  end
end
