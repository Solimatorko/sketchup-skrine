require_relative 'part'
require_relative 'hardware'

module Skrine
  module Core
    # Result of a generator: parts, hardware, computed info and messages.
    class Layout
      attr_reader :parts, :hardware, :warnings, :errors, :info

      def initialize
        @parts = []
        @hardware = []
        @warnings = []
        @errors = []
        @info = {}
      end

      def part(**kw)
        Part.new(**kw).tap { |p| @parts << p }
      end

      def hardware_item(**kw)
        HardwareItem.new(**kw).tap { |h| @hardware << h }
      end

      def warn(message)
        @warnings << message
        nil
      end

      def error(message)
        @errors << message
        nil
      end

      def valid?
        @errors.empty?
      end

      def find(name)
        @parts.find { |p| p.name == name }
      end

      def by_category(category)
        @parts.select { |p| p.category == category }
      end
    end
  end
end
