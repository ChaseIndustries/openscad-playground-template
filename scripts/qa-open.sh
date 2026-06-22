#!/usr/bin/env bash
# Convenience wrapper — interactive project picker that opens the OpenSCAD GUI.
# Same args as the skill's qa-open.sh.
exec "$(cd "$(dirname "$0")/.." && pwd)/.agents/skills/verify-design/scripts/qa-open.sh" "$@"
