require 'json'
require_relative '../sketchup/builder'
require_relative '../sketchup/storage'
require_relative '../sketchup/presets'
require_relative '../sketchup/cutlist_command'
require_relative '../sketchup/commands'
require_relative 'preview_service'

module Skrine
  module SU
    # Parameter editor window. One instance; open_for(group) rebinds it to an object.
    class Dialog
      HTML = File.join(__dir__, 'html', 'index.html')

      def self.instance
        @instance ||= new
      end

      # JSON.generate leaves U+2028/U+2029 unescaped; some WebViews treat those as
      # JS line terminators even inside a string, which breaks execute_script's
      # generated source. Escape them to the \u2028/\u2029 literal sequence so the
      # embedded JS parses them back into the characters instead of choking on them.
      # (Ruby 3.2's json gem, shipped with SketchUp 2026, has no script_safe: option.)
      def self.js_json(obj)
        JSON.generate(obj).gsub("\u2028", '\\u2028').gsub("\u2029", '\\u2029')
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
          # The page also polls via the 'ready' callback; this covers platforms
          # where the bridge is up before the page asks.
          UI.start_timer(0.5, false) { push_state }
        end
      end

      def dialog
        @dialog ||= build_dialog
      end

      private

      def build_dialog
        d = UI::HtmlDialog.new(dialog_title: 'Skrine', preferences_key: 'sk.skrine.editor', width: 1320, height: 880,
                               resizable: true, style: UI::HtmlDialog::STYLE_DIALOG)
        d.set_file(HTML)
        d.add_action_callback('ready') { push_state }
        d.add_action_callback('log') { |_, msg| puts "[Skrine] #{msg}" }
        d.add_action_callback('preview') { |_, json| send_js('Skrine.setPreview', PreviewService.preview(@type, JSON.parse(json))) }
        d.add_action_callback('apply') { |_, json| apply(JSON.parse(json)) }
        d.add_action_callback('gallery') { send_js('Skrine.showGallery', PreviewService.gallery(@type)) }
        d.add_action_callback('use_preset') { |_, file, mode| use_preset(file, mode) }
        d.add_action_callback('save_named_preset') do |_, json, name|
          path = Core::PresetStore.save_named(JSON.parse(json), name)
          UI.messagebox("Preset uložený do galérie:\n#{path}")
        end
        d.add_action_callback('save_preset') { |_, json| Presets.save(json) }
        d.add_action_callback('load_preset') { load_preset }
        d.add_action_callback('cutlist') { run_cutlist }
        d.add_action_callback('new_object') { Commands.new_object(@type ? @type.key : :wardrobe) }
        d
      end

      def send_js(function, obj)
        dialog.execute_script("#{function}(#{self.class.js_json(obj)})")
      end

      def push_state
        return unless @params

        send_js('Skrine.init', PreviewService.init_payload(@type, @params, @last || {}))
      end

      def use_preset(file, mode)
        if mode == 'new'
          Commands.new_from_preset_file(file)
        else
          apply(Core::PresetStore.read(file))
          push_state
        end
      rescue JSON::ParserError, Errno::ENOENT => e
        UI.messagebox("Preset sa nedá načítať: #{e.message}")
      end

      def apply(values)
        @params = @type.schema.merge_defaults(values)
        @last = if @group.nil? || @group.deleted?
                  { errors: ['Skriňa v modeli už neexistuje – vytvor novú (tlačidlo Nová skriňa).'], warnings: [], info: {} }
                else
                  Builder.rebuild(@group, @params)
                end
        dialog.execute_script("Skrine.setResult(#{self.class.js_json(@last)})")
      end

      def load_preset
        params = Presets.load
        return unless params

        apply(params)
        push_state
      end

      def run_cutlist
        groups = [@group].reject { |g| g.nil? || g.deleted? }
        return UI.messagebox('Skriňa v modeli už neexistuje.') if groups.empty?

        CutlistCommand.run(Sketchup.active_model, groups)
      end
    end
  end
end
