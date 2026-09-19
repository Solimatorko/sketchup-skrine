module Skrine
  module Core
    # Declarative parameter schema. It is the single source of truth for
    # defaults, validation, JSON (de)serialization and the HTML form.
    class ParamSchema
      Param = Struct.new(:key, :type, :default, :label, :group, :min, :max,
                         :options, :unit, :item_schema, :help, keyword_init: true)
      Group = Struct.new(:key, :label, keyword_init: true)

      attr_reader :params, :groups

      def initialize(&block)
        @params = {}
        @groups = []
        @current_group = nil
        instance_eval(&block) if block
      end

      def group(key, label)
        @groups << Group.new(key: key, label: label)
        @current_group = key
        yield
        @current_group = nil
      end

      def number(key, default, label:, min: nil, max: nil, unit: 'mm', help: nil)
        add(key, :number, default, label, min: min, max: max, unit: unit, help: help)
      end

      def integer(key, default, label:, min: nil, max: nil, help: nil)
        add(key, :integer, default, label, min: min, max: max, help: help)
      end

      def boolean(key, default, label:, help: nil)
        add(key, :boolean, default, label, help: help)
      end

      def enum(key, default, options:, label:, help: nil)
        add(key, :enum, default, label, options: options.map(&:to_sym), help: help)
      end

      def string(key, default, label:, help: nil)
        add(key, :string, default, label, help: help)
      end

      # Nested hash with its own schema. +default+ overrides the nested defaults.
      def object(key, schema, label:, default: nil, help: nil)
        add(key, :object, default, label, item_schema: schema, help: help)
      end

      # Array of hashes sharing +schema+.
      def list(key, schema, label:, default: [], help: nil)
        add(key, :list, default, label, item_schema: schema, help: help)
      end

      def defaults
        merge_defaults({})
      end

      # Fills missing keys with defaults, coerces scalar types, drops unknown keys.
      def merge_defaults(values)
        values = symbolize(values || {})
        @params.values.each_with_object({}) do |p, h|
          v = values[p.key]
          h[p.key] = case p.type
                     when :object
                       p.item_schema.merge_defaults(symbolize(p.default || {}).merge(symbolize(v || {})))
                     when :list
                       items = v.is_a?(Array) ? v : deep_dup(p.default)
                       items.map { |item| p.item_schema.merge_defaults(item) }
                     else
                       v.nil? ? coerce(p, deep_dup(p.default)) : coerce(p, v)
                     end
        end
      end

      # Returns error strings ("path: problem"); empty when valid.
      def validate(values, path = '')
        errors = []
        @params.values.each do |p|
          v = values[p.key]
          name = "#{path}#{p.key}"
          case p.type
          when :number, :integer
            unless v.is_a?(Numeric)
              errors << "#{name}: musí byť číslo"
              next
            end
            errors << "#{name}: min #{p.min}" if p.min && v < p.min
            errors << "#{name}: max #{p.max}" if p.max && v > p.max
          when :enum
            errors << "#{name}: neplatná hodnota '#{v}'" unless p.options.include?(v.to_s.to_sym)
          when :boolean
            errors << "#{name}: musí byť áno/nie" unless [true, false].include?(v)
          when :object
            errors.concat(p.item_schema.validate(v || {}, "#{name}."))
          when :list
            if v.is_a?(Array)
              v.each_with_index { |item, i| errors.concat(p.item_schema.validate(item, "#{name}[#{i + 1}].")) }
            else
              errors << "#{name}: musí byť zoznam"
            end
          end
        end
        errors
      end

      def to_h
        {
          groups: @groups.map(&:to_h),
          params: @params.values.map { |p| param_to_h(p) },
          defaults: defaults
        }
      end

      private

      def add(key, type, default, label, **opts)
        raise ArgumentError, "duplicate param #{key}" if @params.key?(key)

        @params[key] = Param.new(key: key, type: type, default: default, label: label,
                                 group: @current_group, **opts)
        nil
      end

      def param_to_h(p)
        h = p.to_h.reject { |_, v| v.nil? }
        h[:item_schema] = p.item_schema.to_h if p.item_schema
        h
      end

      def coerce(p, v)
        case p.type
        when :number
          v.is_a?(Numeric) ? v.to_f : (Float(v.to_s, exception: false) || v)
        when :integer
          v.is_a?(Numeric) ? v.to_i : (Integer(v.to_s, exception: false) || v)
        when :enum then v.to_s.to_sym
        when :boolean then v == true || v.to_s == 'true'
        when :string then v.to_s
        else v
        end
      end

      def symbolize(h)
        return {} unless h.is_a?(Hash)

        h.each_with_object({}) { |(k, v), o| o[k.to_sym] = v }
      end

      def deep_dup(o)
        Marshal.load(Marshal.dump(o))
      end
    end
  end
end
