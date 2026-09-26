require 'sketchup.rb'
require 'extensions.rb'
require_relative 'skrine/version'
require_relative 'skrine/sketchup/diag'

module Skrine
  PLUGIN_DIR = File.join(__dir__, 'skrine')

  unless file_loaded?(__FILE__)
    extension = SketchupExtension.new('Skrine', File.join(PLUGIN_DIR, 'loader.rb'))
    extension.description = 'Parametrické skrine: generovanie, úprava a nárezový plán.'
    extension.version = VERSION
    extension.creator = 'Miloš Selečéni'
    Sketchup.register_extension(extension, true)
    SU::Diag.log("extension registered (#{VERSION}); loader runs only when it is enabled in Extension Manager")
    file_loaded(__FILE__)
  end
end
