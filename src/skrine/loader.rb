require 'json'
require_relative 'sketchup/diag'
Skrine::SU::Diag.log("loader start (#{__FILE__})")
begin
require_relative 'core'
require_relative 'sketchup/units'
require_relative 'sketchup/storage'
require_relative 'sketchup/builder'
require_relative 'sketchup/selection'
require_relative 'sketchup/commands'
require_relative 'sketchup/presets'
require_relative 'sketchup/cutlist_command'
require_relative 'ui/dialog'

module Skrine
  # SketchUp-side modules are required here (see sketchup/ and ui/).
end

module Skrine
  unless file_loaded?(__FILE__)
    menu = UI.menu('Extensions').add_submenu('Skrine')
    menu.add_item('Nová skriňa') { SU::Commands.new_object(:wardrobe) }
    menu.add_item('Nová skriňa z presetu…') { SU::Commands.new_from_preset }
    menu.add_item('Upraviť označenú skriňu') { SU::Commands.edit_selected }
    menu.add_item('Nárezový plán (označené / všetky)') { SU::CutlistCommand.run(Sketchup.active_model) }

    UI.add_context_menu_handler do |context_menu|
      group = SU::Selection.current_object(Sketchup.active_model)
      if group
        context_menu.add_separator
        context_menu.add_item('Upraviť skriňu (Skrine)') { SU::Commands.open_editor(group) }
        context_menu.add_item('Nárezový plán skrine') { SU::CutlistCommand.run(Sketchup.active_model, [group]) }
      end
    end
    file_loaded(__FILE__)
    SU::Diag.menu_registered!
    SU::Diag.log('loader done: menu registered')
    SU::Diag.schedule_selftest
  end
end
rescue StandardError, ScriptError => e
  Skrine::SU::Diag.log_exception('loader', e)
  raise
end
