# Skrine – editor po krokoch s detailom pri poli (UI v3) – návrh

Dátum: 2026-09-21 · Nadväzuje na `2026-09-20-visual-editor-design.md` (UI v2). Zachováva
scénu, nákres, karty, moduly, galériu, náhľadovú službu a most do SketchUpu; mení
navigáciu (kroky) a správanie nákresu (detail k poľu vo fokuse).

## 1. Cieľ

Používateľ prechádza skriňu v šiestich krokoch s progress barom hore. V každom kroku
je vľavo nákres, vpravo polia daného kroku. Keď je pole vo fokuse, nákres sa priblíži
na **detail tej jednej veci** (ako Blum konfigurátor): správny pohľad, výrez, oranžovo
zvýraznený prvok a kóta, pod poľom povolený rozsah a prípadný prepočítaný dôsledok.
Bez fokusu nákres ukazuje celý pohľad kroku. Krok „Členenie“ ostáva interaktívny
(klik na stĺpec/pole, moduly, editovateľné kóty) ako v UI v2.

Mimo rozsahu: iné typy objektov, 3D, drag&drop.

## 2. Kroky

| # | krok | polia (zo schémy) | predvolený pohľad |
|---|---|---|---|
| 1 | Korpus a osadenie | placement, width, height, depth, depth_includes_fronts, gap_left/right, filler_*, gap_top, top_strip*, base_type, base_height, bottom_strip*, strip_floor_clearance | čelný |
| 2 | Členenie | stĺpce/polia/moduly – interaktívny nákres + panely stĺpec/pole z UI v2 | čelný bez čiel |
| 3 | Dvere a úchytky | doors_enabled, doors.type, doors.mount, door_display, open_angle, door_max_width, hinge_table, front_gap_h/v, reveal_*, inset_depth, front_grain, handle.* | čelný |
| 4 | Zásuvky | drawer_system, drawer_* (box, dno, drážka, rezerva), inner_drawer_*, tabuľky systémov (zbalené) | čelný bez čiel |
| 5 | Konštrukcia a materiály | panel_thickness, front/back/shelf/partition/strip thickness, top/bottom/side_* (rohy, odsadenia), back_mode + groove_*, shelf_setback/back_clearance, line_drilling*, materials.*, edge_*, joinery*, wall_brackets | pôdorys |
| 6 | Kontrola | súhrn (vonkajšie/vnútorné rozmery, počty dielcov a kovania), varovania, tlačidlá: Použiť v SketchUpe, Nárezový plán, Uložiť preset, Galéria | čelný |

Progress bar: 6 klikateľných položiek, aktívna zvýraznená, kroky s chybou označené
červenou bodkou. Tlačidlá **Späť / Ďalej** dole v paneli. Stav sa nestráca pri
prepínaní krokov (jeden `state`). Auto/Použiť ostáva v päte panela vo všetkých krokoch.

## 3. Detail k poľu (focus detail)

`FOCUS[paramPath] = { view, region, highlight, dim, note }`

- `view`: `front | front_open | side | plan`
- `region`: výrez v mm ako funkcia scény, napr. `'corner_front_left'`, `'base'`,
  `'top'`, `'gap_between_columns'`, `'door_edge_left'`, `'drawer_stack'`,
  `'back_panel'`, `'full'` – pomenované regióny počíta `Drawing.regionBox(scene, name)`
  (vracia `{x0,x1,y0,y1}` v súradniciach pohľadu) s okrajom 10 %.
- `highlight`: druhy boxov/ids, ktoré sa zvýraznia (`['side']`, `['door']`,
  `['plinth','leg']`, `['back']`…), voliteľne filtrované na stĺpec.
- `dim`: dočasná kóta pre detail: `{ axis, from, to, at, label }` počítaná zo scény
  (napr. hrúbka boku = od `side.x` po `side.x2`), alebo id existujúcej kóty.
- `note`: text pod poľom (rozsah `min–max` zo schémy + dôsledok, napr. „vnútorná
  šírka 1964 mm“ z `info`).

Nákres: `Drawing.render(host, scene, { view, region, highlightKinds, extraDims, interactive })`
– `region` nastaví `viewBox` (zoom), `highlightKinds` doplní triedu `.focus`,
`extraDims` sa vykreslia oranžovo. Pri strate fokusu (blur bez fokusu iného poľa,
timeout 300 ms) sa nákres vráti na pohľad kroku. Prepnutie polí je plynulé (CSS
transition na `viewBox` nie je možná – použije sa jednoduchý JS tween 150 ms).

Mapa FOCUS pokrýva všetky polia krokov 1, 3, 4, 5 (pre polia bez zmysluplného detailu
– napr. názov dekoru – `region: 'full'` bez kóty).

## 4. Polia

Jednotný renderer poľa (rozšírenie `Form`): label, vstup (číslo / karty / prepínač /
text), riadok s rozsahom `min – max mm` (zo schémy) a s dôsledkom (z `info`).
Fokus vstupu aj klik na kartu vyvolá `Skrine.focus(paramPath)`.

## 5. Súbory

```
src/skrine/ui/html/steps.js      # definícia krokov (polia, pohľad), progress bar, Späť/Ďalej
src/skrine/ui/html/focus.js      # FOCUS mapa + regióny + extra kóty
src/skrine/ui/html/drawing.js    # + region/viewBox, highlightKinds, extraDims, tween
src/skrine/ui/html/form.js       # + range/consequence riadok, focus hook, reuse v krokoch
src/skrine/ui/html/app.js        # navigácia krokov; panely stĺpec/pole ostávajú v kroku 2
src/skrine/ui/html/index.html, style.css
```
Ruby vrstva bez zmien okrem `PreviewService.init_payload` → pridá `ranges`
(min/max zo schémy sú už v `schema.to_h`; nič nové).

## 6. Testovanie

- `node --check`; browser QA cez `scripts/ui_server.rb`: každý krok, fokus na 3–4
  reprezentatívne polia na krok (screenshot), Späť/Ďalej, chyba v kroku → červená bodka.
- Ruby testy nezmenené (128).
- SketchUp: `scripts/reload.rb` + prechod všetkými krokmi.
