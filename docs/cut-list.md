# Cut list

**Extensions › Skrine › Nárezový plán**, or the button in the editor. With a
selection it covers the selected wardrobes, otherwise every wardrobe in the
model.

## Where the numbers come from

Each part in the model is a group carrying a `Skrine::Part` attribute
dictionary with its name, category, material, length, width, thickness, edge
banding flags and grain direction. Hardware that is not drawn (hinges, runners,
joinery) is stored on the wardrobe group itself. The cut list reads those
attributes, not the geometry — scaling a part in SketchUp does not change its
cut-list size.

## What the report contains

1. **Parts per material** — one table per material and thickness. Identical
   parts are merged into one row (same material, thickness, length, width, edge
   code and grain); the row is named after the first part with `(+n)` appended.
   Each table ends with the area in m² and the edge banding in metres.
2. **Edge banding** — metres per material, computed from the banded edges of
   every part.
3. **Hardware** — hinges, lifts, runners/boxes, hanging rails, legs, handles,
   handle profile (in mm), shelf supports, joinery and wall brackets.

Edges are written as `2D 1K`: `D` = long edges (the ones as long as the part's
length), `K` = short edges. Parts whose side or partition carries system-32
drilling get a note in the `Poznámka` column.

## Exports

| Button | File |
|---|---|
| **Export CSV** | UTF-8 with BOM, `;` separated, parts and hardware; opens directly in Excel |
| **Export pre CutList Optimizer** | `Length;Width;Qty;Label;Enabled;Grain` — import at [cutlistoptimizer.com](https://www.cutlistoptimizer.com/) |
| **Uložiť HTML** | The report as a standalone HTML file |
| **Tlač** | Print the report |

Fields containing `;`, `"` or newlines are quoted (RFC 4180), so a material name
like `DTD; "Egger" H1180` survives the export.

## Materials

Material names come from the **Materiály** tab and are what the cut list groups
by, so use the decor name you order (`DTD 18 biela`, `HDF 3 biela`, …). The
colour next to the name is only used in the SketchUp model.

## Known limitations

- Parts are not nested onto sheets; use CutList Optimizer (or any nesting tool)
  with the exported CSV.
- Hardware quantities follow simple rules (hinge table, joints per panel edge);
  check them before ordering.
- Drawer system tables ship with typical catalogue values and are editable in
  the editor — verify them against the current manufacturer catalogue.
