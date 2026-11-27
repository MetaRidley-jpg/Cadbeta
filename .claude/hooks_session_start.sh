#!/bin/bash
# SessionStart hook: only in Claude Code cloud sessions (local PCs already have Godot).
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0
# Web templates are skipped: they are a ~1 GB download and only a local web export needs them
# (CI has its own copy). Get them with: bash tools/setup_godot.sh
SKIP_TEMPLATES=1 bash "$CLAUDE_PROJECT_DIR/tools/setup_godot.sh"
