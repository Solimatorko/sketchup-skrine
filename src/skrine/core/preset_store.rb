require 'json'
require 'fileutils'

module Skrine
  module Core
    # Preset files: built-in (repo presets/) and user-saved (per-user directory).
    module PresetStore
      NAME_KEY = '_name'.freeze

      def self.builtin_dir
        [File.expand_path('../../../presets', __dir__), File.expand_path('../presets', __dir__)].find { |d| Dir.exist?(d) }
      end

      def self.user_dir
        if RUBY_PLATFORM.include?('darwin')
          File.join(Dir.home, 'Library', 'Application Support', 'Skrine', 'presets')
        else
          File.join(Dir.home, '.skrine', 'presets')
        end
      end

      # [{file:, name:, params:}] – built-in first, then user presets; unreadable files are skipped.
      def self.all(user_dir: self.user_dir)
        dirs = [builtin_dir, user_dir].compact.select { |d| Dir.exist?(d) }
        dirs.flat_map do |dir|
          Dir[File.join(dir, '*.json')].sort.map do |file|
            raw = JSON.parse(File.read(file, encoding: 'UTF-8'))
            name = raw[NAME_KEY] || humanize(File.basename(file, '.json'))
            { file: file, name: name, params: raw.reject { |k, _| k == NAME_KEY } }
          rescue JSON::ParserError
            nil
          end
        end.compact
      end

      # True iff +file+ resolves to a *.json file inside builtin_dir or +user_dir+ –
      # guards read against being pointed at an arbitrary path on disk (e.g. from a
      # dialog callback or the dev server). Resolves symlinks on both sides (the repo
      # itself is often symlinked into SketchUp's Plugins folder) so a legitimate
      # preset reached through a symlink isn't rejected, and symlink tricks can't
      # sneak a path outside the allowed folders past the plain-string comparison.
      def self.allowed?(file, user_dir: self.user_dir)
        path = File.exist?(file) ? File.realpath(file) : File.expand_path(file)
        return false unless path.end_with?('.json')

        [builtin_dir, user_dir].compact.select { |d| Dir.exist?(d) }
                                .any? { |dir| path.start_with?("#{File.realpath(dir)}#{File::SEPARATOR}") }
      end

      def self.read(file, user_dir: self.user_dir)
        raise ArgumentError, "preset mimo povolených priečinkov: #{file}" unless allowed?(file, user_dir: user_dir)

        JSON.parse(File.read(file, encoding: 'UTF-8')).reject { |k, _| k == NAME_KEY }
      end

      def self.save_named(params, name, user_dir: self.user_dir)
        FileUtils.mkdir_p(user_dir)
        path = File.join(user_dir, "#{slug(name)}.json")
        data = { NAME_KEY => name }.merge(stringify(params))
        File.write(path, JSON.pretty_generate(data))
        path
      end

      def self.humanize(basename)
        basename.tr('-_', '  ').strip.capitalize
      end

      def self.slug(name)
        ascii = name.unicode_normalize(:nfkd).encode('ASCII', replace: '').downcase
        ascii.gsub(/[^a-z0-9]+/, '-').gsub(/\A-|-\z/, '')
      end

      def self.stringify(obj)
        case obj
        when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify(v) }
        when Array then obj.map { |v| stringify(v) }
        when Symbol then obj.to_s
        else obj
        end
      end
    end
  end
end
