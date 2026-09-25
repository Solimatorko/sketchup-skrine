# User guide

The editor is a single window: the drawing on the left, the panel of the
selected element on the right, advanced settings collapsed at the bottom.
Labels in the editor are Slovak; this guide gives the English meaning.

![Editor](images/editor.png)

## Opening the editor

| Menu item (Slovak) | Meaning |
|---|---|
| Extensions › Skrine › **Nová skriňa** | New wardrobe at the origin, editor opens |
| Extensions › Skrine › **Nová skriňa z presetu…** | New wardrobe from a preset file |
| Extensions › Skrine › **Upraviť označenú skriňu** | Edit the selected wardrobe |
| Extensions › Skrine › **Nárezový plán** | Cut list for the selection, or for all wardrobes |
| Right-click a wardrobe › **Upraviť skriňu (Skrine)** | Edit that wardrobe |

A new wardrobe is placed next to the wardrobes already in the model, not on top
of them.

## The drawing

Four views: **s čelami** (with fronts), **bez čiel** (fronts hidden), **bok**
(side) and **pôdorys** (plan).

- **Click** a part to select it and open its panel: a door or a partition selects
  the column, a shelf, rail or drawer selects the cell, the plinth, legs or cover
  strips select the base, a side, top, bottom or back panel opens the carcass
  settings. Clicking an empty area of a cell selects that cell.
- **Blue dimensions can be retyped.** Click one, type a value, press Enter. The
  column or cell switches to a fixed millimetre size; the others keep sharing the
  remaining space. If the value does not fit, it is reverted, flashed red and the
  reason is shown below.
- Hovering highlights the part under the cursor.

## Panels

**Skriňa (wardrobe)** — placement between walls / corner / free standing, doors
on or off, default door type and mounting, how doors are drawn (closed or open;
opening only shows in the model), default handle, the list of columns, and a
shortcut to the base settings.

**Stĺpec (column)** — width (auto, mm or ratio), a gallery of **column modules**
that fill the column in one click, the list of cells, per-column door and handle
overrides, and buttons to move, duplicate or delete the column.

**Pole (cell)** — height (auto, mm or ratio) and the contents: adjustable
shelves (count), hanging rail (offset from the top), drawers or inner drawers
(count, optional explicit front heights), or empty. The drawer system is chosen
here too.

**Spodok a vrch (base and top)** — legs, plinth between the sides or standing on
the floor, base height, plinth setback and floor clearance, ceiling gap and top
cover strip, wall gaps and filler strips.

## Advanced settings

Collapsed at the bottom, in five tabs: **Konštrukcia** (panel thicknesses, corner
joints, recesses, back panel mode, shelf setbacks, system-32 drilling), **Čelá a
špáry** (front gaps, reveals, inset depth, grain direction), **Zásuvky** (drawer
system tables and box dimensions), **Materiály** (name and colour per material)
and **Kovanie a hrany** (joinery, wall brackets, edge banding rules).

Every parameter with its default and range is listed in
[parameters.md](parameters.md).

## Applying to the model

- **Auto** on — the SketchUp model is rebuilt after every change (debounced).
- **Auto** off — press **Použiť v SketchUpe** (Apply in SketchUp).
- Every rebuild is one undoable operation, and the wardrobe keeps its position.
- Below the buttons the editor shows the computed inner dimensions, the inner
  width of every column and the height of every cell, plus errors (red) and
  warnings (orange).

## Presets and the gallery

- **Galéria skríň** (wardrobe gallery) — thumbnails of the built-in presets and
  your own. *Použiť na túto skriňu* loads a preset into the wardrobe you are
  editing; *Vytvoriť novú* builds a new wardrobe from it.
- **Presety ▾ › Uložiť do galérie…** — save the current parameters under a name;
  the preset lands in your user folder and appears in the gallery.
- **Presety ▾ › Uložiť do súboru… / Načítať zo súboru…** — plain JSON files.

A preset is partial JSON: only the keys it contains override the defaults.

## Cut list

See [cut-list.md](cut-list.md).
