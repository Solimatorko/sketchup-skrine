require_relative '../core/layout'
require_relative '../core/sizing'
require_relative 'params'
require_relative 'corpus'
require_relative 'columns'
require_relative 'fronts'
require_relative 'drawers'
require_relative 'extras'

module Skrine
  module Wardrobe
    # Pure-Ruby wardrobe generator: params -> Core::Layout (mm). No SketchUp API.
    class Model
      include Corpus
      include Columns
      include Fronts
      include Drawers
      include Extras

      attr_reader :p, :f

      def initialize(params)
        @p = Params::SCHEMA.merge_defaults(params)
      end

      def layout
        @layout = Core::Layout.new
        Params::SCHEMA.validate(@p).each { |e| @layout.error(e) }
        return @layout unless @layout.valid?

        @f = compute_frame
        check_frame
        return @layout unless @layout.valid?

        build_corpus
        build_base
        build_strips
        build_back
        build_columns
        build_extras
        @layout.info.merge!(
          corpus_w: @f[:corpus_w].round(1), corpus_h: @f[:corpus_h].round(1), corpus_d: @f[:corpus_d].round(1),
          inner_w: @f[:inner_w].round(1), inner_h: @f[:inner_h].round(1), inner_d: @f[:inner_d].round(1)
        )
        @layout
      rescue Core::Sizing::Error => e
        @layout.error(e.message)
        @layout
      end

      # Edge flags from a rule (:none / :front / :all); +visible+ is the key of
      # the single visible edge used by the :front rule.
      def edges_for(rule, visible = :long_a)
        e = { long_a: false, long_b: false, short_a: false, short_b: false }
        case rule.to_s.to_sym
        when :all then e.transform_values! { true }
        when :front then e[visible] = true
        end
        e
      end

      def column_doors(col_params)
        col_params[:doors_override] ? col_params[:doors] : @p[:doors]
      end

      def column_handle(col_params)
        col_params[:handle_override] ? col_params[:handle] : @p[:handle]
      end

      def drilling_spec
        { pitch: @p[:drill_pitch], offset_front: @p[:drill_offset_front], offset_back: @p[:drill_offset_back],
          start: @p[:drill_start], end_offset: @p[:drill_end_offset] }
      end

      private

      def compute_frame
        f = {}
        f[:t_top] = p[:top][:thickness]
        f[:t_bot] = p[:bottom][:thickness]
        f[:fronts_protrude] = fronts_protrude
        f[:corpus_x0] = p[:gap_left].to_f
        f[:corpus_w] = p[:width] - p[:gap_left] - p[:gap_right]
        f[:base_h] = p[:base_type] == :floor ? 0.0 : p[:base_height].to_f
        f[:corpus_z0] = f[:base_h]
        f[:corpus_h] = p[:height] - f[:base_h] - p[:gap_top]
        f[:corpus_y0] = f[:fronts_protrude]
        f[:corpus_d] = p[:depth_includes_fronts] ? p[:depth] - f[:fronts_protrude] : p[:depth].to_f
        f[:body_d] = f[:corpus_d] - (p[:back_mode] == :overlay ? p[:back_thickness] : 0)
        f[:inner_x0] = f[:corpus_x0] + p[:side_left][:thickness]
        f[:inner_w] = f[:corpus_w] - p[:side_left][:thickness] - p[:side_right][:thickness]
        f[:inner_z0] = f[:corpus_z0] + f[:t_bot]
        f[:inner_h] = f[:corpus_h] - f[:t_bot] - f[:t_top]
        f[:back_clearance] = case p[:back_mode]
                             when :groove then p[:groove_offset] + p[:back_thickness]
                             when :inset then p[:back_inset_thickness]
                             else 0.0
                             end
        f[:inner_d] = f[:body_d] - f[:back_clearance]
        f
      end

      def check_frame
        @layout.error("Vnútorná šírka korpusu je #{f[:inner_w].round} mm – zväčši šírku alebo zmenši odsadenia") if f[:inner_w] < 50
        @layout.error("Vnútorná výška korpusu je #{f[:inner_h].round} mm – zväčši výšku alebo zmenši spodok/odsadenie od stropu") if f[:inner_h] < 50
        @layout.error("Vnútorná hĺbka korpusu je #{f[:inner_d].round} mm") if f[:inner_d] < 50
      end

      def fronts_protrude
        return 0.0 unless any_fronts?

        mounts = p[:columns].map { |c| column_doors(c)[:mount] }
        mounts.any? { |m| m != :inset } ? p[:front_thickness].to_f : 0.0
      end

      def any_fronts?
        p[:columns].any? do |c|
          (p[:doors_enabled] && column_doors(c)[:type] != :none) || c[:cells].any? { |cell| cell[:content] == :drawers }
        end
      end
    end

    Core::Registry.register(:wardrobe, label: 'Skriňa', schema: Params::SCHEMA, model_class: Model)
  end
end
