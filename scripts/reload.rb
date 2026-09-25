# Reloads the plugin sources into a running SketchUp (Ruby Console):
#   load '/Users/milos/Git/sketchup-skrine/scripts/reload.rb'
root = File.expand_path('../src/skrine', __dir__)
if defined?(Skrine::SU::Dialog)
  d = Skrine::SU::Dialog.instance_variable_get(:@instance)
  d&.dialog&.close rescue nil
  Skrine::SU::Dialog.instance_variable_set(:@instance, nil)
end
%w[sketchup/diag version core/param_schema core/box core/part core/hardware core/layout core/sizing core/registry
   core/preset_store data/drawer_systems wardrobe/params data/column_modules wardrobe/corpus
   wardrobe/columns wardrobe/fronts wardrobe/drawers wardrobe/extras wardrobe/model export/cutlist
   export/scene ui/preview_service sketchup/units sketchup/storage sketchup/builder sketchup/selection
   sketchup/commands sketchup/presets sketchup/cutlist_command ui/dialog].each do |f|
  load File.join(root, "#{f}.rb")
end
# The menu/context-menu block lives in loader.rb behind a file_loaded? guard, so
# loading it again registers the menu when the first (start-up) load crashed and
# is a no-op when it succeeded.
load File.expand_path('../src/skrine/loader.rb', __dir__)
menu_ok = Skrine::SU::Diag.menu_registered?
puts "Skrine reloaded (#{Skrine::VERSION}); menu #{menu_ok ? 'registered' : 'NOT registered - see /tmp/skrine-load.log'}"
