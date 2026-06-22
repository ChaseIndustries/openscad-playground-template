#!/usr/bin/env bash
# Convenience wrapper — same args as the skill's qa-views.sh
exec "$(cd "$(dirname "$0")/.." && pwd)/.agents/skills/verify-design/scripts/qa-views.sh" "$@"
