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

      def open_editor(group)
        if defined?(Skrine::SU::Dialog)
          Dialog.instance.open_for(group)
        else
          UI.messagebox('Editor ešte nie je k dispozícii (Task 12).')
        end
      end
    end
  end
end
