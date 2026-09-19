require 'test_helper'

class CutlistTest < Minitest::Test
  def cutlist(**over)
    params = wardrobe_params(**over)
    l = Skrine::Wardrobe::Model.new(params).layout
    assert l.valid?, l.errors.join('; ')
    Skrine::Export::Cutlist.new(l.parts, l.hardware, materials: params[:materials])
  end

  def test_identical_parts_are_merged_with_material_labels
    c = cutlist
    sides = c.rows.find { |r| r.name.start_with?('Bok') }
    assert_equal 2, sides.qty
    assert_equal 'Bok Ľ (+1)', sides.name
    assert_equal 'DTD 18 biela', sides.material_label
    assert_equal 18, sides.thickness
    doors = c.rows.find { |r| r.name.start_with?('Dvere') }
    assert_equal 4, doors.qty
    assert_equal 'DTD 18 dekor', doors.material_label
  end

  def test_by_material_groups_and_sorts_by_area
    groups = cutlist.by_material
    assert_includes groups.keys, 'DTD 18 biela 18 mm'
    assert_includes groups.keys, 'HDF 3 biela 3 mm'
    rows = groups['DTD 18 biela 18 mm']
    assert_equal 'Bok Ľ (+1)', rows.first.name          # largest area first
  end

  def test_edge_meters_and_area
    c = cutlist
    edges = c.edge_meters
    assert_operator edges['DTD 18 dekor 18 mm'], :>, 20      # fronts banded on 4 edges
    assert_operator c.area_m2['DTD 18 biela 18 mm'], :>, 5
  end

  def test_hardware_rows_merge_and_skip_draw_only
    hw = cutlist.hardware_rows
    slides = hw.find { |r| r.kind == :slide }
    assert_equal 6, slides.qty
    assert_nil hw.find { |r| r.kind == :drawer_side }
    legs = hw.find { |r| r.kind == :leg }
    assert_equal 6, legs.qty
    profile = hw.find { |r| r.kind == :profile }
    assert_equal :mm, profile.unit
  end

  def test_csv_has_header_and_semicolons
    csv = cutlist.to_csv
    lines = csv.lines
    assert lines.first.start_with?("﻿Materiál;Hrúbka;Názov;Ks;Dĺžka;Šírka;Hrany;Dekor")
    assert lines.any? { |l| l.include?('Bok Ľ (+1);2;2300;582;1D;') }
  end

  def test_optimizer_csv_format
    csv = cutlist.to_optimizer_csv
    assert_equal 'Length;Width;Qty;Label;Enabled;Grain', csv.lines.first.strip
    assert csv.lines.any? { |l| l.start_with?('2300;582;2;Bok') }
  end

  def test_html_contains_sections
    html = cutlist.to_html
    assert_includes html, '<h2>DTD 18 biela 18 mm</h2>'
    assert_includes html, 'Kovanie'
    assert_includes html, 'Hranovanie'
  end

  def cutlist_with_corpus_name(name)
    materials = wardrobe_params[:materials].merge(corpus: { name: name, color: '#fff' })
    cutlist(materials: materials)
  end

  def test_csv_and_optimizer_csv_quote_fields_with_separators_or_quotes
    c = cutlist_with_corpus_name('DTD; "Egger" H1180')

    csv = c.to_csv
    assert csv.lines.any? { |l| l.start_with?('"DTD; ""Egger"" H1180";18;') }

    opt = c.to_optimizer_csv
    assert opt.lines.any? { |l| l.include?('"Bok Ľ (+1) [DTD; ""Egger"" H1180 18]"') }
  end

  def test_html_escapes_material_name
    html = cutlist_with_corpus_name('A<B & C').to_html
    assert_includes html, 'A&lt;B &amp; C'
  end
end
