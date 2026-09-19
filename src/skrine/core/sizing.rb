module Skrine
  module Core
    # Distributes a total length among items given as
    # {mode: :mm | :ratio | :auto, value: Numeric}. :mm is fixed, :ratio shares
    # the remainder proportionally, :auto behaves like ratio 1.
    module Sizing
      class Error < StandardError; end

      def self.resolve(specs, total)
        specs = specs.map { |s| { mode: s[:mode].to_s.to_sym, value: s[:value].to_f } }
        fixed = specs.select { |s| s[:mode] == :mm }.sum { |s| s[:value] }
        remaining = total.to_f - fixed
        raise Error, "pevné rozmery (#{fixed.round(1)} mm) presahujú dostupný priestor (#{total.round(1)} mm)" if remaining < -0.01

        weights = specs.map { |s| s[:mode] == :ratio ? s[:value] : (s[:mode] == :auto ? 1.0 : 0.0) }
        wsum = weights.sum
        if wsum <= 0 && remaining.abs > 0.01
          raise Error, "súčet pevných rozmerov (#{fixed.round(1)} mm) sa nerovná dostupnému priestoru (#{total.round(1)} mm) – pridaj položku v režime auto"
        end

        specs.each_with_index.map do |s, i|
          s[:mode] == :mm ? s[:value] : (wsum.positive? ? remaining * weights[i] / wsum : 0.0)
        end
      end

      def self.positions(sizes, separator, origin = 0.0)
        pos = origin.to_f
        sizes.map do |s|
          entry = [pos, s]
          pos += s + separator
          entry
        end
      end
    end
  end
end
