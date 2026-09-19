require 'json'

module Skrine
  module SU
    module Presets
      # Repo-level presets/ (works with the dev symlink; packaged builds copy presets next to src).
      DIR = [File.expand_path('../../../presets', __dir__), File.expand_path('../presets', __dir__)].find { |d| Dir.exist?(d) }

      def self.save(json)
        path = UI.savepanel('Uložiť preset', DIR, 'skrina.json')
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
