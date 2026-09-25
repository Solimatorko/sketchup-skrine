# Installation

## From this repository (recommended while developing)

```bash
git clone https://github.com/Solimatorko/sketchup-skrine.git
cd sketchup-skrine
scripts/install_dev.sh
```

`install_dev.sh` creates two symlinks in SketchUp's Plugins folder, so the
extension always runs the code in your checkout:

| Link | Target |
|---|---|
| `…/SketchUp/Plugins/skrine.rb` | `src/skrine.rb` |
| `…/SketchUp/Plugins/skrine` | `src/skrine/` |

Plugins folder:

- **macOS** — `~/Library/Application Support/SketchUp 2026/SketchUp/Plugins`
- **Windows** — `%AppData%\SketchUp\SketchUp 2026\SketchUp\Plugins`
  (the script is macOS-only; on Windows copy or link the two entries yourself)

Restart SketchUp. A **Skrine** submenu appears under **Extensions**.

## Without git

Download the repository as a ZIP, unpack it and copy `src/skrine.rb` and
`src/skrine/` into the Plugins folder listed above.

## Update

```bash
git pull
```

Then either restart SketchUp or reload the code in the Ruby Console
(**Extensions › Developer › Ruby Console**):

```ruby
load '/path/to/sketchup-skrine/scripts/reload.rb'
```

The reload prints `Skrine reloaded (x.y.z); menu registered`. "Warning: already
initialized constant …" lines are normal when reloading.

## Uninstall

Delete `skrine.rb` and `skrine/` from the Plugins folder and restart SketchUp.
User presets stay in `~/Library/Application Support/Skrine/presets` (macOS) or
`~/.skrine/presets`.

## Troubleshooting

**The Skrine menu is missing.** The extension failed to load. Open the Ruby
Console and run the reload command above; it registers the menu even after a
failed start-up load and writes a log to `/tmp/skrine-load.log` (macOS) with the
exception.

**The editor window stays empty.** The page could not fetch its state. The
dialog retries for five seconds and then shows a message; JavaScript errors are
printed to the Ruby Console with a `[Skrine]` prefix and appended to the same
log file.

**Nothing happens after "Upraviť označenú skriňu" (Edit selected).** Only
wardrobes created by this extension can be edited — they carry a `Skrine`
attribute dictionary. Hand-modelled geometry is not recognised.

**A preset cannot be loaded.** Presets are only read from the repository's
`presets/` folder and from the user preset folder; a JSON file elsewhere is
rejected on purpose.
