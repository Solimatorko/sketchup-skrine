require 'cgi'

module Skrine
  module Export
    # Cut list and hardware summary built from parts/hardware (pure Ruby).
    class Cutlist
      DRAW_ONLY = %i[drawer_side].freeze
      CSV_SEP = ';'

      Row = Struct.new(:material, :material_label, :thickness, :name, :qty, :length, :width, :edge_code, :edges,
                       :grain, :category, :note, keyword_init: true)
      HwRow = Struct.new(:kind, :name, :qty, :unit, keyword_init: true)

      def initialize(parts, hardware, materials: {})
        @parts = parts
        @hardware = hardware
        @materials = materials || {}
      end

      def rows
        @rows ||= @parts
                  .group_by { |pt| [pt.material.to_s, pt.thickness.round(1), pt.length.round(1), pt.width.round(1), pt.edge_code, pt.grain.to_s] }
                  .map do |(mat, t, l, w, code, grain), pts|
                    names = pts.map(&:name).uniq
                    Row.new(material: mat, material_label: label_for(mat), thickness: t,
                            name: names.size == 1 ? names.first : "#{names.first} (+#{names.size - 1})",
                            qty: pts.size, length: l, width: w, edge_code: code, edges: pts.first.edges,
                            grain: grain, category: pts.first.category, note: drilling_note(pts.first))
                  end
                  .sort_by { |r| [r.material_label, r.thickness, -(r.length * r.width), r.name] }
      end

      def group_label(row)
        "#{row.material_label} #{fmt(row.thickness)} mm"
      end

      def by_material
        rows.group_by { |r| group_label(r) }
      end

      def edge_meters
        rows.each_with_object(Hash.new(0.0)) do |r, h|
          e = r.edges
          len = (e[:long_a] ? r.length : 0) + (e[:long_b] ? r.length : 0) + (e[:short_a] ? r.width : 0) + (e[:short_b] ? r.width : 0)
          h[group_label(r)] += len * r.qty / 1000.0
        end
      end

      def area_m2
        rows.each_with_object(Hash.new(0.0)) { |r, h| h[group_label(r)] += r.length * r.width * r.qty / 1_000_000.0 }
      end

      def hardware_rows
        @hardware.reject { |h| DRAW_ONLY.include?(h.kind) }
                 .group_by { |h| [h.kind, h.name, h.unit] }
                 .map { |(kind, name, unit), items| HwRow.new(kind: kind, name: name, qty: items.sum(&:qty), unit: unit) }
                 .sort_by { |r| [r.kind.to_s, r.name] }
      end

      def to_csv
        out = +"﻿"
        out << csv_row(%w[Materiál Hrúbka Názov Ks Dĺžka Šírka Hrany Dekor Poznámka])
        rows.each do |r|
          out << csv_row([r.material_label, fmt(r.thickness), r.name, r.qty, fmt(r.length), fmt(r.width), r.edge_code,
                           r.grain == 'none' ? 'nie' : 'áno', r.note])
        end
        out << "\n" << csv_row(%w[Druh Názov Množstvo Jednotka])
        hardware_rows.each { |h| out << csv_row([h.kind, h.name, fmt(h.qty), unit_label(h.unit)]) }
        out
      end

      # Format understood by CutList Optimizer (cutlistoptimizer.com) CSV import.
      def to_optimizer_csv
        out = +''
        out << csv_row(%w[Length Width Qty Label Enabled Grain])
        rows.each do |r|
          out << csv_row([fmt(r.length), fmt(r.width), r.qty, "#{r.name} [#{r.material_label} #{fmt(r.thickness)}]",
                           'true', r.grain == 'none' ? 'false' : 'true'])
        end
        out
      end

      def to_html
        h = +'<!DOCTYPE html><html lang="sk"><head><meta charset="utf-8"><title>Nárezový plán</title>'
        h << '<style>body{font-family:-apple-system,Helvetica,Arial,sans-serif;font-size:13px;margin:20px}'
        h << 'table{border-collapse:collapse;margin-bottom:18px;width:100%}th,td{border:1px solid #ccc;padding:4px 8px;text-align:left}'
        h << 'th{background:#f0f0f0}td.n{text-align:right}h2{margin:18px 0 6px}@media print{button{display:none}}</style></head><body>'
        h << '<h1>Nárezový plán</h1>'
        by_material.each do |label, list|
          h << "<h2>#{esc(label)}</h2><table><tr><th>Názov</th><th>Ks</th><th>Dĺžka</th><th>Šírka</th><th>Hrany</th><th>Dekor</th></tr>"
          list.each do |r|
            note = r.note ? " <small>#{esc(r.note)}</small>" : ''
            h << "<tr><td>#{esc(r.name)}#{note}</td><td class=n>#{r.qty}</td><td class=n>#{fmt(r.length)}</td><td class=n>#{fmt(r.width)}</td>"
            h << "<td>#{r.edge_code}</td><td>#{r.grain == 'none' ? 'nie' : 'áno'}</td></tr>"
          end
          h << "<tr><th colspan=6>Plocha #{fmt(area_m2[label], 2)} m² · Hranovanie #{fmt(edge_meters[label], 1)} m</th></tr></table>"
        end
        h << '<h2>Hranovanie</h2><table><tr><th>Materiál</th><th>Metre</th></tr>'
        edge_meters.each { |label, m| h << "<tr><td>#{esc(label)}</td><td class=n>#{fmt(m, 1)}</td></tr>" }
        h << '</table><h2>Kovanie</h2><table><tr><th>Druh</th><th>Názov</th><th>Množstvo</th></tr>'
        hardware_rows.each { |r| h << "<tr><td>#{r.kind}</td><td>#{esc(r.name)}</td><td class=n>#{fmt(r.qty)} #{unit_label(r.unit)}</td></tr>" }
        h << '</table></body></html>'
        h
      end

      private

      # Line-drilling (system 32) info to surface for a merged row, taken from
      # its first part; nil when that part has none.
      def drilling_note(part)
        d = part.meta[:drilling]
        return nil unless d

        "rad otvorov #{d[:pitch].to_f.round} mm"
      end

      def label_for(mat)
        name = @materials.dig(mat.to_sym, :name).to_s
        name.empty? ? mat.to_s : name
      end

      def unit_label(unit)
        { pcs: 'ks', pair: 'pár', set: 'sada', mm: 'mm' }[unit.to_sym] || unit.to_s
      end

      def fmt(num, decimals = 1)
        rounded = num.to_f.round(decimals)
        rounded == rounded.to_i ? rounded.to_i.to_s : rounded.to_s
      end

      def esc(s)
        CGI.escapeHTML(s.to_s)
      end

      def csv_row(fields)
        fields.map { |f| csv_field(f) }.join(CSV_SEP) << "\n"
      end

      # RFC 4180 style: quote a field only when it contains the separator, a
      # double quote or a line break; double up any inner quotes.
      def csv_field(value)
        s = value.to_s
        s.match?(/[;"\n\r]/) ? "\"#{s.gsub('"', '""')}\"" : s
      end
    end
  end
end
