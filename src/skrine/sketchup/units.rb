module Skrine
  module SU
    module Units
      MM_PER_INCH = 25.4

      # Millimetres -> SketchUp internal inches (Float).
      def self.mm(value)
        value.to_f / MM_PER_INCH
      end

      def self.point(x, y, z)
        Geom::Point3d.new(mm(x), mm(y), mm(z))
      end
    end
  end
end
