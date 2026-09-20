# Verification script for the SketchUp Ruby Console:
#   load '/Users/milos/Git/sketchup-skrine/scripts/verify.rb'
# Loads the extension from the repo, builds every preset side by side, runs the
# cut list for the first one and writes a log to /tmp/skrine-verify.log.
LOG = '/tmp/skrine-verify.log'
lines = []
begin
  root = File.expand_path('..', __dir__)
  load File.join(root, 'src', 'skrine.rb')
  load File.join(root, 'src', 'skrine', 'loader.rb')
  lines << "loaded Skrine #{Skrine::VERSION} (Ruby #{RUBY_VERSION}, SketchUp #{Sketchup.version})"
  model = Sketchup.active_model
  x = 0.0
  groups = []
  Dir[File.join(root, 'presets', '*.json')].sort.each do |file|
    params = Skrine::Wardrobe::Params::SCHEMA.merge_defaults(JSON.parse(File.read(file)))
    res = Skrine::SU::Builder.create(model, :wardrobe, params)
    if res[:errors].any?
      lines << "#{File.basename(file)}: ERRORS #{res[:errors].join('; ')}"
      next
    end
    g = res[:group]
    g.transform!(Geom::Transformation.translation(Geom::Vector3d.new(Skrine::SU::Units.mm(x), 0, 0)))
    x += params[:width] + 300
    parts = g.entities.grep(Sketchup::Group).count { |e| e.get_attribute('Skrine::Part', 'name') }
    hw = g.entities.grep(Sketchup::Group).count { |e| e.get_attribute('Skrine::Hardware', 'name') }
    lines << "#{File.basename(file)}: #{parts} parts, #{hw} drawn hardware, warnings: #{res[:warnings].inspect}"
    groups << g
  end
  unless groups.empty?
    g = groups.first
    d = Skrine::SU::Storage.read(g)
    p2 = Skrine::Wardrobe::Params::SCHEMA.merge_defaults(d[:params]).merge(width: 2400.0, door_display: :open)
    res = Skrine::SU::Builder.rebuild(g, p2)
    lines << "rebuild 2400/open: errors=#{res[:errors].inspect} warnings=#{res[:warnings].size} inner_w=#{res[:info][:inner_w]}"
    first = g.entities.grep(Sketchup::Group).find { |e| e.attribute_dictionary('Skrine::Part') }
    dict = first.attribute_dictionary('Skrine::Part')
    lines << "attr dict responds to_h=#{dict.respond_to?(:to_h)} keys=#{dict.keys.inspect}"
    lines << "attr to_h=#{(dict.respond_to?(:to_h) ? dict.to_h : {}).inspect[0, 300]}"
    lines << "attr manual=#{dict.keys.to_h { |k| [k, dict[k]] }.inspect[0, 300]}"
    cl = Skrine::SU::CutlistCommand.collect([g])
    lines << "cutlist: #{cl.rows.size} rows, #{cl.hardware_rows.size} hardware rows, csv bytes #{cl.to_csv.bytesize}"
    cl.rows.each { |r| lines << "  row: #{r.material_label} #{r.thickness} #{r.name} x#{r.qty} #{r.length}x#{r.width}" }
    model.selection.clear
    model.selection.add(g)
    Skrine::SU::Commands.edit_selected
    lines << 'dialog opened'
  end
  model.active_view.zoom_extents
  model.active_view.write_image('/tmp/skrine-verify.png', 1600, 1000, true)
  lines << 'screenshot /tmp/skrine-verify.png'
rescue StandardError => e
  lines << "EXCEPTION: #{e.class}: #{e.message}\n#{e.backtrace.first(8).join("\n")}"
end
File.write(LOG, lines.join("\n") + "\n")
puts lines
