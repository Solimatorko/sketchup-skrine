require 'json'
require 'fileutils'

module Skrine
  module SU
    module Presets
      # Built-in repo presets/ (works with the dev symlink; packaged builds copy presets next to src).
      DIR = Core::PresetStore.builtin_dir

      def self.save(json)
        FileUtils.mkdir_p(Core::PresetStore.user_dir)
        path = UI.savepanel('Uložiť preset', Core::PresetStore.user_dir, 'skrina.json')
        return unless path

        path += '.json' unless path.end_with?('.json')
        File.write(path, JSON.pretty_generate(JSON.parse(json)))
      end

      def self.load
        path = UI.openpanel('Načítať preset', DIR, 'JSON|*.json||')
        return nil unless path

        JSON.parse(File.read(path))
      rescue JSON::ParserError => e
        UI.messagebox("Preset sa nedá načítať: #{e.message}")
        nil
      end
    end
  end
end
