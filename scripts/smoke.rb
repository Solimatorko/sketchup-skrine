# Smoke test for the SketchUp layer. Builds every preset side by side and prints counts.
model = Sketchup.active_model
x = 0.0
Dir[File.expand_path('../presets/*.json', __dir__)].sort.each do |file|
  params = Skrine::Wardrobe::Params::SCHEMA.merge_defaults(JSON.parse(File.read(file)))
  res = Skrine::SU::Builder.create(model, :wardrobe, params)
  if res[:errors].any?
    puts "#{File.basename(file)}: ERRORS #{res[:errors].join('; ')}"
    next
  end
  g = res[:group]
  g.transform!(Geom::Transformation.translation(Geom::Vector3d.new(Skrine::SU::Units.mm(x), 0, 0)))
  x += params[:width] + 300
  parts = g.entities.grep(Sketchup::Group).count { |e| e.get_attribute('Skrine::Part', 'name') }
  puts "#{File.basename(file)}: #{parts} parts, warnings: #{res[:warnings].size}"
end
model.active_view.zoom_extents
