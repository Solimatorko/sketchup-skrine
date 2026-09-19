require_relative 'storage'
require_relative 'selection'

module Skrine
  module SU
    # Builds the cut list from what is actually in the model: parts are read from
    # the part groups' attributes (so manual edits count), hardware from the
    # object's stored list.
    module CutlistCommand
      module_function

      def run(model, groups = [])
        groups = model.selection.grep(Sketchup::Group).select { |g| Storage.wardrobe?(g) } if groups.empty?
        groups = Selection.all_objects(model) if groups.empty?
        return UI.messagebox('V modeli nie je žiadna skriňa vytvorená pluginom Skrine.') if groups.empty?

        show(collect(groups))
      end

      def collect(groups)
        parts = []
        hardware = []
        materials = {}
        groups.each do |g|
          data = Storage.read(g)
          type = Core::Registry.fetch(data[:type])
          params = type.schema.merge_defaults(data[:params])
          params[:materials].each { |k, v| materials[k] ||= v }
          part_groups(g).each do |e|
            dict = e.attribute_dictionary(Storage::PART_DICT)
            next unless dict

            # AttributeDictionary#to_h availability differs across SketchUp/Ruby
            # versions; each_pair.to_h is the portable fallback.
            attrs = dict.respond_to?(:to_h) ? dict.to_h : dict.each_pair.to_h
            parts << Core::Part.from_attrs(attrs)
          end
          hardware.concat(Storage.hardware(g))
        end
        Export::Cutlist.new(parts, hardware, materials: materials)
      end

      def show(cutlist)
        buttons = '<p><button onclick="sketchup.export_csv()">Export CSV</button> ' \
                  '<button onclick="sketchup.export_optimizer()">Export pre CutList Optimizer</button> ' \
                  '<button onclick="sketchup.export_html()">Uložiť HTML</button> ' \
                  '<button onclick="window.print()">Tlač</button></p>'
        @dialog = UI::HtmlDialog.new(dialog_title: 'Nárezový plán', preferences_key: 'sk.skrine.cutlist',
                                     width: 900, height: 720, resizable: true)
        @dialog.set_html(cutlist.to_html.sub('<h1>Nárezový plán</h1>', "<h1>Nárezový plán</h1>#{buttons}"))
        @dialog.add_action_callback('export_csv') { save_file('narezovy-plan.csv', cutlist.to_csv) }
        @dialog.add_action_callback('export_optimizer') { save_file('cutlist-optimizer.csv', cutlist.to_optimizer_csv) }
        @dialog.add_action_callback('export_html') { save_file('narezovy-plan.html', cutlist.to_html) }
        @dialog.show
      end

      def save_file(default_name, content)
        path = UI.savepanel('Uložiť', nil, default_name)
        return unless path

        File.write(path, content)
        UI.messagebox("Uložené: #{path}")
      end

      # Entities inside +group+ that may carry a part attribute dictionary. Uses
      # the real SketchUp Group grep when available; in plain Ruby (unit tests,
      # no SketchUp host) falls back to anything that can hold one.
      def self.part_groups(group)
        if defined?(Sketchup::Group)
          group.entities.grep(Sketchup::Group)
        else
          group.entities.select { |e| e.respond_to?(:attribute_dictionary) }
        end
      end
      private_class_method :part_groups
    end
  end
end
