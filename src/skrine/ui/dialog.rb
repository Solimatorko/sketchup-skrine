require 'json'
require_relative '../sketchup/builder'
require_relative '../sketchup/storage'
require_relative '../sketchup/presets'

module Skrine
  module SU
    # Parameter editor window. One instance; open_for(group) rebinds it to an object.
    class Dialog
      HTML = File.join(__dir__, 'html', 'index.html')

      def self.instance
        @instance ||= new
      end

      def open_for(group)
        @group = group
        data = Storage.read(group)
        @type = Core::Registry.fetch(data[:type])
        @params = @type.schema.merge_defaults(data[:params])
        @last = nil
        if dialog.visible?
          push_state
        else
          dialog.show
        end
      end

      def dialog
        @dialog ||= build_dialog
      end

      private

      def build_dialog
        d = UI::HtmlDialog.new(dialog_title: 'Skrine', preferences_key: 'sk.skrine.editor', width: 560, height: 920,
                               resizable: true, style: UI::HtmlDialog::STYLE_DIALOG)
        d.set_file(HTML)
        d.add_action_callback('ready') { push_state }
        d.add_action_callback('apply') { |_, json| apply(JSON.parse(json)) }
        d.add_action_callback('save_preset') { |_, json| Presets.save(json) }
        d.add_action_callback('load_preset') { load_preset }
        d.add_action_callback('cutlist') { run_cutlist }
        d.add_action_callback('new_object') { Commands.new_object(@type ? @type.key : :wardrobe) }
        d
      end

      def push_state
        return unless @params

        payload = { type: @type.key, label: @type.label, schema: @type.schema.to_h, state: @params, result: @last || {} }
        dialog.execute_script("Skrine.init(#{JSON.generate(payload)})")
      end

      def apply(values)
        @params = @type.schema.merge_defaults(values)
        @last = if @group.nil? || @group.deleted?
                  { errors: ['Skriňa v modeli už neexistuje – vytvor novú (tlačidlo Nová skriňa).'], warnings: [], info: {} }
                else
                  Builder.rebuild(@group, @params)
                end
        dialog.execute_script("Skrine.setResult(#{JSON.generate(@last)})")
      end

      def load_preset
        params = Presets.load
        return unless params

        apply(params)
        push_state
      end

      def run_cutlist
        if defined?(Skrine::SU::CutlistCommand)
          CutlistCommand.run(Sketchup.active_model, [@group].compact)
        else
          UI.messagebox('Nárezový plán ešte nie je k dispozícii (Task 13).')
        end
      end
    end
  end
end
