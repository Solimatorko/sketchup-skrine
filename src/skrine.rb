require 'sketchup.rb'
require 'extensions.rb'
require_relative 'skrine/version'

module Skrine
  PLUGIN_DIR = File.join(__dir__, 'skrine')

  unless file_loaded?(__FILE__)
    extension = SketchupExtension.new('Skrine', File.join(PLUGIN_DIR, 'loader.rb'))
    extension.description = 'Parametrické skrine: generovanie, úprava a nárezový plán.'
    extension.version = VERSION
    extension.creator = 'Miloš Selečéni'
    Sketchup.register_extension(extension, true)
    file_loaded(__FILE__)
  end
end
