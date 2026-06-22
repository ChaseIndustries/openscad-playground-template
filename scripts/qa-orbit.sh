#!/usr/bin/env bash
exec "$(cd "$(dirname "$0")/.." && pwd)/.agents/skills/verify-design/scripts/qa-orbit.sh" "$@"
