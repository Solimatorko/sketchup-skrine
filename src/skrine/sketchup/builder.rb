require_relative 'units'
require_relative 'storage'

module Skrine
  module SU
    # Turns a Core::Layout into SketchUp geometry inside a group.
    module Builder
      module_function

      def create(model, type_key, params)
        started = false
        type = Core::Registry.fetch(type_key)
        layout = type.model_class.new(params).layout
        return result(layout) unless layout.valid?

        model.start_operation("Skrine: nová #{type.label}", true)
        started = true
        group = model.active_entities.add_group
        group.name = type.label
        build_into(group, layout, params)
        Storage.write(group, type.key, params, hardware: layout.hardware)
        model.commit_operation
        model.selection.clear
        model.selection.add(group)
        result(layout).merge(group: group)
      rescue StandardError => e
        model.abort_operation if started
        { errors: ["Chyba pri generovaní: #{e.message}"], warnings: [], info: {} }
      end

      def rebuild(group, params)
        started = false
        model = nil
        data = Storage.read(group)
        raise "Skupina neobsahuje platné dáta objektu Skrine." if data.nil?

        type = Core::Registry.fetch(data[:type])
        layout = type.model_class.new(params).layout
        return result(layout) unless layout.valid?

        model = group.model
        model.start_operation("Skrine: úprava #{type.label}", true)
        started = true
        group.entities.clear!
        build_into(group, layout, params)
        Storage.write(group, type.key, params, hardware: layout.hardware)
        model.commit_operation
        result(layout)
      rescue StandardError => e
        model&.abort_operation if started
        { errors: ["Chyba pri generovaní: #{e.message}"], warnings: [], info: {} }
      end

      def result(layout)
        { errors: layout.errors, warnings: layout.warnings, info: layout.info }
      end

      def build_into(group, layout, params)
        materials = params[:materials] || {}
        layout.parts.each do |part|
          g = add_box(group.entities, part.box, part.name, material_for(group.model, part.material, materials))
          part.to_attrs.each { |k, v| g.set_attribute(Storage::PART_DICT, k, v) }
          apply_rotation(g, part.rotation) if part.rotation
        end
        layout.hardware.each do |hw|
          next unless hw.box

          g = add_box(group.entities, hw.box, hw.name, material_for(group.model, :hardware, materials))
          hw.to_attrs.each { |k, v| g.set_attribute(Storage::HW_DICT, k, v) }
        end
      end

      def add_box(entities, box, name, material)
        g = entities.add_group
        g.name = name
        pts = [
          Units.point(box.x, box.y, box.z), Units.point(box.x2, box.y, box.z),
          Units.point(box.x2, box.y2, box.z), Units.point(box.x, box.y2, box.z)
        ]
        face = g.entities.add_face(pts)
        face.reverse! if face.normal.z < 0
        face.pushpull(Units.mm(box.dz))
        g.material = material if material
        g
      end

      def apply_rotation(group, rot)
        point = Units.point(*rot[:point])
        axis = Geom::Vector3d.new(*rot[:axis])
        group.transform!(Geom::Transformation.rotation(point, axis, rot[:angle].degrees))
      end

      HARDWARE_COLOR = '#8a8a8a'.freeze

      def material_for(model, key, materials)
        name = "Skrine/#{key}"
        mat = model.materials[name] || model.materials.add(name)
        hex = key == :hardware ? HARDWARE_COLOR : (materials.dig(key.to_sym, :color) || '#ffffff')
        rgb = hex.to_s.delete('#').scan(/../).map { |c| c.to_i(16) }
        mat.color = Sketchup::Color.new(*rgb) if rgb.size == 3
        mat
      end
    end
  end
end
