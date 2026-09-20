module Skrine
  module Wardrobe
    # Corpus panels, base, cover strips, fillers and back panel.
    module Corpus
      def build_corpus
        build_side(:left)
        build_side(:right)
        build_horizontal(:top)
        build_horizontal(:bottom)
      end

      def build_side(which)
        sp = which == :left ? p[:side_left] : p[:side_right]
        corner = which == :left ? :corner_left : :corner_right
        t = sp[:thickness]
        x = which == :left ? f[:corpus_x0] : f[:corpus_x0] + f[:corpus_w] - t
        plinth = p[:base_type] == :plinth
        z0 = plinth ? 0.0 : f[:corpus_z0]
        z0 = f[:corpus_z0] + f[:t_bot] if !plinth && p[:bottom][corner] == :overlay
        z1 = f[:corpus_z0] + f[:corpus_h]
        z1 -= f[:t_top] if p[:top][corner] == :overlay
        y = f[:corpus_y0] + sp[:front_recess]
        dy = f[:body_d] - sp[:front_recess] - sp[:back_recess]
        part = layout.part(
          name: which == :left ? 'Bok Ľ' : 'Bok P', category: :corpus, material: :corpus,
          length: z1 - z0, width: dy, thickness: t, edges: edges_for(p[:edge_corpus], :long_a),
          box: Core::Box.new(x: x, y: y, z: z0, dx: t, dy: dy, dz: z1 - z0), meta: { side: which }
        )
        part.meta[:drilling] = drilling_spec if p[:line_drilling]
        part
      end

      def build_horizontal(which)
        pp = p[which]
        t = pp[:thickness]
        plinth_bottom = which == :bottom && p[:base_type] == :plinth
        corner_l = plinth_bottom ? :inset : pp[:corner_left]
        corner_r = plinth_bottom ? :inset : pp[:corner_right]
        x0 = corner_l == :overlay ? f[:corpus_x0] : f[:inner_x0] - pp[:engagement]
        x1 = corner_r == :overlay ? f[:corpus_x0] + f[:corpus_w] : f[:inner_x0] + f[:inner_w] + pp[:engagement]
        z = which == :top ? f[:corpus_z0] + f[:corpus_h] - t : f[:corpus_z0]
        y = f[:corpus_y0] + pp[:front_recess]
        dy = f[:body_d] - pp[:front_recess] - pp[:back_recess]
        layout.part(
          name: which == :top ? 'Strop' : 'Dno', category: :corpus, material: :corpus,
          length: x1 - x0, width: dy, thickness: t, edges: edges_for(p[:edge_corpus], :long_a),
          box: Core::Box.new(x: x0, y: y, z: z, dx: x1 - x0, dy: dy, dz: t),
          meta: { panel: which }
        )
      end

      def build_base
        case p[:base_type]
        when :legs
          build_legs
          build_bottom_strip(f[:corpus_x0], f[:corpus_w]) if p[:bottom_strip]
        when :plinth
          build_bottom_strip(f[:inner_x0], f[:inner_w])
        end
      end

      def build_legs
        h = f[:base_h]
        return if h <= 0

        size = 40.0
        xs = [f[:corpus_x0] + 30, f[:corpus_x0] + f[:corpus_w] - 30 - size]
        # Legs are placed before partitions are laid out, so inner legs use even spacing.
        n_inner = p[:columns].size - 1
        n_inner.times { |i| xs << f[:corpus_x0] + f[:corpus_w] * (i + 1) / (n_inner + 1) - size / 2 }
        ys = [f[:corpus_y0] + 50, f[:corpus_y0] + f[:body_d] - 50 - size]
        xs.product(ys).each do |x, y|
          layout.hardware_item(kind: :leg, name: "Nožička #{h.round} mm", qty: 1, unit: :pcs,
                               box: Core::Box.new(x: x, y: y, z: 0.0, dx: size, dy: size, dz: h))
        end
      end

      def build_bottom_strip(x0, w)
        h = f[:base_h] - p[:strip_floor_clearance]
        return if h <= 0

        t = p[:strip_thickness]
        layout.part(
          name: 'Sokel', category: :strip, material: :strip, length: w, width: h, thickness: t,
          edges: edges_for(p[:edge_strip], :long_a),
          box: Core::Box.new(x: x0, y: p[:bottom_strip_setback].to_f, z: p[:strip_floor_clearance].to_f, dx: w, dy: t, dz: h),
          meta: { strip: :plinth }
        )
      end

      def build_strips
        build_top_strip if p[:top_strip]
        build_filler(:left) if p[:filler_left]
        build_filler(:right) if p[:filler_right]
      end

      def build_top_strip
        h = p[:top_strip_height].positive? ? p[:top_strip_height] : p[:gap_top]
        return layout.warn('Horná lišta: odsadenie od stropu je 0, lišta sa negeneruje') if h <= 0

        layout.warn("Horná lišta (#{h.round} mm) je vyššia než odsadenie od stropu (#{p[:gap_top].round} mm)") if h > p[:gap_top]
        t = p[:strip_thickness]
        layout.part(
          name: 'Lišta horná', category: :strip, material: :strip, length: f[:corpus_w], width: h, thickness: t,
          edges: edges_for(p[:edge_strip], :long_a),
          box: Core::Box.new(x: f[:corpus_x0], y: p[:top_strip_setback].to_f, z: f[:corpus_z0] + f[:corpus_h], dx: f[:corpus_w], dy: t, dz: h),
          meta: { strip: :top }
        )
      end

      def build_filler(which)
        gap = which == :left ? p[:gap_left] : p[:gap_right]
        return layout.warn("Zaslepovacia lišta #{which == :left ? 'vľavo' : 'vpravo'}: odsadenie od steny je 0") if gap <= 0

        t = p[:strip_thickness]
        z0 = p[:base_type] == :plinth ? 0.0 : f[:corpus_z0]
        h = f[:corpus_z0] + f[:corpus_h] - z0
        x = which == :left ? 0.0 : p[:width] - gap
        layout.part(
          name: "Lišta zaslepovacia #{which == :left ? 'Ľ' : 'P'}", category: :filler, material: :strip,
          length: h, width: gap, thickness: t, edges: edges_for(p[:edge_strip], :long_a),
          box: Core::Box.new(x: x, y: 0.0, z: z0, dx: gap, dy: t, dz: h),
          meta: { strip: :filler, side: which }
        )
      end

      def build_back
        case p[:back_mode]
        when :groove
          t = p[:back_thickness]
          g = p[:groove_depth]
          box = Core::Box.new(x: f[:inner_x0] - g, y: f[:corpus_y0] + f[:body_d] - p[:groove_offset] - t,
                              z: f[:inner_z0] - g, dx: f[:inner_w] + 2 * g, dy: t, dz: f[:inner_h] + 2 * g)
        when :overlay
          t = p[:back_thickness]
          box = Core::Box.new(x: f[:corpus_x0], y: f[:corpus_y0] + f[:body_d], z: f[:corpus_z0],
                              dx: f[:corpus_w], dy: t, dz: f[:corpus_h])
        when :inset
          t = p[:back_inset_thickness]
          box = Core::Box.new(x: f[:inner_x0], y: f[:corpus_y0] + f[:body_d] - t, z: f[:inner_z0],
                              dx: f[:inner_w], dy: t, dz: f[:inner_h])
        end
        material = p[:back_mode] == :inset ? :corpus : :back
        layout.part(name: 'Zadná stena', category: :back, material: material, length: box.dz, width: box.dx,
                    thickness: t, edges: edges_for(:none), grain: :none, box: box)
      end
    end
  end
end
