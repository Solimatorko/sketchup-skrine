# Regenerates docs/parameters.md from the wardrobe parameter schema:
#   ruby -Isrc scripts/gen_docs.rb
$LOAD_PATH.unshift File.expand_path('../src', __dir__)
require 'skrine/core'


# English gloss per parameter path (exact match first, then ".suffix" match).
EN = {
  'placement' => 'Where the wardrobe stands: between two walls, in a left/right corner, or free standing. Only pre-fills the wall gaps.',
  'width' => 'Overall outside width, including cover strips and wall gaps.',
  'height' => 'Overall outside height, floor to top (including the base and the gap under the ceiling).',
  'depth' => 'Overall outside depth.',
  'depth_includes_fronts' => 'When on, the fronts are inside the given depth; when off, the carcass alone is that deep.',
  'gap_left' => 'Gap between the wall and the carcass on the left.',
  'gap_right' => 'Gap between the wall and the carcass on the right.',
  'filler_left' => 'Fill the left wall gap with a filler strip.',
  'filler_right' => 'Fill the right wall gap with a filler strip.',
  'gap_top' => 'Gap between the top of the carcass and the ceiling.',
  'top_strip' => 'Cover the ceiling gap with a strip.',
  'top_strip_height' => 'Height of the top cover strip; 0 uses the whole ceiling gap.',
  'top_strip_setback' => 'How far the top strip sits behind the front plane.',
  'base_type' => 'Base: adjustable legs, a plinth board between the sides, or the carcass standing on the floor.',
  'base_height' => 'Height of the base (legs or plinth).',
  'bottom_strip' => 'Add a plinth board in front of the legs.',
  'bottom_strip_setback' => 'How far the plinth sits behind the front plane (toe kick).',
  'strip_floor_clearance' => 'Gap between the plinth and the floor.',
  'panel_thickness' => 'Default carcass panel thickness.',
  'front_thickness' => 'Thickness of doors and drawer fronts.',
  'back_thickness' => 'Thickness of the back panel (HDF).',
  'shelf_thickness' => 'Thickness of shelves.',
  'partition_thickness' => 'Thickness of vertical partitions between columns.',
  'strip_thickness' => 'Thickness of cover and filler strips.',
  'top' => 'Top panel: thickness, corner joints and recesses.',
  'bottom' => 'Bottom panel: thickness, corner joints and recesses.',
  'side_left' => 'Left side panel.',
  'side_right' => 'Right side panel.',
  'back_mode' => 'Back panel: HDF in a groove, HDF applied on the back, or a thick board inset between the sides.',
  'groove_depth' => 'Depth of the groove that holds the back panel.',
  'groove_offset' => 'Distance of the groove from the rear edge.',
  'back_inset_thickness' => 'Thickness of the inset (visible) back board.',
  'shelf_setback' => 'How far shelves sit behind the front edge.',
  'shelf_back_clearance' => 'Gap between shelves and the back panel.',
  'line_drilling' => 'Record system-32 shelf-pin drilling on sides and partitions (reported in the cut list).',
  'drill_pitch' => 'Distance between shelf-pin holes.',
  'drill_offset_front' => 'Distance of the front hole row from the front edge.',
  'drill_offset_back' => 'Distance of the rear hole row from the rear edge.',
  'drill_start' => 'Height of the first hole above the bottom.',
  'drill_end_offset' => 'Distance of the last hole below the top.',
  'front_gap_h' => 'Gap between neighbouring fronts, horizontally.',
  'front_gap_v' => 'Gap between stacked fronts, vertically.',
  'reveal_top' => 'How much shorter the front is at the top edge of the carcass.',
  'reveal_bottom' => 'How much shorter the front is at the bottom edge.',
  'reveal_left' => 'How much narrower the front is at the left side.',
  'reveal_right' => 'How much narrower the front is at the right side.',
  'inset_depth' => 'How deep inset fronts sit inside the carcass.',
  'front_grain' => 'Grain direction of fronts (affects the cut list).',
  'doors_enabled' => 'Turn doors off for an open carcass (shelving unit).',
  'doors' => 'Default door settings; a column can override them.',
  'door_display' => 'Draw doors closed or open (visual only, model side).',
  'open_angle' => 'Opening angle used when doors are drawn open.',
  'door_max_width' => 'Width above which a single door leaf gets a warning.',
  'hinge_table' => 'Hinge count per door height: "max height:count, ..." (e.g. 900:2,1600:3).',
  'handle' => 'Default handle; a column can override it.',
  'drawer_system' => 'Drawer system used for all drawers (front only, wooden box, or a Blum system).',
  'drawer_box_thickness' => 'Thickness of wooden drawer sides / metal-box back panel.',
  'drawer_bottom_thickness' => 'Thickness of the wooden drawer bottom.',
  'drawer_bottom_groove' => 'Groove depth that holds the wooden drawer bottom.',
  'metal_box_bottom_thickness' => 'Thickness of the bottom used in metal drawer boxes.',
  'drawer_depth_reserve' => 'Clearance kept behind the runner when picking its nominal length.',
  'inner_drawer_setback' => 'How far an inner drawer front sits behind the doors.',
  'inner_drawer_side_gap' => 'Side clearance of an inner drawer front.',
  'drawer_systems' => 'Editable catalogue tables of the drawer systems (verify against the current manufacturer catalogue).',
  'columns' => 'Columns from left to right; each holds cells from top to bottom.',
  'materials' => 'Materials: name (used in the cut list) and colour (used in the model).',
  'joinery' => 'Joint hardware counted for fixed joints (dowels, confirmats, cam locks).',
  'joinery_pitch' => 'Spacing used to compute how many joints a panel edge needs.',
  'wall_brackets' => 'Number of wall mounting brackets (wall-hung cabinets).',
  'edge_corpus' => 'Edge banding rule for sides, top and bottom.',
  'edge_shelf' => 'Edge banding rule for shelves and partitions.',
  'edge_front' => 'Edge banding rule for doors and drawer fronts.',
  'edge_strip' => 'Edge banding rule for cover and filler strips.',
  'edge_drawer_box' => 'Edge banding rule for wooden drawer boxes.',
  '.thickness' => 'Material thickness of this panel.',
  '.corner_left' => 'Left corner joint: inset between the sides, or overlaying the side.',
  '.corner_right' => 'Right corner joint: inset between the sides, or overlaying the side.',
  '.engagement' => 'How far the panel is let into the side panels.',
  '.front_recess' => 'How far the panel sits behind the front edge.',
  '.back_recess' => 'How far the panel stops short of the rear edge.',
  '.type' => 'Type.',
  '.mount' => 'Front mounting: overlay, half overlay or inset.',
  '.hole_spacing' => 'Handle hole spacing (centre to centre).',
  '.offset_edge' => 'Handle distance from the front edge.',
  '.orientation' => 'Handle orientation.',
  '.profile_height' => 'Height of the integrated handle profile; the front is shortened by it.',
  '.profile_position' => 'Whether the handle profile runs along the top or the bottom edge.',
  '.width_mode' => 'How the column width is given: auto, fixed mm, or a ratio of the remaining space.',
  '.width' => 'Column width value (mm or ratio, depending on the mode).',
  '.doors_override' => 'Use door settings of this column instead of the global ones.',
  '.handle_override' => 'Use a handle setting of this column instead of the global one.',
  '.cells' => 'Cells of this column, top to bottom.',
  '.height_mode' => 'How the cell height is given: auto, fixed mm, or a ratio.',
  '.height' => 'Cell height value (mm or ratio, depending on the mode).',
  '.content' => 'What the cell holds: adjustable shelves, a hanging rail, drawers, inner drawers, or nothing.',
  '.shelves_count' => 'Number of adjustable shelves in the cell.',
  '.drawers_count' => 'Number of drawers in the cell.',
  '.drawer_heights' => 'Front heights from the top, comma separated; empty spreads them evenly.',
  '.rod_offset_top' => 'Distance of the hanging rail below the top of the cell.',
  '.name' => 'Name shown in the cut list.',
  '.color' => 'Colour used in the SketchUp model (#rrggbb).',
  '.label' => 'Display name.',
  '.box' => 'Box construction: none (front only), wooden, or metal.',
  '.heights' => 'Height classes of the system: "CLASS:side height mm, ...".',
  '.lengths' => 'Nominal runner lengths (NL) in mm.',
  '.side_clearance' => 'Side clearance per side.',
  '.height_clearance' => 'Height clearance of a wooden box.',
  '.bottom_width_deduction' => 'Deducted from the inner width to get the drawer bottom width.',
  '.bottom_length_deduction' => 'Deducted from the nominal length to get the drawer bottom length.',
  '.back_width_deduction' => 'Deducted from the inner width to get the drawer back panel width.',
  '.back_height_deduction' => 'Deducted from the height class to get the drawer back panel height.',
  '.front_min_extra' => 'Minimum extra front height above the height class.'
}.freeze

def english(path)
  EN[path] || EN[".#{path.split('.').last}"] || ''
end

SCHEMA = Skrine::Core::Registry.fetch(:wardrobe).schema
OUT = File.expand_path('../docs/parameters.md', __dir__)

def fmt_default(value)
  case value
  when nil then '—'
  when true then '`true`'
  when false then '`false`'
  when Float then value == value.to_i ? "`#{value.to_i}`" : "`#{value}`"
  when String then value.empty? ? '—' : "`#{value}`"
  when Symbol then "`#{value}`"
  when Array, Hash then '(see below)'
  else "`#{value}`"
  end
end

def rows(schema, prefix = '')
  schema.params.values.map do |p|
    case p.type
    when :object
      ["| `#{prefix}#{p.key}` | object | — | #{p.label} | #{english("#{prefix}#{p.key}".gsub(/\[\]/, ''))} |"] + rows(p.item_schema, "#{prefix}#{p.key}.")
    when :list
      ["| `#{prefix}#{p.key}[]` | list | — | #{p.label} | #{english("#{prefix}#{p.key}".gsub(/\[\]/, ''))} |"] + rows(p.item_schema, "#{prefix}#{p.key}[].")
    else
      path = "#{prefix}#{p.key}"
      range = [p.min && "min #{p.min}", p.max && "max #{p.max}"].compact.join(', ')
      values = p.options ? p.options.map { |o| "`#{o}`" }.join(' · ') : ''
      notes = [english(path.gsub(/\[\]/, '')), values.empty? ? nil : "Values: #{values}", range.empty? ? nil : "Range: #{range}"].compact.reject(&:empty?).join('<br>')
      ["| `#{path}` | #{p.type}#{p.unit == 'mm' && p.type == :number ? ' (mm)' : ''} | #{fmt_default(p.default)} | #{p.label} | #{notes} |"]
    end
  end.flatten
end

groups = SCHEMA.groups.map { |g| [g.key, g.label] }.to_h
by_group = SCHEMA.params.values.group_by(&:group)

out = +<<~HEAD
  # Parameter reference

  <!-- Generated by scripts/gen_docs.rb — do not edit by hand. -->

  Every parameter of the `wardrobe` object type. All dimensions are millimetres
  (`Float`). The editor is in Slovak, so each row also shows the label you see on
  screen. Nested objects use dotted paths (`top.thickness`), list items use `[]`
  (`columns[].cells[].content`). Presets are partial JSON of exactly these keys.

HEAD

groups.each do |key, label|
  params = by_group[key] || []
  next if params.empty?

  out << "## #{label} (`#{key}`)\n\n"
  out << "| Parameter | Type | Default | Label in the editor (Slovak) | Meaning |\n|---|---|---|---|---|\n"
  params.each do |p|
    sub = Skrine::Core::ParamSchema.new
    sub.instance_variable_set(:@params, { p.key => p })
    out << rows(sub).join("\n") << "\n"
  end
  out << "\n"
end

File.write(OUT, out)
puts "wrote #{OUT} (#{out.lines.size} lines)"
