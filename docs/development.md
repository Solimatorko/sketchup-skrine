# Development

## Setup

The pure Ruby layer runs outside SketchUp, so the test suite needs a normal
Ruby 3.2+ (SketchUp 2026 embeds Ruby 3.2 — do not use language features newer
than that). On macOS:

```bash
brew install ruby        # /opt/homebrew/opt/ruby/bin/ruby
scripts/install_dev.sh   # symlink the checkout into SketchUp's Plugins folder
```

## Everyday commands

```bash
# tests (128 examples, no SketchUp needed)
/opt/homebrew/opt/ruby/bin/ruby -Isrc -Itest test/run_all.rb

# the editor in a browser: starts the dev server and opens it
scripts/ui              # http://localhost:8792/
scripts/ui icons        # pictogram catalogue
scripts/ui drawing      # drawing test page with a click log
scripts/ui stop

# syntax checks
/opt/homebrew/opt/ruby/bin/ruby -wc src/skrine/**/*.rb
node --check src/skrine/ui/html/app.js

# regenerate docs/parameters.md from the schema
/opt/homebrew/opt/ruby/bin/ruby -Isrc scripts/gen_docs.rb

# static SVG previews of a preset (front, side, plan) as one HTML file
/opt/homebrew/opt/ruby/bin/ruby -Isrc scripts/preview.rb presets/satnik-2-stlpce.json /tmp/preview.html
```

## Inside SketchUp

Ruby Console (**Extensions › Developer › Ruby Console**):

```ruby
load '/path/to/sketchup-skrine/scripts/reload.rb'   # reload code + register the menu
load '/path/to/sketchup-skrine/scripts/verify.rb'   # build all presets, rebuild one, cut list, screenshot
```

`scripts/diag`-style logging: `src/skrine/sketchup/diag.rb` appends load and
error messages to `/tmp/skrine-load.log`, and JavaScript errors from the dialog
are forwarded there as well. Touching `/tmp/skrine-selftest.request` before
starting SketchUp runs a self-test after start-up (builds a wardrobe, opens the
editor, saves `/tmp/skrine-selftest.png`).

## Tests

`test/` mirrors `src/`. The suite covers the parameter schema, the sizing rules,
the whole wardrobe generator (corpus, columns, fronts, drawers, extras), the
scene JSON, the cut list, the preset store and the column modules, plus a
"SketchUp shape" test that stubs `UI`/`Sketchup` and builds the dialog, which is
what catches mistakes that only appear inside SketchUp.

The JavaScript has no automated tests; it is checked with `node --check` and a
browser pass over `scripts/ui`.

## Adding a new object type

`Core::Registry` makes the dialog, the storage, the builder and the cut list
type-agnostic. A new type (for example a wide top cabinet spanning several
modules) needs:

1. `src/skrine/<type>/params.rb` — a `ParamSchema`.
2. `src/skrine/<type>/model.rb` — `#layout` returning a `Core::Layout`.
3. `Core::Registry.register(:<type>, label:, schema:, model_class:)`.
4. A menu entry calling `SU::Commands.new_object(:<type>)`.

Everything else (editor, preview, gallery, cut list, attributes) works without
changes as long as the model fills `layout.info` the way `Export::Scene`
expects.

## Conventions

- Code and comments in English, user-facing strings in Slovak.
- Millimetres as `Float` everywhere except `sketchup/units.rb`.
- `core`, `data`, `wardrobe`, `export`, `ui/preview_service.rb` must not
  reference `Sketchup`, `UI` or `Geom`.
- Never define a constant named `UI` inside `module Skrine` (see
  [architecture.md](architecture.md)).
- Commit messages: `feat:`, `fix:`, `test:`, `docs:`, `chore:`.

## Design documents

`docs/superpowers/specs/` and `docs/superpowers/plans/` hold the design specs and
implementation plans (in Slovak) for the generator, the visual editor and the
planned stepped editor.
