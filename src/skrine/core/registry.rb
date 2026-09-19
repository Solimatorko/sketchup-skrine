module Skrine
  module Core
    # Registry of parametric object types (wardrobe, later top cabinet, ...).
    # model_class must respond to .new(params) and #layout -> Layout.
    module Registry
      class UnknownType < StandardError; end

      Type = Struct.new(:key, :label, :schema, :model_class, keyword_init: true)

      @types = {}

      def self.register(key, label:, schema:, model_class:)
        @types[key.to_sym] = Type.new(key: key.to_sym, label: label, schema: schema, model_class: model_class)
      end

      def self.fetch(key)
        @types.fetch(key.to_s.to_sym) { raise UnknownType, "neznámy typ objektu: #{key}" }
      end

      def self.types
        @types.values
      end
    end
  end
end
