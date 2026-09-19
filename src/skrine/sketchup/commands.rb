require_relative 'builder'
require_relative 'selection'

module Skrine
  module SU
    module Commands
      module_function

      def new_object(type_key = :wardrobe)
        model = Sketchup.active_model
        type = Core::Registry.fetch(type_key)
        res = Builder.create(model, type.key, type.schema.defaults)
        if res[:errors].any?
          UI.messagebox("Skriňa sa nevytvorila:\n#{res[:errors].join("\n")}")
        else
          open_editor(res[:group])
        end
      end

      def edit_selected
        group = Selection.current_object(Sketchup.active_model)
        return UI.messagebox('Označ skriňu vytvorenú pluginom Skrine.') unless group

        open_editor(group)
      end

      # Skrine::SU::Dialog is required by loader.rb after this file, so it is
      # only resolved when this method actually runs (not when this file loads).
      def open_editor(group)
        Dialog.instance.open_for(group)
      end
    end
  end
end
