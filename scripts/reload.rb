# Reloads the plugin sources into a running SketchUp (Ruby Console):
#   load '/Users/milos/Git/sketchup-skrine/scripts/reload.rb'
root = File.expand_path('../src/skrine', __dir__)
if defined?(Skrine::SU::Dialog)
  d = Skrine::SU::Dialog.instance_variable_get(:@instance)
  d&.dialog&.close rescue nil
  Skrine::SU::Dialog.instance_variable_set(:@instance, nil)
end
%w[version core/param_schema core/box core/part core/hardware core/layout core/sizing core/registry
   data/drawer_systems wardrobe/params wardrobe/corpus wardrobe/columns wardrobe/fronts wardrobe/drawers
   wardrobe/extras wardrobe/model export/cutlist sketchup/units sketchup/storage sketchup/builder
   sketchup/selection sketchup/commands sketchup/presets sketchup/cutlist_command ui/dialog].each do |f|
  load File.join(root, "#{f}.rb")
end
puts "Skrine reloaded (#{Skrine::VERSION})"
