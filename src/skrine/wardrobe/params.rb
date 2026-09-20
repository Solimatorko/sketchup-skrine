require_relative '../core/param_schema'
require_relative '../data/drawer_systems'

module Skrine
  module Wardrobe
    # Parameter schema of the "Skriňa" object type.
    module Params
      S = Core::ParamSchema

      PANEL = S.new do
        number :thickness, 18, label: 'Hrúbka', min: 3, max: 60
        number :front_recess, 0, label: 'Odsadenie vpredu', min: 0
        number :back_recess, 0, label: 'Odsadenie vzadu', min: 0
      end

      PANEL_WITH_CORNERS = S.new do
        number :thickness, 18, label: 'Hrúbka', min: 3, max: 60
        enum :corner_left, :inset, options: %i[inset overlay], label: 'Ľavý roh (medzi bokmi / cez bok)'
        enum :corner_right, :inset, options: %i[inset overlay], label: 'Pravý roh (medzi bokmi / cez bok)'
        number :engagement, 0, label: 'Zapustenie do boku', min: 0, max: 20
        number :front_recess, 0, label: 'Odsadenie vpredu', min: 0
        number :back_recess, 0, label: 'Odsadenie vzadu', min: 0
      end

      HANDLE = S.new do
        enum :type, :profile, options: %i[none drilled profile], label: 'Typ úchytky'
        number :hole_spacing, 160, label: 'Rozteč otvorov', min: 0
        number :offset_edge, 30, label: 'Odsadenie od hrany', min: 0
        enum :orientation, :horizontal, options: %i[horizontal vertical], label: 'Orientácia'
        number :profile_height, 30, label: 'Výška profilu (skráti čelo)', min: 0, max: 100
        enum :profile_position, :top, options: %i[top bottom], label: 'Pozícia profilu'
      end

      DOORS = S.new do
        enum :type, :double, options: %i[none single_left single_right double flap_up], label: 'Typ dverí'
        enum :mount, :overlay, options: %i[overlay half_overlay inset], label: 'Uloženie čiel'
      end

      CELL = S.new do
        enum :height_mode, :auto, options: %i[auto mm ratio], label: 'Výška – režim'
        number :height, 1, label: 'Výška (mm / pomer)', min: 0
        enum :content, :shelves, options: %i[shelves rod drawers inner_drawers empty], label: 'Obsah'
        integer :shelves_count, 2, label: 'Počet políc', min: 0, max: 30
        integer :drawers_count, 3, label: 'Počet zásuviek', min: 1, max: 12
        string :drawer_heights, '', label: 'Výšky čiel zhora (mm, čiarkou; prázdne = rovnomerne)'
        number :rod_offset_top, 60, label: 'Tyč – odsadenie zhora', min: 0
      end

      COLUMN = S.new do
        enum :width_mode, :auto, options: %i[auto mm ratio], label: 'Šírka – režim'
        number :width, 1, label: 'Šírka (mm / pomer)', min: 0
        boolean :doors_override, false, label: 'Vlastné nastavenie dverí'
        object :doors, DOORS, label: 'Dvere'
        boolean :handle_override, false, label: 'Vlastná úchytka'
        object :handle, HANDLE, label: 'Úchytka'
        list :cells, CELL, label: 'Polia (zhora nadol)', default: [{}]
      end

      MATERIAL = S.new do
        string :name, '', label: 'Názov / dekor'
        string :color, '#ffffff', label: 'Farba v modeli (#rrggbb)'
      end

      MATERIALS = S.new do
        object :corpus, MATERIAL, label: 'Korpus', default: { name: 'DTD 18 biela', color: '#e8e8e8' }
        object :front, MATERIAL, label: 'Čelá', default: { name: 'DTD 18 dekor', color: '#f4b8a0' }
        object :back, MATERIAL, label: 'Zadná stena', default: { name: 'HDF 3 biela', color: '#f5f5f5' }
        object :drawer_box, MATERIAL, label: 'Zásuvkový box', default: { name: 'DTD 16 biela', color: '#dddddd' }
        object :strip, MATERIAL, label: 'Lišty', default: { name: 'DTD 18 biela', color: '#e0e0e0' }
      end

      DRAWER_SYSTEM = S.new do
        string :label, '', label: 'Názov'
        enum :box, :metal, options: %i[none wood metal], label: 'Typ boxu'
        string :heights, '', label: 'Výškové triedy (N:66.5,M:90.5,…)'
        string :lengths, '', label: 'Nominálne dĺžky NL (mm, čiarkou)'
        number :side_clearance, 0, label: 'Bočná vôľa na stranu', min: 0
        number :height_clearance, 0, label: 'Výšková vôľa dreveného boxu', min: 0
        number :bottom_width_deduction, 0, label: 'Dno: odpočet od vnútornej šírky', min: 0
        number :bottom_length_deduction, 0, label: 'Dno: odpočet od NL', min: 0
        number :back_width_deduction, 0, label: 'Zadný diel: odpočet od vnútornej šírky', min: 0
        number :back_height_deduction, 0, label: 'Zadný diel: odpočet od výšky triedy', min: 0
        number :front_min_extra, 0, label: 'Min. presah čela nad výšku triedy', min: 0
      end

      DRAWER_SYSTEMS = S.new do
        Data::DrawerSystems::DEFAULTS.each do |key, defaults|
          object key, DRAWER_SYSTEM, label: defaults[:label], default: defaults
        end
      end

      SCHEMA = S.new do
        group :dims, 'Rozmery' do
          enum :placement, :between_walls, options: %i[between_walls corner_left corner_right free], label: 'Osadenie'
          number :width, 2000, label: 'Šírka (vonkajšia)', min: 200, max: 10_000
          number :height, 2400, label: 'Výška (vonkajšia)', min: 200, max: 4000
          number :depth, 600, label: 'Hĺbka (vonkajšia)', min: 100, max: 1500
          boolean :depth_includes_fronts, true, label: 'Hĺbka vrátane čiel'
          number :gap_left, 0, label: 'Odsadenie od steny vľavo', min: 0
          number :gap_right, 0, label: 'Odsadenie od steny vpravo', min: 0
          boolean :filler_left, false, label: 'Zaslepovacia lišta vľavo'
          boolean :filler_right, false, label: 'Zaslepovacia lišta vpravo'
          number :gap_top, 0, label: 'Odsadenie od stropu', min: 0
          boolean :top_strip, false, label: 'Krycia lišta hore'
          number :top_strip_height, 0, label: 'Výška hornej lišty (0 = celé odsadenie)', min: 0
          number :top_strip_setback, 0, label: 'Zapustenie hornej lišty od čiel', min: 0
          enum :base_type, :legs, options: %i[legs plinth floor], label: 'Spodok (nožičky / sokel medzi bokmi / na podlahe)'
          number :base_height, 100, label: 'Výška spodku', min: 0, max: 400
          boolean :bottom_strip, true, label: 'Krycia lišta dole (sokel)'
          number :bottom_strip_setback, 50, label: 'Zapustenie sokla od čiel', min: 0
          number :strip_floor_clearance, 10, label: 'Medzera sokla od podlahy', min: 0
        end

        group :construction, 'Konštrukcia' do
          number :panel_thickness, 18, label: 'Hrúbka korpusu (všeobecná)', min: 3, max: 60
          number :front_thickness, 18, label: 'Hrúbka čiel', min: 3, max: 60
          number :back_thickness, 3, label: 'Hrúbka zadnej steny (HDF)', min: 1, max: 30
          number :shelf_thickness, 18, label: 'Hrúbka políc', min: 3, max: 60
          number :partition_thickness, 18, label: 'Hrúbka priečok', min: 3, max: 60
          number :strip_thickness, 18, label: 'Hrúbka líšt', min: 3, max: 60
          object :top, PANEL_WITH_CORNERS, label: 'Strop'
          object :bottom, PANEL_WITH_CORNERS, label: 'Dno'
          object :side_left, PANEL, label: 'Ľavý bok'
          object :side_right, PANEL, label: 'Pravý bok'
          enum :back_mode, :groove, options: %i[groove overlay inset], label: 'Zadná stena (v drážke / nalozená / priznaná)'
          number :groove_depth, 8, label: 'Hĺbka drážky', min: 0
          number :groove_offset, 12, label: 'Drážka od zadnej hrany', min: 0
          number :back_inset_thickness, 18, label: 'Hrúbka priznanej zadnej steny', min: 3
          number :shelf_setback, 2, label: 'Zapustenie políc vpredu', min: 0
          number :shelf_back_clearance, 0, label: 'Vôľa políc vzadu', min: 0
          boolean :line_drilling, false, label: 'Rad otvorov (systém 32)'
          number :drill_pitch, 32, label: 'Rozteč otvorov', min: 1
          number :drill_offset_front, 37, label: 'Rad od prednej hrany', min: 0
          number :drill_offset_back, 37, label: 'Rad od zadnej hrany', min: 0
          number :drill_start, 100, label: 'Prvý otvor od dna', min: 0
          number :drill_end_offset, 100, label: 'Posledný otvor od stropu', min: 0
        end

        group :fronts, 'Čelá a špáry' do
          number :front_gap_h, 3, label: 'Špára medzi čelami vodorovne', min: 0
          number :front_gap_v, 3, label: 'Špára medzi čelami zvisle', min: 0
          number :reveal_top, 2, label: 'Odsadenie čela od hornej hrany', min: 0
          number :reveal_bottom, 0, label: 'Odsadenie čela od spodnej hrany', min: 0
          number :reveal_left, 2, label: 'Odsadenie čela od ľavej hrany', min: 0
          number :reveal_right, 2, label: 'Odsadenie čela od pravej hrany', min: 0
          number :inset_depth, 2, label: 'Zapustenie vnorených čiel', min: 0
          enum :front_grain, :vertical, options: %i[vertical horizontal], label: 'Smer dekoru čiel'
        end

        group :doors, 'Dvere' do
          boolean :doors_enabled, true, label: 'Dvere (vypnuté = otvorený korpus)'
          object :doors, DOORS, label: 'Predvolené dvere'
          enum :door_display, :closed, options: %i[closed open], label: 'Zobrazenie dverí'
          number :open_angle, 90, label: 'Uhol otvorenia', min: 0, max: 180, unit: '°'
          number :door_max_width, 600, label: 'Max. odporúčaná šírka krídla', min: 100
          string :hinge_table, '900:2,1600:3,2100:4,9999:5', label: 'Pánty: do výšky:počet, …'
        end

        group :handles, 'Úchytky' do
          object :handle, HANDLE, label: 'Predvolená úchytka'
        end

        group :drawers, 'Zásuvky' do
          enum :drawer_system, :blum_legrabox, options: Data::DrawerSystems::DEFAULTS.keys, label: 'Systém zásuviek'
          number :drawer_box_thickness, 16, label: 'Hrúbka bokov/zadného dielu boxu', min: 3
          number :drawer_bottom_thickness, 3, label: 'Drevený box – hrúbka dna', min: 1
          number :drawer_bottom_groove, 6, label: 'Drevený box – drážka dna', min: 0
          number :metal_box_bottom_thickness, 16, label: 'Kovový box – hrúbka dna', min: 3
          number :drawer_depth_reserve, 20, label: 'Rezerva hĺbky za zásuvkou', min: 0
          number :inner_drawer_setback, 30, label: 'Vnorená zásuvka – zapustenie čela', min: 0
          number :inner_drawer_side_gap, 3, label: 'Vnorená zásuvka – bočná špára', min: 0
          object :drawer_systems, DRAWER_SYSTEMS, label: 'Tabuľky systémov'
        end

        group :columns, 'Stĺpce' do
          list :columns, COLUMN, label: 'Stĺpce (zľava doprava)', default: [
            { cells: [{ content: :rod }, { content: :drawers, height_mode: :mm, height: 600, drawers_count: 3 }] },
            { cells: [{ content: :shelves, shelves_count: 4 }, { content: :drawers, height_mode: :mm, height: 600, drawers_count: 3 }] }
          ]
        end

        group :materials, 'Materiály' do
          object :materials, MATERIALS, label: 'Materiály'
        end

        group :hardware, 'Kovanie a hrany' do
          enum :joinery, :confirmat, options: %i[none dowels confirmat cam_lock], label: 'Spojovací materiál'
          number :joinery_pitch, 300, label: 'Rozteč spojov', min: 50
          integer :wall_brackets, 0, label: 'Závesné kovanie (ks)', min: 0
          enum :edge_corpus, :front, options: %i[none front all], label: 'Hrany – boky, strop, dno'
          enum :edge_shelf, :front, options: %i[none front all], label: 'Hrany – police, priečky'
          enum :edge_front, :all, options: %i[none front all], label: 'Hrany – čelá'
          enum :edge_strip, :all, options: %i[none front all], label: 'Hrany – lišty'
          enum :edge_drawer_box, :front, options: %i[none front all], label: 'Hrany – drevený box (horná hrana)'
        end
      end
    end
  end
end
