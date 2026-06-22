#!/usr/bin/env bash
# qa-zfloor.sh <mode>
# Verify no part geometry is below Z=0. A buried part won't print.
set -euo pipefail
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" || "${HELP:-0}" == "1" ]]; then
  cat <<'EOF'
qa-zfloor.sh <mode>
Exports STL and fails if any vertex Z < 0 (geometry below print bed).
Env: OPENSCAD=  PLAYGROUND_PROJECT=
EOF
  exit 0
fi
MODE=${1:?Usage: qa-zfloor.sh <mode>}
_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=./qa-project.sh
source "${_SCRIPT_DIR}/qa-project.sh"
# shellcheck source=./qa-common.sh
source "${_SCRIPT_DIR}/qa-common.sh"
qa_project_resolve || exit $?
OPENSCAD="${OPENSCAD:-openscad}"
SCRATCH="${PROJECT_BUILD_DIR}/qa/.cache"
mkdir -p "$SCRATCH"
OUT="${SCRATCH}/check_zfloor_m${MODE}.stl"
LOG=$(mktemp "${SCRATCH}/qa_zfloor_log.XXXXXX")
trap 'rm -f "$LOG"' EXIT
cd "$PLAYGROUND_PROJECT_DIR"
qa_ensure_view_camera || exit 1

echo "=== Z-floor check: $PLAYGROUND_PROJECT mode $MODE ==="
set +e
"$OPENSCAD" --export-format=asciistl -o "$OUT" -D "mode=$MODE" "$PROJECT_SCAD" >"$LOG" 2>&1
SCAD_EC=$?
set -e
if [ "$SCAD_EC" -ne 0 ]; then
  echo "FAIL - OpenSCAD exited $SCAD_EC"
  cat "$LOG"
  exit 1
fi

if ! grep -qE "[[:space:]]vertex[[:space:]]" "$OUT"; then
  echo "FAIL - no vertices found in STL (parse or export issue)"
  exit 1
fi
MIN_Z=$(grep -E "[[:space:]]vertex[[:space:]]" "$OUT" | awk '
  { z = $4 + 0; if (NR == 1 || z < min) min = z }
  END { print min + 0 }
')
echo "Lowest 5 Z vertices:"
grep -E "[[:space:]]vertex[[:space:]]" "$OUT" | awk '{print $4}' | sort -g | head -5 || true
if awk -v z="$MIN_Z" 'BEGIN { if (z < 0) exit 0; else exit 1 }'; then
  echo "FAIL - min Z=$MIN_Z (geometry underground)"
  exit 1
else
  echo "PASS - min Z=$MIN_Z"
fi
