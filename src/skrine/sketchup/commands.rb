require_relative 'builder'
require_relative 'selection'
require_relative 'presets'
require_relative 'units'

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
          place_next_to_existing(model, res[:group])
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
          place_next_to_existing(model, res[:group])
          open_editor(res[:group])
        end
      rescue JSON::ParserError, Errno::ENOENT, ArgumentError => e
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

      GAP_MM = 300

      # R4: a freshly built object always starts at the origin, so "Nová skriňa" /
      # "Vytvoriť novú" (gallery) would otherwise stack it on top of whatever is
      # already there. If the model already has other Skrine objects, shift the new
      # one so its bounding box starts GAP_MM to the right of the rightmost one.
      # Best-effort only: any failure here must not undo the object that was just
      # built, so it is swallowed rather than surfaced as an error.
      def place_next_to_existing(model, group)
        started = false
        others = Selection.all_objects(model) - [group]
        return if others.empty?

        max_x = others.map { |g| g.bounds.max.x }.max
        dx = (max_x + Units.mm(GAP_MM)) - group.bounds.min.x
        return if dx <= 0

        model.start_operation('Skrine: umiestnenie novej skrine', true)
        started = true
        group.transform!(Geom::Transformation.translation(Geom::Vector3d.new(dx, 0, 0)))
        model.commit_operation
      rescue StandardError
        model.abort_operation if started
      end
    end
  end
end
