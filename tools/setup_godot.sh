#!/bin/bash
# Set up a fresh Linux box (Claude Code cloud session, CI, a new PC) to build and test Cadavire.
# Installs: Godot 4.7.2 (headless-capable editor binary) on PATH, the web export templates,
# xvfb (to record movies without a screen), librsvg (vector import), ffmpeg, Python Pillow.
# Safe to run again: each step is skipped when it is already done.
# usage: bash tools/setup_godot.sh            (all)
#        SKIP_TEMPLATES=1 bash tools/setup_godot.sh   (no web templates: tests only)
# Runs on its own as the SessionStart hook in .claude/settings.json (cloud sessions only).
set -uo pipefail
V="${GODOT_VERSION:-4.7.2}"
BIN_DIR="$HOME/godot"
URL="https://github.com/godotengine/godot/releases/download/${V}-stable"
log() { echo "[setup_godot] $*"; }

# 1. Godot
have=""
command -v godot >/dev/null 2>&1 && have="$(godot --version 2>/dev/null | cut -d. -f1-3)"
if [ "$have" = "$V" ]; then
  log "godot $V already on PATH ($(command -v godot))"
else
  if [ ! -x "$BIN_DIR/godot" ]; then
    log "downloading Godot $V ..."
    mkdir -p "$BIN_DIR"
    curl -fsSL -o /tmp/godot.zip "$URL/Godot_v${V}-stable_linux.x86_64.zip" \
      && unzip -q -o /tmp/godot.zip -d "$BIN_DIR" \
      && mv -f "$BIN_DIR/Godot_v${V}-stable_linux.x86_64" "$BIN_DIR/godot" \
      && rm -f /tmp/godot.zip \
      || { log "ERROR: Godot download failed (network allowlist? github.com release assets must be reachable)"; exit 0; }
  fi
  mkdir -p "$HOME/.local/bin"
  ln -sf "$BIN_DIR/godot" "$HOME/.local/bin/godot"
  export PATH="$HOME/.local/bin:$PATH"
  # keep it on PATH for the rest of a Claude Code session
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$CLAUDE_ENV_FILE"; fi
  log "godot: $("$BIN_DIR/godot" --version)"
fi

# 2. Web export templates (only the web ones, ~40 MB of a ~1 GB archive)
T="$HOME/.local/share/godot/export_templates/${V}.stable"
if [ -z "${SKIP_TEMPLATES:-}" ] && [ ! -f "$T/web_nothreads_release.zip" ]; then
  log "downloading web export templates ..."
  mkdir -p "$T"
  curl -fsSL -o /tmp/templates.tpz "$URL/Godot_v${V}-stable_export_templates.tpz" \
    && unzip -q -o -j /tmp/templates.tpz 'templates/web*' 'templates/version.txt' -d "$T" \
    && rm -f /tmp/templates.tpz \
    || log "WARN: templates failed (only needed for a local web export; CI has its own)"
fi

# 3. System tools for recording / art import (best effort: apt may be blocked)
need=""
command -v xvfb-run >/dev/null 2>&1 || need="$need xvfb"
command -v rsvg-convert >/dev/null 2>&1 || need="$need librsvg2-bin"
command -v ffmpeg >/dev/null 2>&1 || need="$need ffmpeg"
if [ -n "$need" ]; then
  SUDO=""; [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"
  log "apt install:$need"
  ($SUDO apt-get update -qq && $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $need libgl1 libgl1-mesa-dri >/dev/null) \
    || log "WARN: apt failed; tests still run headless, but no recordings / vector import"
fi
python3 -c "import PIL" 2>/dev/null || pip install -q --break-system-packages Pillow 2>/dev/null || pip install -q Pillow || log "WARN: Pillow missing"

# 4. First import (builds .godot/ caches so class_name scripts resolve)
cd "$(dirname "$0")/.."
if [ ! -d .godot ]; then
  log "first import ..."
  godot --headless --path . --import >/dev/null 2>&1 || true
fi
log "done. Smoke test: godot --headless --path . res://tests/test_runner.tscn --quit-after 30000 -- --fresh"
exit 0
