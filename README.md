# Skrine – parametrické skrine pre SketchUp

Ruby extension pre SketchUp 2026. Skriňa sa generuje z parametrov (rozmery,
konštrukcia, stĺpce/polia, dvere, zásuvky, úchytky, materiály) a po každej zmene
sa pregeneruje. Z modelu sa exportuje nárezový plán a kusovník kovania.

## Použitie
1. Extensions › Skrine › **Nová skriňa** – vloží skriňu na počiatok a otvorí editor.
2. Uprav parametre (záložky Rozmery, Konštrukcia, Čelá a špáry, Dvere, Úchytky, Zásuvky, Stĺpce, Materiály, Kovanie a hrany) → **Použiť** alebo zapni **Auto**.
3. Skriňu presuň štandardným nástrojom Move; pravý klik na skriňu → **Upraviť skriňu**.
4. **Nárezový plán** – tabuľky podľa materiálu, hranovanie, kovanie; export CSV / CutList Optimizer / HTML.
5. Presety: `presets/*.json` – čiastočné JSON parametre, načítajú sa cez Načítať preset.

Rozmery dielcov sú uložené v atribútoch (`Skrine::Part`) každej groupy; nárezový plán číta atribúty, nie geometriu.
Tabuľky zásuvkových systémov (Blum LEGRABOX / TANDEMBOX / MERIVOBOX) sú predvolené hodnoty – over ich v aktuálnom katalógu a uprav v záložke Zásuvky.

## Vývoj
- `scripts/install_dev.sh` – symlink do SketchUp Plugins
- Testy: `/opt/homebrew/opt/ruby/bin/ruby -Isrc -Itest test/run_all.rb`
- Spec: `docs/superpowers/specs/2026-09-19-skrine-plugin-design.md`
