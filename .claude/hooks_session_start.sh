#!/bin/bash
# SessionStart hook: only in Claude Code cloud sessions (local PCs already have Godot).
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0
bash "$CLAUDE_PROJECT_DIR/tools/setup_godot.sh"
