#!/usr/bin/env bash
# Export all printable STL parts for the active openscad-playground project.
#
# Modes/names come from the project's repl-config.json (entries where
# type == "print" — stl_name is the output basename).
#
# Forms:
#   ./scripts/export_parts.sh              # all "print" modes
#   ./scripts/export_parts.sh tests        # all "test" modes
#   ./scripts/export_parts.sh all          # both
#   ./scripts/export_parts.sh 5 6 8        # specific mode numbers
#
# Env: OPENSCAD=  PLAYGROUND_PROJECT=
set -euo pipefail

_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
_QA_SCRIPTS="${_SCRIPT_DIR}/../.agents/skills/verify-design/scripts"
# shellcheck source=../.agents/skills/verify-design/scripts/qa-project.sh
source "${_QA_SCRIPTS}/qa-project.sh"
# shellcheck source=../.agents/skills/verify-design/scripts/qa-common.sh
source "${_QA_SCRIPTS}/qa-common.sh"

qa_project_resolve || exit $?
OPENSCAD="${OPENSCAD:-openscad}"
BUILD="${PLAYGROUND_ROOT}/build"
REPL_CFG="${PLAYGROUND_PROJECT_DIR}/repl-config.json"

if ! "$OPENSCAD" --version >/dev/null 2>&1; then
  echo "ERROR: OpenSCAD not runnable: $OPENSCAD (set OPENSCAD=openscad or path to binary)" >&2
  exit 1
fi

if [[ ! -f "$REPL_CFG" ]]; then
  echo "ERROR: $REPL_CFG missing. Cannot determine print modes for project '$PLAYGROUND_PROJECT'." >&2
  exit 2
fi

mkdir -p "$BUILD"
cd "$PLAYGROUND_PROJECT_DIR"
qa_ensure_view_camera || exit 1

_filter="${1:-print}"
shift || true

if [[ "$_filter" == "print" ]]; then
  MODES=$(python3 -c "
import json, sys
d = json.load(open(sys.argv[1], encoding='utf-8'))
for m in d.get('modes') or []:
    if m.get('type') == 'print':
        print(f\"{m['id']}\t{m.get('stl_name', 'PRINT_' + str(m['id']))}\")
" "$REPL_CFG")
elif [[ "$_filter" == "tests" ]]; then
  MODES=$(python3 -c "
import json, sys
d = json.load(open(sys.argv[1], encoding='utf-8'))
for m in d.get('modes') or []:
    if m.get('type') == 'test':
        print(f\"{m['id']}\t{m.get('stl_name', 'TEST_' + str(m['id']))}\")
" "$REPL_CFG")
elif [[ "$_filter" == "all" ]]; then
  MODES=$(python3 -c "
import json, sys
d = json.load(open(sys.argv[1], encoding='utf-8'))
for m in d.get('modes') or []:
    if m.get('type') in ('print', 'test'):
        print(f\"{m['id']}\t{m.get('stl_name', 'PART_' + str(m['id']))}\")
" "$REPL_CFG")
else
  # treat $_filter and rest as explicit mode ids; look up names from repl-config
  IDS="$_filter $*"
  MODES=$(python3 -c "
import json, sys
d = json.load(open(sys.argv[1], encoding='utf-8'))
ids = set(sys.argv[2].split())
by_id = {str(m['id']): m for m in d.get('modes') or []}
for mid in ids:
    m = by_id.get(mid)
    if m is None:
        print(f'{mid}\\tMODE_{mid}')
    else:
        print(f\"{m['id']}\\t{m.get('stl_name', 'PART_' + str(m['id']))}\")
" "$REPL_CFG" "$IDS")
fi

if [[ -z "${MODES// }" ]]; then
  echo "Nothing to export (no matching modes)."
  exit 0
fi

PASS=0; FAIL=0
while IFS=$'\t' read -r mode name; do
  [[ -z "$mode" ]] && continue
  out="$BUILD/${PLAYGROUND_PROJECT}--${name}.stl"
  echo -n "Exporting mode $mode → $out ... "
  if "$OPENSCAD" -o "$out" --render --export-format binstl -D "mode=$mode" "$PROJECT_SCAD" 2>/dev/null; then
    echo "OK"; PASS=$((PASS+1))
  else
    echo "FAILED"; FAIL=$((FAIL+1))
  fi
done <<< "$MODES"

echo ""
echo "$PASS exported, $FAIL failed"
ls -lh "$BUILD"/*.stl 2>/dev/null
