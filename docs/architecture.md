# Architecture

## Layers

```
src/skrine.rb                 SketchupExtension registration
src/skrine/loader.rb          requires everything, menu and context menu

src/skrine/core/              pure Ruby, no SketchUp API
  param_schema.rb             parameter schema: defaults, coercion, validation, to_h
  box.rb part.rb hardware.rb  value objects (millimetres)
  layout.rb                   result of a generator: parts, hardware, info, messages
  sizing.rb                   distributing a length over mm / ratio / auto items
  registry.rb                 object types (wardrobe, …)
  preset_store.rb             built-in and user presets

src/skrine/data/              catalogue data (drawer systems, column modules)
src/skrine/wardrobe/          the wardrobe generator: params → Layout
  params.rb model.rb corpus.rb columns.rb fronts.rb drawers.rb extras.rb
src/skrine/export/
  scene.rb                    Layout → scene JSON for the drawing
  cutlist.rb                  Layout/model parts → cut list, CSV, HTML

src/skrine/sketchup/          the only files that touch the SketchUp API
  units.rb storage.rb builder.rb selection.rb commands.rb presets.rb
  cutlist_command.rb diag.rb
src/skrine/ui/
  preview_service.rb          pure: preview / init payload / gallery
  dialog.rb                   HtmlDialog and its callbacks
  html/                       the editor page (vanilla JS, no build step)
```

Everything in `core`, `data`, `wardrobe`, `export` and `ui/preview_service.rb`
is plain Ruby: it runs (and is tested) without SketchUp. Dimensions are
millimetres as `Float`; the conversion to SketchUp's inches happens only in
`sketchup/units.rb`.

> The namespace `Skrine::UI` must never exist: SketchUp defines a global `UI`
> module, and a constant with the same name inside `module Skrine` would shadow
> it for every unqualified `UI.…` call. The editor service lives in
> `Skrine::Editor`; a guard test keeps it that way.

## Coordinates

X = width (left to right), Y = depth (the front plane of the fronts is 0, the
carcass grows towards +Y), Z = height (floor is 0). `width`, `height` and
`depth` are outside dimensions.

## From parameters to geometry

1. `Params::SCHEMA.merge_defaults(values)` fills defaults and coerces types.
2. `Wardrobe::Model#layout` builds a `Core::Layout`: a list of `Part`s (with a
   `Box` each) and `HardwareItem`s, plus `info` (computed inner sizes, columns
   and cells) and `errors` / `warnings`.
3. `SU::Builder` turns the layout into SketchUp groups inside one group per
   wardrobe, writes the attributes and applies materials. Rebuilding clears the
   group's entities and rebuilds in place inside a single undoable operation.

## Data stored in the model

| Dictionary | On | Keys |
|---|---|---|
| `Skrine` | wardrobe group | `type`, `version`, `params` (JSON), `hardware` (JSON) |
| `Skrine::Part` | part group | name, category, material, length, width, thickness, edges, grain, meta |
| `Skrine::Hardware` | drawn hardware group | kind, name, qty, unit, meta |

Because the parameters travel with the group, any wardrobe can be reopened and
edited later, and `merge_defaults` migrates parameters saved by older versions.

## Scene JSON

`Export::Scene.build(layout, params)` produces what the drawing needs:

```json
{
  "size": { "w": 2000.0, "h": 2400.0, "d": 600.0 },
  "boxes": [{ "id": "p17", "kind": "door", "column": 1, "cell": null,
              "name": "Dvere S1 Ľ", "category": "front",
              "x": 2.0, "y": 0.0, "z": 728.5, "dx": 496.75, "dy": 18.0, "dz": 1639.5 }],
  "columns": [{ "index": 1, "x": 18.0, "w": 973.0 }],
  "cells": [{ "column": 1, "cell": 1, "x": 18.0, "z": 736.0, "w": 973.0, "h": 1646.0,
              "content": "rod" }],
  "dims": [{ "id": "col-1", "axis": "x", "from": 18.0, "to": 991.0, "at": 2450.0,
             "value": 973.0, "edit": "columns.0.width" }]
}
```

`kind` drives the colour and what a click selects; `edit` is the path in the
parameter state that a dimension edits.

## Dialog bridge

The page never computes geometry. It sends the parameter state to Ruby and gets
a scene back:

| JS → Ruby | Ruby → JS |
|---|---|
| `sketchup.preview(json, seq)` | `Skrine.setPreview({scene, info, errors, warnings, seq})` |
| `sketchup.apply(json, seq)` | `Skrine.setResult({errors, warnings, info, seq})` |
| `sketchup.gallery()` | `Skrine.showGallery([{file, name, scene}])` |
| `sketchup.use_preset(file, mode)` | `Skrine.init(payload)` |
| `sketchup.save_named_preset(json, name)`, `save_preset`, `load_preset`, `cutlist`, `new_object`, `log` | `Skrine.init(payload)` on open |

`preview` is cheap and never touches the model; `apply` rebuilds it. Responses
carry the sequence number of the request so stale answers are ignored.

Because the contract is plain HTTP-shaped JSON, `scripts/ui_server.rb` can serve
the same page outside SketchUp with a `window.sketchup` stub — that is how the
editor is developed and tested in a browser.
