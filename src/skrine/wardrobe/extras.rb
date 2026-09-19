module Skrine
  module Wardrobe
    # Joinery and mounting hardware derived from the generated parts.
    module Extras
      JOINERY_LABELS = { dowels: 'Kolík', confirmat: 'Konfirmát', cam_lock: 'Excenter' }.freeze

      def build_extras
        build_joinery
        if p[:wall_brackets].positive?
          layout.hardware_item(kind: :bracket, name: 'Závesné kovanie', qty: p[:wall_brackets], unit: :pcs)
        end
      end

      def build_joinery
        return if p[:joinery] == :none

        count = 0
        layout.parts.each do |part|
          case part.category
          when :corpus then count += 2 * per_joint(part.width) if %w[Strop Dno].include?(part.name)
          when :partition then count += 2 * per_joint(part.width)
          when :shelf then count += 2 * per_joint(part.width) unless part.meta[:adjustable]
          end
        end
        layout.hardware_item(kind: :joinery, name: JOINERY_LABELS[p[:joinery]], qty: count, unit: :pcs)
      end

      def per_joint(length)
        [2, (length / p[:joinery_pitch]).ceil].max
      end
    end
  end
end
