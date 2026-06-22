#!/usr/bin/env bash
# qa-thrown.sh <mode> <qa_dir>
# ThrownTogether preview PNG. Purple/magenta = inverted normals / non-manifold.
set -euo pipefail

_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=./qa-project.sh
source "${_SCRIPT_DIR}/qa-project.sh"
# shellcheck source=./qa-common.sh
source "${_SCRIPT_DIR}/qa-common.sh"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" || "${HELP:-0}" == "1" ]]; then
  cat <<'EOF'
qa-thrown.sh <mode> <qa_dir>

ThrownTogether preview PNG (fast face-orientation check; not a CGAL render).

Env: IMGSIZE=1600,900  QA_MANIFEST=1  DRY_RUN=1  OPENSCAD=  PLAYGROUND_PROJECT=

Purple/magenta on exterior = inverted normals / non-manifold / bad difference().
Yellow = outside faces = correct.
EOF
  exit 0
fi

MODE=${1:?Usage: qa-thrown.sh <mode> <qa_dir>}
QA_DIR=${2:?Usage: qa-thrown.sh <mode> <qa_dir>}
qa_project_resolve || exit $?
OPENSCAD="${OPENSCAD:-openscad}"
IMGSIZE="${IMGSIZE:-1600,900}"
QA_DIR=$(qa_resolve_qa_dir "$QA_DIR" "$PLAYGROUND_PROJECT_DIR")
mkdir -p "$QA_DIR"
cd "$PLAYGROUND_PROJECT_DIR"
qa_ensure_view_camera || exit 1

OUT="${QA_DIR}/m${MODE}_thrown.png"
CAM="throwntogether,viewall"

qa_manifest_clear
echo "=== Thrown-together: mode $MODE ==="
qa_openscad_png "$OUT" "$MODE" -- "$OPENSCAD" -o "$OUT" --preview=throwntogether -D "mode=$MODE" \
  --autocenter --viewall --view=axes,scales --imgsize="${IMGSIZE}" "$PROJECT_SCAD"
qa_manifest_add "$OUT" "$CAM"
qa_manifest_write "$QA_DIR" "qa-thrown.sh" "$MODE"
echo "Rendered: $OUT"
echo "QA dir: $QA_DIR"
echo "Check: purple/magenta on exterior = inverted normals / non-manifold / bad difference()"
