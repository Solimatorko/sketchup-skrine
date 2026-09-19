module Skrine
  module Data
    # Default drawer-system tables. Values are typical catalogue figures and are
    # editable in the dialog (Zásuvky › Tabuľky systémov); verify against the
    # manufacturer's current catalogue before ordering.
    # heights: "CLASS:side_height_mm,..." ; lengths: nominal runner lengths (NL).
    module DrawerSystems
      DEFAULTS = {
        front_only: {
          label: 'Len čelo + výsuv', box: :none, heights: '', lengths: '250,300,350,400,450,500,550,600',
          side_clearance: 0, height_clearance: 0, bottom_width_deduction: 0, bottom_length_deduction: 0,
          back_width_deduction: 0, back_height_deduction: 0, front_min_extra: 0
        },
        wood_box: {
          label: 'Drevený box', box: :wood, heights: '', lengths: '250,300,350,400,450,500,550,600',
          side_clearance: 13, height_clearance: 25, bottom_width_deduction: 0, bottom_length_deduction: 0,
          back_width_deduction: 0, back_height_deduction: 0, front_min_extra: 0
        },
        blum_legrabox: {
          label: 'Blum LEGRABOX', box: :metal, heights: 'N:66.5,M:90.5,K:128.5,C:177,F:241',
          lengths: '270,300,350,400,450,500,550,600,650',
          side_clearance: 12.5, height_clearance: 0, bottom_width_deduction: 87, bottom_length_deduction: 12,
          back_width_deduction: 87, back_height_deduction: 0, front_min_extra: 12
        },
        blum_tandembox: {
          label: 'Blum TANDEMBOX antaro', box: :metal, heights: 'N:68,M:83,K:115,C:192,D:224',
          lengths: '270,300,350,400,450,500,550,600,650',
          side_clearance: 12.5, height_clearance: 0, bottom_width_deduction: 87, bottom_length_deduction: 14,
          back_width_deduction: 87, back_height_deduction: 0, front_min_extra: 15
        },
        blum_merivobox: {
          label: 'Blum MERIVOBOX', box: :metal, heights: 'N:68,M:91,K:127,E:187',
          lengths: '270,300,350,400,450,500,550,600',
          side_clearance: 12.5, height_clearance: 0, bottom_width_deduction: 84, bottom_length_deduction: 12,
          back_width_deduction: 84, back_height_deduction: 0, front_min_extra: 12
        }
      }.freeze
    end
  end
end
