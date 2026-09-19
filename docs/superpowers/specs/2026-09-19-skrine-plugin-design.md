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

**Konštrukcia** (inšpirované Blum Cabinet Configurator)
- `panel_thickness` (18) – všeobecná hrúbka korpusu; `front_thickness` (18),
  `back_thickness` (3), `shelf_thickness` (= panel, prepísateľné), `strip_thickness`,
  `partition_thickness` (= panel)
- **Panely korpusu** – `top`, `bottom`, `side_left`, `side_right`, každý:
  `thickness` (default = panel_thickness), `front_recess`, `back_recess`
  (odsadenie od prednej/zadnej hrany korpusu); strop a dno navyše
  `corner_left`/`corner_right`: `inset` (medzi bokmi) | `overlay` (cez bok) a
  `engagement` (rozmer zapustenia pri čiastočnom prekrytí). Kombinácia
  „strop overlay, dno inset“ je bežná a musí fungovať.
- `line_drilling`: `enabled`, `pitch` (32), `offset_front`, `offset_back`,
  `start_height`, `end_offset` – rad otvorov pre nastaviteľné police; v1 ide do
  výstupu ako informácia k dielcu (bok/priečka), nekreslí sa.
- Dialóg zobrazuje **vypočítané vnútorné rozmery** (výška, šírka, hĺbka) a
  vnútorné rozmery každého stĺpca/poľa, aby bolo vidno, čo sa mení.
- `back_mode`: `groove` (HDF v drážke, `groove_depth`, `groove_offset`) |
  `overlay` (HDF nalozená zozadu, korpus sa o hrúbku skráti) |
  `inset` („priznaná“ – doska hrúbky `back_inset_thickness` medzi bokmi, police o ňu kratšie)
- **Čelá – presahy a špáry**: `front_gap_h` (3) a `front_gap_v` (3) – špára
  medzi susednými čelami vodorovne/zvisle; `front_reveal_top/bottom/left/right`
  (2/0/2/2) – o koľko je čelo kratšie než plný presah na danej strane korpusu
  (Blum „Gap/overlay“); spolu s `mount` určujú konečný rozmer čela
- `shelf_setback` (2) – polica zapustená za prednú hranu; `shelf_back_clearance`

**Stĺpce** – `columns: [ { width: {mode: mm|ratio|auto, value}, doors: {…}, handle_override: {…}|nil, cells: [ { height: {mode}, content: shelves|rod|drawers|inner_drawers|empty, shelves_count, drawers_count, drawer_heights: auto|[mm], rod_offset_top } ] } ]`
- Susedné stĺpce oddeľuje priečka (hrúbka corpus). Polia oddeľuje pevná polica.
- `shelves`: N nastaviteľných políc rovnomerne v poli (`shelf_supports` do kovania).
- `rod`: vešiaková tyč (kovanie, dĺžka = vnútorná šírka), `rod_offset_top`.
- `drawers`: N zásuviek s vonkajšími čelami; čelá vypĺňajú výšku poľa (auto)
  alebo zadané výšky.
- `inner_drawers`: zásuvky za dverami; čelo zapustené o `inner_drawer_setback`.
- Soklová zásuvka (Blum SPACE STEP) je mimo v1; architektúra polí ju neskôr
  umožní ako obsah spodku.

**Dvere (per stĺpec, globálny default)**
- `doors_enabled` (globálne; false = otvorený korpus / regál)
- `type`: `none` | `single_left` | `single_right` | `double` | `flap_up`
  (výklop hore – Blum AVENTOS HF/HS/HL/HK; pánt = kovanie `:lift`, zobrazenie
  „open“ otáča okolo hornej hrany)
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
3. **Kovanie**: pánty, výklopy, výsuvy (typ, nominálna dĺžka), tyče (mm),
   nožičky, úchytky, profil (mm), podpery políc, spojovací materiál
   (`joinery`: `dowels` | `confirmat` | `cam_lock` – počet na spoj podľa dĺžky,
   default 2 + 1/300 mm), závesné kovanie (`wall_brackets`, počet, pre horné
   skrinky).
4. **Sumár plôch** m² na materiál (informatívne, bez prirezu).

Exporty: CSV (UTF-8, `;`), CSV pre CutList Optimizer
(`Length;Width;Qty;Label;Enabled;Grain`), HTML (na tlač).

### 7.1 Inšpirácia Blum Cabinet Configurator

Prevzaté princípy: vonkajší rozmer + živo počítané vnútorné; per-panel nastavenia
(hrúbka, rohový spoj, odsadenia); presah/špára per strana čela; katalóg kovania
podľa výrobcu (pánty, výklopy, boxy, výsuvy) s tabuľkami rozmerov; „Extras“ ako
spojovací a závesný materiál. Rozdiel: náš plugin pracuje s celou skriňou
(viac stĺpcov/polí) a výstupom je nárezový plán, nie objednávka kovania.

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

## 11. Odchýlky v1 od tohto specu (zaznamenané pri implementácii)

- **Toolbar** nie je (vyžaduje ikony); príkazy sú v menu *Extensions › Skrine*
  (Nová skriňa · Nová skriňa z presetu… · Upraviť označenú · Nárezový plán) a v
  kontextovom menu skrine. Presety sa ukladajú/načítavajú aj z editora.
- **`materials.*.thickness`** ako default pre `*_thickness` nie je implementované;
  materiál má názov a farbu, hrúbky sú výhradne v skupine Konštrukcia/Zásuvky.
- **`Layout#envelope`** nahrádza `Layout#info` (`corpus_w/h/d`, `inner_w/h/d`,
  `columns[]`), ktoré dialóg zobrazuje ako vypočítané rozmery.
- **Spojovací materiál**: počet na spoj je `max(2, ceil(dĺžka / rozteč))`
  (namiesto „2 + 1/300 mm“).
- **Rad otvorov** sa do nárezového plánu dostáva ako poznámka pri dielci
  (stĺpec *Poznámka* v CSV, `<small>` v HTML); nekreslí sa.
- Súradnice, atribúty a vrstvy sú podľa §3–§5; verzia atribútov `version = 1`
  (migrácia = doplnenie chýbajúcich parametrov defaultmi).
