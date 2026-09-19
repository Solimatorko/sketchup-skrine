# Skrine – parametrické skrine pre SketchUp

Ruby extension pre SketchUp 2026. Skriňa sa generuje z parametrov (rozmery,
konštrukcia, stĺpce/polia, dvere, zásuvky, úchytky, materiály) a po každej zmene
sa pregeneruje. Z modelu sa exportuje nárezový plán a kusovník kovania.

## Vývoj
- `scripts/install_dev.sh` – symlink do SketchUp Plugins
- Testy: `/opt/homebrew/opt/ruby/bin/ruby -Isrc -Itest test/run_all.rb`
- Spec: `docs/superpowers/specs/2026-09-19-skrine-plugin-design.md`
