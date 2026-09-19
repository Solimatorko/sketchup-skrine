# Skrine – parametrický plugin pre SketchUp (návrh)

Dátum: 2026-09-19 · Stav: schválené v diskusii, čaká na implementáciu

## 1. Cieľ

Samostatný SketchUp extension (Ruby, SketchUp 2026 / Ruby 3.2), ktorý generuje
vstavané a voľne stojace skrine do izieb z parametrov zadaných vo formulári.
Každá zmena parametra (vrátane hrúbky materiálu) pregeneruje celú skriňu.
Z vygenerovanej skrine sa dá vyrobiť **nárezový plán** (rozpis dielcov podľa
materiálu, hranovanie) a **kusovník kovania**.

Nahrádza doterajší node-graf v plugine *Parametric Modeling* (Samuel Tallet),
ktorý sa pri ~100 nodoch stal neudržiavateľným.

Mimo rozsahu v1: nestovanie dielcov na formáty dosiek (rieši externý CutList
Optimizer z exportovaného CSV), polia cez viac stĺpcov, rohové skrine, výkresy
vŕtania. Architektúra však počíta s ďalšími typmi objektov (napr. široká horná
skrinka nad viacerými modulmi), ktoré sa pridajú neskôr ako nový generátor.

## 2. Architektúra

```
sketchup-skrine/
  src/skrine.rb                 # SketchupExtension registrácia
  src/skrine/
    loader.rb                   # require poradie, menu, toolbar
    core/
      param_schema.rb           # DSL: skupiny, parametre (typ, default, min/max, popis)
      registry.rb               # register typov objektov (:wardrobe, ...)
      part.rb                   # Part – jeden dielec (rozmery, materiál, hrany, kategória)
      hardware.rb               # HardwareItem – položka kovania
      layout.rb                 # Layout – výsledok generátora: parts + placements + hardware
      units.rb                  # mm <-> palce (SketchUp interné jednotky)
    data/
      drawer_systems.rb         # Blum Legrabox/Tandembox/Merivobox + drevený box – tabuľky
      hinges.rb                 # počet pántov podľa výšky/šírky dverí
    wardrobe/
      params.rb                 # schéma parametrov typu Skriňa
      model.rb                  # čistý Ruby: params -> Layout (žiadne SketchUp API)
      columns.rb, doors.rb, drawers.rb, back_panel.rb, base_top.rb  # čiastkové výpočty
    sketchup/
      builder.rb                # Layout -> geometria (groupy, atribúty, materiály)
      storage.rb                # čítanie/zápis parametrov z/do atribútov groupy
      selection.rb              # nájdi označenú skriňu
      commands.rb               # Nová skriňa / Upraviť / Nárezový plán / Presety
    ui/
      dialog.rb                 # UI::HtmlDialog + JS<->Ruby most
      html/index.html, app.js, style.css
    export/
      cutlist.rb                # zber dielcov z modelu, zoskupenie, CSV/HTML
      cutlist_optimizer.rb      # CSV vo formáte CutList Optimizer
  presets/                      # *.json presety (napr. „Skriňa 2 stĺpce + zásuvky“)
  test/                         # minitest, čistý Ruby (model, drawers, doors, cutlist)
  scripts/install_dev.sh        # symlink src/ do SketchUp Plugins
```

Zásady:

- **Model vrstva (wardrobe/*, core/*, data/*, export/cutlist.rb) nemá závislosť na
  SketchUp API** – testuje sa bežným `ruby` (homebrew 3.2.2). Všetky rozmery v mm
  (Float). Prevod na palce robí až `sketchup/builder.rb`.
- **Schéma parametrov je jediný zdroj pravdy** – z nej sa generuje formulár,
  validácia (min/max/typ), defaulty aj JSON serializácia.
- **Register typov**: `Registry.register(:wardrobe, label:, schema:, model_class:)`.
  Dialóg, storage, builder a cutlist sú na type nezávislé. Ďalší typ = nová
  zložka `src/skrine/<typ>/` + registrácia.

## 3. Dátový model

### 3.1 Part (dielec)

| pole | význam |
|---|---|
| `name` | napr. `Bok Ľ`, `Polica S2/P3`, `Dvere S1 Ľ`, `Čelo zásuvky S2/Z1` |
| `category` | `:corpus`, `:front`, `:back`, `:strip` (lišty), `:drawer_box`, `:filler` |
| `material` | kľúč materiálu (`corpus`, `front`, `back`, `drawer_box`, …) |
| `length`, `width`, `thickness` | mm; `length` je v smere dekoru |
| `edges` | `{top:, bottom:, left:, right:}` – hranovať áno/nie (vzťahuje sa na orientáciu v nárezovom pláne: top/bottom = krátke, left/right = dlhé strany, resp. presne definované per dielec) |
| `grain` | `:length` / `:none` |
| `qty` | vždy 1 v layoute; zlučovanie robí cutlist |
| `placement` | pozícia + orientácia v lokálnych súradniciach skrine (mm) |
| `meta` | `{column: 1, cell: 2, ...}` pre pomenovanie a ladenie |

### 3.2 HardwareItem

`{ kind: :hinge | :drawer_slide | :rod | :leg | :handle | :profile | :shelf_support, name:, qty:, unit: :pcs | :mm, meta: }`

### 3.3 Layout

`{ parts: [Part], hardware: [HardwareItem], envelope: {w,h,d}, warnings: [String] }`.
Warnings = neblokujúce problémy (napr. „zásuvka v S2/P1 je nižšia ako minimum
Legrabox M“).

### 3.4 Súradnice

Lokálny systém skrine: X = šírka (zľava doprava), Y = hĺbka (predná hrana čiel
v Y=0, korpus rastie do +Y, zadná stena pri Y=D), Z = výška (podlaha Z=0).
Vonkajšia obálka `W × H × D` = rozmery vrátane líšt, čiel a odsadení – to, čo sa
musí zmestiť do miestnosti.

## 4. Parametre typu Skriňa

Všetky rozmery mm. „ratio“ = pomerná časť zo zvyšku po odčítaní pevných mm hodnôt;
„auto“ = rovnomerne.

**Rozmery a osadenie**
- `width`, `height`, `depth` (vonkajšie), `depth_includes_fronts` (default true)
- `gap_left`, `gap_right` – odsadenie korpusu od steny; `filler_left`, `filler_right`
  – zaslepovacia lišta (áno/nie) v tej medzere
- `gap_top` – odsadenie od stropu; `top_strip` (áno/nie), `top_strip_height`
  (default = gap_top), `top_strip_setback`
- `base_type`: `legs` | `plinth` | `floor`; `base_height`; `bottom_strip` (áno/nie),
  `bottom_strip_setback`; pri `plinth` boky siahajú na podlahu, sokel je medzi nimi;
  pri `legs` kusovník nožičiek (4 + 2 na každú priečku)

**Konštrukcia**
- `corpus_thickness` (18), `front_thickness` (18), `back_thickness` (3),
  `shelf_thickness` (= corpus, prepísateľné), `strip_thickness`
- `top_mount`: `between_sides` | `on_sides`
- `back_mode`: `groove` (HDF v drážke, `groove_depth`, `groove_offset`) |
  `overlay` (HDF nalozená zozadu, korpus sa o hrúbku skráti) |
  `inset` („priznaná“ – doska hrúbky `back_inset_thickness` medzi bokmi, police o ňu kratšie)
- `front_gap` (3) – špára medzi susednými čelami a k okraju
- `shelf_setback` (2) – polica zapustená za prednú hranu; `shelf_back_clearance`

**Stĺpce** – `columns: [ { width: {mode: mm|ratio|auto, value}, doors: {…}, handle_override: {…}|nil, cells: [ { height: {mode}, content: shelves|rod|drawers|inner_drawers|empty, shelves_count, drawers_count, drawer_heights: auto|[mm], rod_offset_top } ] } ]`
- Susedné stĺpce oddeľuje priečka (hrúbka corpus). Polia oddeľuje pevná polica.
- `shelves`: N nastaviteľných políc rovnomerne v poli (`shelf_supports` do kovania).
- `rod`: vešiaková tyč (kovanie, dĺžka = vnútorná šírka), `rod_offset_top`.
- `drawers`: N zásuviek s vonkajšími čelami; čelá vypĺňajú výšku poľa (auto)
  alebo zadané výšky.
- `inner_drawers`: zásuvky za dverami; čelo zapustené o `inner_drawer_setback`.

**Dvere (per stĺpec, globálny default)**
- `doors_enabled` (globálne; false = otvorený korpus / regál)
- `type`: `none` | `single_left` | `single_right` | `double`
- `mount`: `overlay` | `half_overlay` | `inset`
- `display`: `closed` | `open` + `open_angle` (len vizualizácia, nemení rozpis)
- Dvere pokrývajú súvislé úseky polí, ktoré nie sú `drawers`; každý úsek =
  samostatná sada dvierok. Šírka čela = vnútorná šírka + presahy − špára; presah
  na zdieľanej priečke je vždy `t/2`, na vonkajšom boku `t` (overlay), `t/2`
  (half_overlay), `0` (inset, plus špára). Vertikálne analogicky voči stropu/dnu/
  pevným policiam.
- Pánty: počet z tabuľky `data/hinges.rb` podľa výšky dverí (default: <900: 2,
  <1600: 3, <2100: 4, inak 5), editovateľné.

**Úchytky (globálne, prepis per stĺpec)**
- `type`: `none` | `drilled` | `profile`
- `drilled`: `hole_spacing` (128/160/…), `position` (vzdialenosť od hrany, od
  horného/spodného okraja), `orientation` (horizontálna/vertikálna)
- `profile` (integrovaný Gola/frézovaný profil): `profile_height` – čelo sa o ňu
  skráti, profil ide do kovania v mm; `profile_position` (top | bottom)

**Zásuvky**
- `drawer_system`: `front_only` | `wood_box` | `blum_legrabox` | `blum_tandembox` |
  `blum_merivobox` (tabuľky v `data/drawer_systems.rb`: výškové triedy, nominálne
  dĺžky, bočná vôľa, min./max. výška čela, hrúbka dna, vôľa dna) – hodnoty sú
  editovateľné v záložke Nastavenia a ukladajú sa s modelom
- `front_only`: do nárezu len čelo; výsuv (dĺžka = najväčšia nominálna ≤ hĺbka −
  rezerva) do kovania
- `wood_box`: boky, zadný diel, dno (`drawer_box_thickness`, `drawer_bottom_thickness`,
  `drawer_side_clearance`, `drawer_height_clearance`), + čelo; výsuvy do kovania
- Blum systémy: box = kovové boky (kovanie) + dno + zadný diel z materiálu
  (`drawer_box` – rozmery podľa tabuľky), čelo; výška čela → výber triedy

**Materiály** – tabuľka `materials: { corpus: {name, color, thickness}, front:, back:, drawer_box:, strip: }`; názov ide do nárezového plánu, farba do modelu.
Hrúbka v materiáli je default pre príslušné `*_thickness` parametre (jednosmerne – zmena hrúbky v konštrukcii má prednosť).

**Hranovanie (defaulty, prepísateľné per kategória)** – boky: predná hrana; police:
predná hrana; priečky: predná; strop/dno: predná; dvere a čelá: všetky 4;
lišty: viditeľné hrany; zadná stena: nič.

## 5. Generovanie v SketchUpe

- Skriňa = top-level `Group` s `AttributeDictionary "Skrine"`:
  `type = "wardrobe"`, `version = 1`, `params = <JSON>`.
- Každý dielec = `Group` v skrini, `name` = názov dielca, dictionary
  `"Skrine::Part"` = polia z Part (bez placement). Materiál SketchUpu podľa
  `materials[*].color`, názov `Skrine/<material>`.
- Kovanie sa modeluje zjednodušene (tyč = valec, nožička = kváder, pánt/výsuv sa
  nekreslia) a nesie dictionary `"Skrine::Hardware"`.
- Dvere „open“: groupa dverí otočená okolo osi pántov o `open_angle`.
- **Pregenerovanie**: `model.start_operation("Skriňa", true)` → vymazať obsah
  groupy → postaviť nanovo → `commit_operation`. Transformácia groupy sa zachová,
  takže skriňa zostane na mieste. Ak groupa už neexistuje (zmazaná), dialóg
  ponúkne vytvoriť novú.
- Nová skriňa sa vloží na počiatok, používateľ ju presunie štandardnými nástrojmi.

## 6. UI

`UI::HtmlDialog` (vanilla JS, žiadne buildovanie). Ruby pošle do JS schému +
aktuálne parametre; JS vykreslí záložky: **Rozmery · Konštrukcia · Stĺpce ·
Dvere & úchytky · Zásuvky · Materiály · Nastavenia (tabuľky Blum/pánty)**.

- Záložka Stĺpce: editor zoznamu stĺpcov (pridať/odobrať/duplikovať/poradie),
  v každom zoznam polí; per stĺpec prepis dverí a úchytiek.
- Tlačidlo **Použiť** + prepínač **Auto** (debounce 300 ms) → callback `apply(json)`.
- Validácia z min/max schémy v JS; `warnings` z Layoutu sa zobrazia pod formulárom.
- **Presety**: uložiť/načítať JSON (`UI.savepanel/openpanel`), niekoľko vzorových v `presets/`.
- Menu **Extensions › Skrine**: Nová skriňa · Upraviť označenú · Nárezový plán ·
  Presety. Toolbar s rovnakými príkazmi. Kontextové menu na skrini: Upraviť.
- Jazyk UI: slovenčina (texty v jednom JS objekte, ľahko preložiteľné).

## 7. Nárezový plán a kusovník

Vstup: označené skrine, alebo všetky skrine v modeli. Zber = prejsť groupy s
`"Skrine::Part"` / `"Skrine::Hardware"` (nie z parametrov – takže aj ručne
upravený dielec sa započíta podľa atribútov).

Výstup (HtmlDialog s tabuľkou + tlačidlá exportu):
1. **Dielce** zoskupené podľa materiálu (názov, hrúbka): názov, ks, dĺžka, šírka,
   hrany (formát `2D 1K` + detail), dekor. Rovnaké dielce sa zlúčia (kľúč:
   material+L+W+T+edges+grain).
2. **Hranovanie**: metráž ABS na materiál/hrúbku.
3. **Kovanie**: pánty, výsuvy (typ, nominálna dĺžka), tyče (mm), nožičky,
   úchytky, profil (mm), podpery políc.
4. **Sumár plôch** m² na materiál (informatívne, bez prirezu).

Exporty: CSV (UTF-8, `;`), CSV pre CutList Optimizer
(`Length;Width;Qty;Label;Enabled;Grain`), HTML (na tlač).

## 8. Chybové stavy

- Neplatné parametre (napr. súčet mm šírok > vnútorná šírka, záporná výška poľa):
  model vráti `errors` → dialóg zobrazí, negeneruje sa.
- Nepohodlné, ale platné (zásuvka mimo tabuľky Blum, dvere > 600 mm šírka):
  `warnings`, generuje sa.
- Pregenerovanie zlyhá výnimkou → `abort_operation`, hláška s detailom.
- Starší `version` v atribútoch → migrácia defaultmi chýbajúcich parametrov.

## 9. Testovanie

- `test/` minitest (čistý Ruby): pre referenčné konfigurácie overiť presné rozmery
  dielcov (bok, strop medzi/na bokoch, priečka, polica pri každom `back_mode`,
  dvere pre každý `mount` × pozíciu stĺpca, čelá zásuviek s profilom, drevený box,
  Legrabox trieda), počty kovania, zlučovanie v cutliste, CSV formát, chyby/warnings.
- `test/fixtures/*.json` – parametre; presety v `presets/` sa v teste načítajú a
  musia vygenerovať layout bez `errors`.
- SketchUp: `scripts/smoke.rb` na spustenie z Ruby Console (vygeneruje preset,
  spočíta dielce, spustí cutlist) + ručné overenie na `~/Downloads/Skrine.skp`.
- Spustenie: `ruby -Isrc -Itest test/run_all.rb`.

## 10. Postup implementácie (poradie)

1. Kostra repa, extension loader, schéma parametrov, Part/Layout, registry, testy bežia.
2. Model Skriňa: obálka, korpus, stĺpce, polia, police, zadná stena, spodok/vrch, lišty.
3. Dvere + úchytky + pánty. 4. Zásuvky (front_only, wood_box, Blum). 5. Builder v SketchUpe + storage + príkazy.
6. HtmlDialog. 7. Nárezový plán + exporty. 8. Presety, smoke test, overenie na reálnom modeli.
