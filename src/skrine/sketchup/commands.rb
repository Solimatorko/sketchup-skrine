require_relative 'builder'
require_relative 'selection'
require_relative 'presets'

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

      # Loads a preset JSON file and creates a wardrobe from it directly
      # (skips the editor's live defaults, unlike new_object).
      def new_from_preset
        path = UI.openpanel('Načítať preset', Core::PresetStore.user_dir, 'JSON|*.json||')
        new_from_preset_file(path) if path
      end

      def new_from_preset_file(file)
        params = Core::PresetStore.read(file)
        model = Sketchup.active_model
        res = Builder.create(model, :wardrobe, Core::Registry.fetch(:wardrobe).schema.merge_defaults(params))
        if res[:errors].any?
          UI.messagebox("Skriňa sa nevytvorila:\n#{res[:errors].join("\n")}")
        else
          open_editor(res[:group])
        end
      rescue JSON::ParserError, Errno::ENOENT => e
        UI.messagebox("Preset sa nedá načítať: #{e.message}")
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
