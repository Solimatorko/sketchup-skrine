require_relative '../export/scene'
require_relative '../data/column_modules'
require_relative '../core/preset_store'

module Skrine
  # Namespace for the editor page's pure-Ruby support code. Deliberately not
  # named `UI` — SketchUp defines a global `::UI` module, and a `Skrine::UI`
  # constant would shadow it for every unqualified `UI` reference inside
  # `module Skrine ... end` (menu registration, HtmlDialog, messagebox, …).
  module Editor
    # Builds what the editor page needs (scene, info, messages). Used by the
    # SketchUp dialog and by scripts/ui_server.rb, so it must stay SketchUp-free.
    module PreviewService
      module_function

      def preview(type, values)
        params = type.schema.merge_defaults(values)
        layout = type.model_class.new(params).layout
        {
          scene: layout.valid? ? Export::Scene.build(layout, params) : nil,
          info: layout.info, errors: layout.errors, warnings: layout.warnings, state: params
        }
      end

      def init_payload(type, params, result = {})
        {
          type: type.key, label: type.label, schema: type.schema.to_h, state: params, result: result,
          modules: Data::ColumnModules.to_h, preview: preview(type, params)
        }
      end

      def gallery(type, presets = Core::PresetStore.all)
        presets.map do |p|
          pv = preview(type, p[:params])
          next nil unless pv[:scene]

          { file: p[:file], name: p[:name], scene: pv[:scene] }
        end.compact
      end
    end
  end
end
