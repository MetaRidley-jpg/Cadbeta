#!/bin/bash
# Bake every dogfight sprite atlas to art/baked/ (PNG + JSON), then import the PNGs.
# Run after you change art/stacks/* or a code model in df_render / df_plane / df_weather.
# If you forget: dev runs print "art/baked/<key> is stale" and bake live; CI re-bakes before export.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="$(command -v godot || echo "$HOME/godot/godot")"
out="$("$GODOT" --headless --path . res://tools/bake/bake_sprites.tscn -- --fresh --bakesprites 2>&1 || true)"
echo "$out" | grep -E "BAKED|SCRIPT ERROR" || true
echo "$out" | grep -q "^BAKED " || { echo "bake FAILED"; exit 1; }
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
ls art/baked/*.json | wc -l | xargs echo "baked files:"
