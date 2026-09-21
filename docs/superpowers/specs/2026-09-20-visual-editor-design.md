# Skrine – vizuálny editor (UI v2) – návrh

Dátum: 2026-09-20 · Nadväzuje na `2026-09-19-skrine-plugin-design.md` (model, nárezový
plán a SketchUp vrstva zostávajú; mení sa dialóg).

## 1. Cieľ

Nahradiť formulár generovaný zo schémy jednou veľkou obrazovkou, v ktorej je hlavným
ovládacím prvkom **živý nákres skrine**: klik na stĺpec / pole / dvere / sokel vyberie
prvok, vpravo sa zobrazia jeho voľby ako **obrázkové karty** a čísla, každá zmena sa
**okamžite prejaví v nákreze** (bez čakania na SketchUp) a s Auto aj v modeli.
Inšpirácia: Blum Cabinet Configurator (klik na panel → jeho vlastnosti), skrinka.sk
(moduly stĺpcov, kóty v nákreze), online-skrine.sk (galéria hotových skríň).

Mimo rozsahu: 3D náhľad v dialógu (na to je SketchUp), ťahanie priečok myšou (kóty sa
editujú číslom), toolbar s ikonami.

## 2. Rozloženie

Dialóg `UI::HtmlDialog` 1320×880, roztiahnuteľný, CSS grid:

```
┌ toolbar ──────────────────────────────────────────┬ panel (380 px) ─────────────┐
│ [Galéria skríň] [Presety ▾]  Š[2000] V[2400] H[600]│ nadpis vybraného prvku       │
│ typ osadenia: [medzi stenami][Ľ roh][P roh][voľná]  │ karty + polia pre prvok      │
├ nákres ───────────────────────────────────────────┤ (scrolluje samostatne)       │
│  pohľad: (•) s čelami ( ) bez čiel ( ) bok ( ) pôdorys │                          │
│  SVG: skriňa s kótami; hover zvýrazní, klik vyberie │                              │
├ rozšírené (zbaliteľné) ───────────────────────────┤ [Použiť] ☑ Auto  [Nárezový plán]│
│ záložky: Konštrukcia · Čelá a špáry · Zásuvky ·    │ chyby / varovania             │
│ Materiály · Kovanie a hrany (formulár zo schémy)   │ vnútorné rozmery              │
└───────────────────────────────────────────────────┴──────────────────────────────┘
```

## 3. Tok dát

Dva callbacky do Ruby:

- `preview(params_json)` – **lacný**: Ruby spustí čistý model (`Model#layout`), vráti
  `{ scene, info, errors, warnings }`. Volá sa po každej zmene (debounce 150 ms). Nemení
  SketchUp.
- `apply(params_json)` – ako doteraz: `Builder.rebuild` + `setResult`. Volá sa tlačidlom
  Použiť alebo automaticky (Auto, debounce 400 ms po poslednej zmene).

Dialóg drží `state` (parametre) v JS; Ruby je bezstavové okrem `@group`.

### 3.1 Scene JSON (`Export::Scene`, čistý Ruby)

```json
{
  "size": { "w": 2000, "h": 2400, "d": 600 },
  "boxes": [
    { "id": "p12", "kind": "door", "column": 1, "cell": null, "name": "Dvere S1 Ľ",
      "x": 2, "y": 0, "z": 728.5, "dx": 496.75, "dy": 18, "dz": 1639.5, "category": "front" }
  ],
  "cells": [ { "column": 1, "cell": 1, "x": 18, "z": 736, "w": 973, "h": 1646, "content": "rod" } ],
  "columns": [ { "index": 1, "x": 18, "w": 973 } ],
  "dims": [
    { "id": "width", "axis": "x", "from": 0, "to": 2000, "at": 2450, "value": 2000, "edit": "width" },
    { "id": "col-1", "axis": "x", "from": 18, "to": 991, "at": -60, "value": 973, "edit": "columns.0.width" },
    { "id": "cell-1-1", "axis": "z", "from": 736, "to": 2382, "at": -60, "value": 1646, "edit": "columns.0.cells.0.height" }
  ]
}
```

`kind` (odvodené z `Part#category` + `meta`): `side top bottom partition shelf back plinth
top_strip filler door drawer_front drawer_box leg rod`. Každý box nesie `column`/`cell`
(ak má). `cells` sú neviditeľné obdĺžniky vnútra polí (aj prázdnych) – klikacie ciele.
Kóty `dims`: `edit` je cesta v `state`; `null` = needitovateľná (napr. hrúbka).
Model doplní `meta[:column]`/`meta[:cell]` aj boxom polí do `layout.info` (už je
`info[:columns][i][:cells][j]`, pridá sa `x, z, w, h`).

### 3.2 Výberový model (JS)

`selection = { kind: 'global' | 'column' | 'cell' | 'base' | 'construction', column:, cell: }`

| klik na | výber | panel |
|---|---|---|
| prázdna plocha / kóta celku | global | typ osadenia, Š/V/H, dvere globálne, úchytka globálne |
| dvere, priečka, hlavička stĺpca | column | šírka (auto/mm/pomer), **knižnica modulov**, dvere (typ, uloženie), úchytka (prepis), zoznam polí |
| police, tyč, čelo zásuvky, vnútro poľa | cell | výška (auto/mm/pomer), obsah (karty), počet políc/zásuviek, výšky čiel, tyč |
| sokel, nožičky, horná lišta, zaslepenie | base | spodok (nožičky/sokel/podlaha), výška, lišty, odsadenia od steny/stropu |
| bok, strop, dno, zadná stena | construction | otvorí záložku Konštrukcia v rozšírených + zvýrazní |

Hover v nákreze zvýrazní prvok (oranžový obrys), výber = oranžová výplň 25 %. Výber
sa zachová po prekreslení (podľa kind+column+cell).

### 3.3 Editácia kót

Klik na kótu → inline `<input>` v SVG (`foreignObject`), Enter potvrdí: zapíše
`state` podľa `edit` (šírka stĺpca → `width_mode: 'mm'`, ostatné stĺpce zostanú; výška
poľa → `height_mode: 'mm'`), spustí preview. Ak model vráti chybu (súčet presahuje),
kóta sa zobrazí červená s hláškou a stav sa vráti.

## 4. Panely a karty

Karta = `<button class="card">` s inline SVG piktogramom (48×48) a názvom; skupina kariet
= radio. Piktogramy sú v `src/skrine/ui/html/icons.js` (`ICONS[key] -> svg string`),
štýl: biele plochy, tmavý obrys, oranžová (#f28c28) zvýraznená časť (ako Blum).

Karty pre: typ osadenia (`placement`: between_walls / corner_left / corner_right /
free – nastaví `gap_left/right` a `filler_*`), spodok (legs/plinth/floor), zadná stena
(groove/overlay/inset), typ dverí (none/single_left/single_right/double/flap_up),
uloženie čiel (overlay/half_overlay/inset), úchytka (none/drilled/profile), obsah poľa
(shelves/rod/drawers/inner_drawers/empty), systém zásuviek (5), rohový spoj
(inset/overlay). Číselné hodnoty: `<input type=number>` + `<input type=range>` pre Š/V/H.

Nový parameter `placement` (enum, default `between_walls`) v schéme; model ho
nepoužíva na geometriu (len UI predvyplní odsadenia).

## 5. Knižnica modulov stĺpca (`src/skrine/data/column_modules.rb`)

Zoznam `{ key, label, cells: [...] }` – napr. `hanging_drawers` „Vešanie + 3 zásuvky“,
`shelves_5` „5 políc“, `double_hanging` „2× krátke vešanie“, `shelves_drawers` „Police +
zásuvky“, `hanging_top_shelves` „Vešanie hore, police dole“, `hanging_only` „Dlhé
vešanie“, `drawers_only` „Zásuvky“. Klik na kartu modulu nahradí `columns[i].cells`.
Náhľad karty = mini nákres stĺpca (JS vykreslí z definície modulu schematicky).

## 6. Galéria skríň

Tlačidlo **Galéria skríň** otvorí overlay s kartami: každá karta = preset z `presets/`
(a používateľské v `~/Library/Application Support/Skrine/presets/`) s náhľadom
(čelný pohľad zo scény) a názvom (`_name` v JSON, inak názov súboru). Ruby callback
`gallery()` vráti `[ { file, name, scene } ]`. Klik: „Použiť na túto skriňu“ –
nahradí stav a náhľad (`@params` + `push_state`, **bez** okamžitého prekreslenia
modelu); model sa prekreslí, keď to urobí Auto alebo tlačidlo Použiť, presne ako
pri ručnej zmene. Alebo „Vytvoriť novú“ (`Commands.new_from_preset_file`).
Používateľ si uloží aktuálnu skriňu ako preset (Presety ▾ › Uložiť do galérie,
vyplní meno v riadku v menu) – uloží sa do používateľského priečinka a objaví sa
v galérii.

## 7. Rozšírené

Dolná zbaliteľná sekcia so záložkami generovanými zo schémy ako dnes (skupiny
construction, fronts, drawers, materials, hardware; dims/doors/handles/columns sú
pokryté nákresom a panelmi). Enumy aj tu ako karty (menšie), čísla ako polia.

## 8. Súbory

```
src/skrine/export/scene.rb            # Layout+params -> scene hash (čistý Ruby, testy)
src/skrine/data/column_modules.rb     # knižnica modulov (čistý Ruby, testy)
src/skrine/ui/dialog.rb               # callbacky preview/apply/gallery/save_preset/...
src/skrine/ui/html/index.html, style.css
src/skrine/ui/html/app.js             # stav, panely, rozšírené, handshake
src/skrine/ui/html/drawing.js         # SVG nákres, projekcie, hover/klik, kóty
src/skrine/ui/html/cards.js           # karty, ikony -> icons.js
src/skrine/ui/html/gallery.js         # galéria skríň
scripts/ui_server.rb                  # dev server: sprístupní html + preview/gallery cez HTTP
                                      # (JS stub `sketchup` volá fetch), na vizuálne testy v prehliadači
```

## 9. Testovanie

- minitest: `Scene` (kinds, cells, dims, editovateľné cesty pre referenčnú skriňu),
  `ColumnModules` (každý modul dá platný layout), `placement` predvyplnenie.
- `node --check` na JS; vizuálna kontrola cez `scripts/ui_server.rb` v prehliadači
  (screenshoty: default, výber stĺpca, výber poľa, galéria, kóta v editácii).
- SketchUp: `scripts/reload.rb` + ručné overenie (klik → panel → zmena → nákres → Auto → model).

## 10. Overenie

Task 8 (QA finished editora) overil hotovú stránku v prehliadači cez `scripts/ui_server.rb`
(port 8792, stub `window.sketchup` nad HTTP, žiadny SketchUp). Postup a nálezy sú
v `.superpowers/sdd/2026-09-20-visual-editor/task-8-report.md`; zhrnutie:

**Overené v prehliadači:**
- Default stránka (nákres, panel, info riadok) sa vykreslí bez JS chýb.
- Klik na stĺpec v nákrese → panel stĺpca (šírka, knižnica modulov); klik na kartu modulu
  okamžite prepíše `columns[i].cells` a nákres sa prekreslí.
- Klik na pole (shelf/drawer_front/drawer_box/rod) → panel poľa (výška, obsah); klik na
  kartu obsahu prepíše pole a nákres sa prekreslí.
- Editácia kóty: platná hodnota sa uloží (`setPath` → mm mód, prekreslenie, warningy z
  preview); neplatná hodnota (napr. šírka stĺpca < 50 mm → `layout.error`) sa vráti na
  pôvodnú a kóta na 2 s zčervenie (`.dim.error`).
- Osadenie „voľne stojaca“ vynuluje `gap_left/right` a `filler_left/right`.
- Vypnutie dverí (`doors_enabled = false`) vykreslí otvorený korpus bez čiel.
- Prepínač „Zobrazenie dverí → otvorené“ nemení nákres (len 3D model v SketchUpe) –
  pridaný hint text pod kartami to teraz vysvetľuje.
- Auto vypnuté: zmena parametra vyvolá len `preview` (náhľad/warningy), nie `apply`;
  tlačidlo „Použiť v SketchUpe“ vyvolá `apply` presne raz.
- Galéria skríň: otvorenie zobrazí karty s live SVG náhľadom; „Použiť na túto skriňu“
  prepíše aktuálny stav (rozmery, typ dverí, scéna), „Vytvoriť novú“ načíta iný preset
  do toho istého okna (v reálnom SketchUpe ide cez `Commands.new_from_preset_file`).
- Menu **Presety ▾** sa otvára/zatvára; položky (uložiť do galérie/súboru, načítať zo
  súboru) volajú príslušné stubované callbacky.
- Rozšírené záložky (Konštrukcia, Čelá a špáry, Zásuvky, Materiály, Kovanie a hrany) sa
  prepínajú správne; enumy s definovaným piktogramom (`ICONS`) sú karty, ostatné (napr.
  hranovanie) ostávajú `<select>` – podľa návrhu v `form.js`.
- Zmena veľkosti okna prehliadača prepočíta mierku nákresu (`Drawing.render` používa
  `host.clientWidth/Height`) a kóty ostanú čitateľné.
- Konzola aj sieťové požiadavky (`/state`, `/preview`, `/gallery`, `/preset`) bez chýb
  počas celej relácie.

**Nájdené a opravené chyby (`fix(ui): …`):**
- Chýbajúci hint text pri karte „Zobrazenie dverí → otvorené“ (nič nenaznačovalo, že
  otvorenie sa neprejaví v nákrese) – doplnený text a CSS trieda `.hint` v paneli.
- Menu **Presety ▾** sa po kliknutí mimo seba nezatváralo (chýbal listener na klik mimo
  `.menu`) – doplnený `document` click-outside handler.
- `scripts/ui_server.rb` padal s `Encoding::CompatibilityError`, keď shell nemal
  nastavené `LANG`/`LC_ALL` (UTF-8 znaky v `index.html` pri `File.read` + `.sub` so
  slovenskými reťazcami) – opravené vynútením `Encoding.default_external/internal =
  Encoding::UTF_8` a explicitným `encoding: 'UTF-8'` pri čítaní `index.html`.

**Kozmetické/menšie pozorovania (neopravované, nekritické):**
- Rozbalenie „Rozšírené nastavenia“ zmenší dostupnú výšku nákresu (grid riadok
  `drawing` je `1fr`, `advanced` je `auto`) – funguje správne, len menej miesta na
  nákres pri nízkom okne.
- V automatizovanom prehliadači `Enter` v kóte niekedy nevyvolá commit okamžite (blur
  vždy commitne) – pravdepodobne kvôli poradiu udalostí v headless klikaní, nie chyba
  aplikácie (rovnaké pozorovanie ako v Task 7 reporte).

**Zostáva overiť v SketchUpe (Step 2, mimo rozsah Task 8 – vykonáva kontrolór cez
`scripts/reload.rb` a `scripts/verify.rb`, bez zásahu do `verify.rb`):**
- Reálny handshake `window.sketchup` (WebDialog/HtmlDialog) namiesto HTTP stub-u.
- Zmena šírky kótou → Auto → prekreslenie 3D modelu (`Builder.rebuild`).
- Modul „5 políc“ priradený stĺpcu 2 → korektná geometria v modeli.
- Galéria → „Vytvoriť novú“ → `Commands.new_from_preset_file` vloží druhú skriňu vedľa.
- Screenshot cez `view.write_image` (súčasť `scripts/verify.rb`) pre vizuálnu kontrolu
  v reálnom modeli.
