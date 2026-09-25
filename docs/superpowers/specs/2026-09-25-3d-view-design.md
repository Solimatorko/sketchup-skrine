# Skrine – 3D náhľad a pravítko (UI doplnok) – návrh

Dátum: 2026-09-25 · Nadväzuje na `2026-09-20-visual-editor-design.md`.
Nemení model ani SketchUp vrstvu; pridáva piaty pohľad do editora.

## 1. Cieľ

V lište pohľadov pribudne **3D**: rovnaká scéna (`Export::Scene`) vykreslená
cez WebGL (three.js) priamo v dialógu aj v prehliadači. Slúži na kontrolu
návrhu bez SketchUpu a na meranie vzdialeností.

Mimo rozsahu: fotorealistický render, textúry dekorov, tiene, export obrázka.

## 2. Vykreslenie

- **three.js sa vendoruje** do `src/skrine/ui/html/libs/three.min.js` (+ vlastný
  orbit ovládač, aby nepribúdali ďalšie súbory) – dialóg môže byť offline.
- Každý box scény = `BoxGeometry` + `MeshLambertMaterial` vo farbe materiálu
  (`materials[*].color`), plus `LineSegments` z `EdgesGeometry` (tenké čierne
  hrany, „technický“ vzhľad). Kovanie so `box` sivé.
- Osvetlenie: `HemisphereLight` + jedno smerové svetlo, bez tieňov.
- Scéna sa stavia raz za `setPreview`; pri zmene parametrov sa prestaví
  (pár stoviek boxov – lacné).
- Kamera: perspektíva, orbit (ľavé tlačidlo), posun (pravé/stred), zoom
  kolieskom; tlačidlá **predok / bok / zhora / axonometria** a **priblížiť na
  výber**.
- Prepínače: **bez čiel** (skryje `door`, `drawer_front`, lišty – rovnaké
  pravidlá ako 2D), **otvorené dvere** (použije `rotation` z dielca),
  **rez** (posuvník `clippingPlanes` odreže prednú časť).
- Klik na dielec = rovnaký výber ako v 2D (`Drawing.targetFor`), hover zvýrazní
  oranžovo; panel vpravo sa nemení.
- Ak `WebGLRenderingContext` nie je k dispozícii, karta 3D sa skryje a editor
  funguje ako doteraz.

## 3. Pravítko (meranie)

Tlačidlo **Meranie** v lište 3D.

- **Snap body** sa počítajú z boxov scény (nie z meshu): 8 rohov, 12 stredov
  hrán, 6 stredov plôch pre každý viditeľný box. Kandidáti sa premietnu do
  obrazovky a vyberie sa najbližší do 12 px; farba podľa typu (roh zelený,
  hrana modrá, plocha sivá). Ak nič nie je v dosahu, použije sa presný priesečník
  lúča s plochou.
- Prvý klik = začiatok, druhý = koniec. Zobrazí sa čiara s koncovými značkami a
  štítok `1234,5 mm` + rozklad `ΔX 973 · ΔY 0 · ΔZ 760`.
- Merania zostávajú v zozname pod nákresom (názov, hodnota, tlačidlo ✕);
  **Escape** ruší rozrobené, **Vymazať všetko** zoznam.
- **„Použiť ako rozmer“** (voľba 2): ak meranie zodpovedá parametru, ponúkne sa
  tlačidlo. Priradenie podľa osi a dotknutých dielcov:
  - ΔY medzi dvoma bodmi na boku/zadnej stene → `depth`
  - ΔX medzi vonkajšími bokmi → `width`, medzi priečkami jedného stĺpca →
    `columns[i].width` (prepne na `mm`)
  - ΔZ medzi podlahou a stropom → `height`, medzi policami jedného poľa →
    `columns[i].cells[j].height`
  - ΔX/ΔZ v rámci jedného dielca (rovnaký `boxId`) → jeho hrúbka/rozmer sa
    neprepisuje (ponuka sa nezobrazí).
  Tlačidlo zapíše hodnotu cez `Skrine.setPath(path, value)` – teda rovnaká cesta
  ako pri editovateľných kótach, vrátane revertu pri chybe.

## 4. Súbory

```
src/skrine/ui/html/libs/three.min.js   (vendored, MIT)
src/skrine/ui/html/viewer3d.js          scéna, kamera, orbit, výber, rez
src/skrine/ui/html/measure.js           snap body, meranie, „použiť ako rozmer“
src/skrine/ui/html/app.js               karta 3D v lište pohľadov, prepojenie
src/skrine/ui/html/style.css            lišta 3D, zoznam meraní
```

## 5. Testovanie

- `node --check`; browser QA cez `scripts/ui`: 3D sa vykreslí, orbit, prepínače,
  klik vyberie ten istý prvok ako v 2D, meranie roh–roh dá očakávanú hodnotu
  (napr. vnútorná šírka 1964 mm), „použiť ako rozmer“ zmení parameter a nákres.
- Ruby testy nezmenené.
- SketchUp: `scripts/reload.rb`, otvoriť editor, karta 3D (overí WebGL v dialógu).
