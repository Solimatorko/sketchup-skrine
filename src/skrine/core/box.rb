module Skrine
  module Core
    # Axis-aligned box in wardrobe-local millimetres.
    Box = Struct.new(:x, :y, :z, :dx, :dy, :dz, keyword_init: true) do
      def x2 = x + dx
      def y2 = y + dy
      def z2 = z + dz
    end
  end
end
