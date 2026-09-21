# Skrine – parametrické skrine pre SketchUp

Ruby extension pre SketchUp 2026. Skriňa sa generuje z parametrov (rozmery,
konštrukcia, stĺpce/polia, dvere, zásuvky, úchytky, materiály) a po každej zmene
sa pregeneruje. Z modelu sa exportuje nárezový plán a kusovník kovania.

## Použitie
1. Extensions › Skrine › **Nová skriňa** – vloží skriňu na počiatok a otvorí vizuálny editor.
2. **Nákres** hore zobrazuje skriňu spredu (aj bez čiel, zboku, pôdorys – prepínač nad nákresom). Klikni na stĺpec, pole, dvere alebo sokel priamo v nákrese – vpravo sa otvorí príslušný panel. Modré kóty (šírka, výška, hĺbka, šírky stĺpcov, výšky polí) sa dajú prepísať kliknutím – neplatná hodnota sa na chvíľu zvýrazní červeno a vráti pôvodnú hodnotu.
3. **Panely vpravo** podľa výberu:
   - nič vybrané → globálne parametre skrine (osadenie, dvere, úchytka, zoznam stĺpcov, spodok/vrch);
   - stĺpec → šírka (auto/mm/pomer) a **knižnica modulov** – karty s piktogramom (veniec, police, zásuvky, kombinácie…), klik okamžite prepíše obsah stĺpca;
   - pole → výška (auto/mm/pomer) a karty obsahu poľa (police, tyč, zásuvky, vnorené zásuvky, prázdne) + parametre zásuviek;
   - sokel/konštrukcia → skratka do príslušnej záložky Rozšírených nastavení.
4. **Galéria skríň** (tlačidlo v hlavičke) ukazuje uložené presety s živým náhľadom; „Použiť na túto skriňu“ prepíše aktuálnu skriňu, „Vytvoriť novú“ vloží ďalšiu. **Presety ▾** ponúka uloženie do galérie/súboru a načítanie zo súboru.
5. **Rozšírené nastavenia** (skladacia sekcia pod nákresom) – záložky Konštrukcia, Čelá a špáry, Zásuvky, Materiály, Kovanie a hrany; časté enumy majú piktogramové karty, ostatné bežný výber.
6. **Auto** (pri tlačidle Použiť) po každej zmene rovno prekreslí model v SketchUpe; keď je vypnuté, zmeny sa len prepočítajú v náhľade a do modelu sa prenesú až tlačidlom **Použiť v SketchUpe**.
7. Skriňu presuň štandardným nástrojom Move; pravý klik na skriňu → **Upraviť skriňu**.
8. **Nárezový plán** – tabuľky podľa materiálu, hranovanie, kovanie; export CSV / CutList Optimizer / HTML.
9. Presety: `presets/*.json` – čiastočné JSON parametre, načítajú sa cez galériu alebo Načítať zo súboru.

Poznámka: prepínač „Zobrazenie dverí → otvorené“ ovplyvňuje len 3D model (dvere sa v ňom vykreslia pootočené); nákres v editore ostáva vždy zatvorený, o čom informuje text pod prepínačom.

Rozmery dielcov sú uložené v atribútoch (`Skrine::Part`) každej groupy; nárezový plán číta atribúty, nie geometriu.
Tabuľky zásuvkových systémov (Blum LEGRABOX / TANDEMBOX / MERIVOBOX) sú predvolené hodnoty – over ich v aktuálnom katalógu a uprav v záložke Zásuvky.

## Vývoj
- `scripts/install_dev.sh` – symlink do SketchUp Plugins
- Testy: `/opt/homebrew/opt/ruby/bin/ruby -Isrc -Itest test/run_all.rb`
- `scripts/ui_server.rb` – samostatný dev server pre stránku editora bez SketchUpu, so stubom `window.sketchup` nad HTTP: `/opt/homebrew/opt/ruby/bin/ruby scripts/ui_server.rb` → http://localhost:8792/. Funguje aj v shelli bez UTF-8 locale (LANG/LC_ALL) – vynucuje `Encoding::UTF_8`.
- `scripts/reload.rb` – znovu načíta zdrojáky pluginu do bežiaceho SketchUpu (Ruby Console): `load '/Users/milos/Git/sketchup-skrine/scripts/reload.rb'`.
- `scripts/verify.rb` – v SketchUpe vytvorí všetky presety vedľa seba, otvorí editor nad prvým a uloží screenshot/log (`load '/Users/milos/Git/sketchup-skrine/scripts/verify.rb'`).
- `scripts/preview.rb` – rýchly CLI náhľad rozloženia (bez SketchUpu aj bez prehliadača): `/opt/homebrew/opt/ruby/bin/ruby -Isrc scripts/preview.rb [preset.json] [out.html]` vykreslí SVG pohľady (spredu/zboku/pôdorys) do HTML súboru – hodí sa na rýchlu kontrolu rozmerov/rozloženia priamo z konzoly.
- Spec: `docs/superpowers/specs/2026-09-19-skrine-plugin-design.md`, `docs/superpowers/specs/2026-09-20-visual-editor-design.md`
