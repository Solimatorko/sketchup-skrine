# Renders a wardrobe layout as an HTML page with SVG front/side/top views.
#   /opt/homebrew/opt/ruby/bin/ruby -Isrc scripts/preview.rb [preset.json|-] [out.html]
$LOAD_PATH.unshift File.expand_path('../src', __dir__)
require 'skrine/core'
require 'json'

src = ARGV[0]
params = src && src != '-' ? JSON.parse(File.read(src)) : {}
params = Skrine::Wardrobe::Params::SCHEMA.merge_defaults(params)
layout = Skrine::Wardrobe::Model.new(params).layout
abort "ERRORS: #{layout.errors.join('; ')}" unless layout.valid?

COLORS = { corpus: '#d9c9a8', shelf: '#e8dcc0', partition: '#cdbb95', front: '#f4b8a0', back: '#f0ece0',
           strip: '#b8a27a', drawer_box: '#c8c8c8', filler: '#b8a27a' }.freeze

def svg_view(layout, params, axes, title, hide: [])
  ax, ay = axes # e.g. [:x, :z] → horizontal x, vertical z (up)
  boxes = layout.parts.reject { |p| hide.include?(p.category) }.map { |p| [p.box, COLORS[p.category] || '#999', p.name, 1.0] } +
          layout.hardware.select(&:box).map { |h| [h.box, '#7a7a7a', h.name, 0.9] }
  w = params[:width]; h = ay == :z ? params[:height] : params[:depth]
  size = { x: params[:width], y: params[:depth], z: params[:height] }
  vw = size[ax]; vh = size[ay]
  pad = 60
  scale = [ (900.0 - 2 * pad) / vw, (700.0 - 2 * pad) / vh ].min
  s = +%(<svg xmlns="http://www.w3.org/2000/svg" width="#{(vw * scale + 2 * pad).round}" height="#{(vh * scale + 2 * pad).round}" style="background:#fff;border:1px solid #ddd;margin:8px">)
  s << %(<text x="#{pad}" y="24" font-family="sans-serif" font-size="16" font-weight="bold">#{title}</text>)
  # sort so that parts further from the viewer are drawn first
  depth_axis = (%i[x y z] - [ax, ay]).first
  boxes.sort_by { |b, *_| depth_axis == :y ? -b.y : b.send(depth_axis) }.each do |b, color, name, op|
    x0 = b.send(ax); dx = b.send(:"d#{ax}"); y0 = b.send(ay); dy = b.send(:"d#{ay}")
    px = pad + x0 * scale
    py = ay == :z ? pad + (vh - y0 - dy) * scale : pad + y0 * scale
    s << %(<rect x="#{px.round(1)}" y="#{py.round(1)}" width="#{(dx * scale).round(1)}" height="#{(dy * scale).round(1)}" fill="#{color}" fill-opacity="#{op}" stroke="#333" stroke-width="0.6"><title>#{name} #{dx.round(1)}×#{dy.round(1)}</title></rect>)
  end
  s << %(<text x="#{pad}" y="#{(vh * scale + pad + 30).round}" font-family="sans-serif" font-size="12">#{vw.round} × #{vh.round} mm</text>)
  s << '</svg>'
end

html = +"<!DOCTYPE html><html><head><meta charset='utf-8'><title>Skrine preview</title></head><body style='font-family:sans-serif;margin:10px'>"
html << "<h2>#{src || 'defaults'} — #{layout.parts.size} parts, #{layout.warnings.size} warnings</h2>"
html << svg_view(layout, params, %i[x z], 'Čelný pohľad (X/Z)')
html << svg_view(layout, params, %i[x z], 'Čelný pohľad bez čiel a líšt', hide: %i[front strip filler])
html << svg_view(layout, params, %i[y z], 'Rez zboku (bez ľavého boku)', hide: []).sub('Rez zboku', 'Bočný pohľad')
html << svg_view(layout, params, %i[y z], 'Bočný pohľad (Y/Z), predok vľavo')
html << svg_view(layout, params, %i[x y], 'Pôdorys (X/Y), predok hore')
html << "<p>#{layout.warnings.join('<br>')}</p></body></html>"
out = ARGV[1] || '/tmp/skrine-preview.html'
File.write(out, html)
puts "wrote #{out}"
