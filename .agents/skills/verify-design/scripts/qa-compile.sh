#!/usr/bin/env bash
# qa-compile.sh <mode>
# Compile a mode, fail on warnings/errors or zero triangles.
set -euo pipefail
_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=./qa-project.sh
source "${_SCRIPT_DIR}/qa-project.sh"
# shellcheck source=./qa-common.sh
source "${_SCRIPT_DIR}/qa-common.sh"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" || "${HELP:-0}" == "1" ]]; then
  cat <<'EOF'
qa-compile.sh <mode>
Exports ASCII STL to build/qa/.cache/, fails on WARNING/ERROR/assert or zero triangles.
Env: OPENSCAD=  PLAYGROUND_PROJECT=
EOF
  exit 0
fi

MODE=${1:?Usage: qa-compile.sh <mode>}
qa_project_resolve || exit $?
OPENSCAD="${OPENSCAD:-openscad}"
SCRATCH="${PROJECT_BUILD_DIR}/qa/.cache"
mkdir -p "$SCRATCH"
OUT="${SCRATCH}/qa_compile_m${MODE}.stl"
LOG=$(mktemp "${SCRATCH}/qa_compile_log.XXXXXX")
trap 'rm -f "$LOG"' EXIT
cd "$PLAYGROUND_PROJECT_DIR"
qa_ensure_view_camera || exit 1

echo "=== Compile check: $PLAYGROUND_PROJECT mode $MODE ==="
set +e
"$OPENSCAD" --export-format=asciistl -o "$OUT" -D "mode=$MODE" "$PROJECT_SCAD" >"$LOG" 2>&1
SCAD_EC=$?
set -e
if [ "$SCAD_EC" -ne 0 ]; then
  echo "FAIL - OpenSCAD exited $SCAD_EC"
  cat "$LOG"
  exit 1
fi

WARNINGS=$(grep -E "WARNING|ERROR|assert" "$LOG" | grep -Fv "Viewall and autocenter disabled" || true)
if [ -n "$WARNINGS" ]; then
  echo "FAIL - warnings/errors:"
  echo "$WARNINGS"
  exit 1
else
  echo "CLEAN (no warnings)"
fi

TRIANGLES=$(grep -c "facet normal" "$OUT" 2>/dev/null || echo 0)
TRIANGLES=$((TRIANGLES + 0))
echo "Triangle count: $TRIANGLES"
if [ "$TRIANGLES" -eq 0 ]; then
  echo "FAIL - zero triangles (silent CGAL failure or empty geometry)"
  exit 1
fi
echo "PASS"
