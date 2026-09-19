require_relative 'storage'

module Skrine
  module SU
    module Selection
      # The selected Skrine object, or the one whose interior is being edited.
      def self.current_object(model)
        sel = model.selection.grep(Sketchup::Group).find { |g| Storage.wardrobe?(g) }
        return sel if sel

        model.active_path&.reverse&.find { |e| Storage.wardrobe?(e) }
      end

      def self.all_objects(model)
        model.entities.grep(Sketchup::Group).select { |g| Storage.wardrobe?(g) }
      end
    end
  end
end
