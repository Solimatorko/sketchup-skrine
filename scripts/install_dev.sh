#!/usr/bin/env bash
# Symlinks the plugin into SketchUp 2026 Plugins so edits are live after "Reload".
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)/src"
DST="$HOME/Library/Application Support/SketchUp 2026/SketchUp/Plugins"
ln -sfn "$SRC/skrine.rb" "$DST/skrine.rb"
ln -sfn "$SRC/skrine" "$DST/skrine"
echo "Linked $SRC -> $DST"
