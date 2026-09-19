require 'json'

module Skrine
  module SU
    # Persists object type + params on the top-level group as attributes.
    module Storage
      DICT = 'Skrine'
      PART_DICT = 'Skrine::Part'
      HW_DICT = 'Skrine::Hardware'
      VERSION = 1

      # +hardware+ (Core::HardwareItem list) is stored too, because most fittings
      # (hinges, runners, joinery) are not drawn and would otherwise be lost.
      def self.write(group, type_key, params, hardware: [])
        group.set_attribute(DICT, 'type', type_key.to_s)
        group.set_attribute(DICT, 'version', VERSION)
        group.set_attribute(DICT, 'params', JSON.generate(params))
        group.set_attribute(DICT, 'hardware', JSON.generate(hardware.map(&:to_attrs)))
      end

      def self.read(group)
        return nil unless wardrobe?(group)

        type = group.get_attribute(DICT, 'type')
        params = JSON.parse(group.get_attribute(DICT, 'params') || '{}')
        { type: type.to_sym, params: params }
      end

      def self.hardware(group)
        JSON.parse(group.get_attribute(DICT, 'hardware') || '[]').map { |a| Core::HardwareItem.from_attrs(a) }
      end

      def self.wardrobe?(entity)
        entity.is_a?(Sketchup::Group) && !entity.get_attribute(DICT, 'type').nil?
      end
    end
  end
end
