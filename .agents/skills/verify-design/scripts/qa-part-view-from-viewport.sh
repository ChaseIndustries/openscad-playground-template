#!/usr/bin/env bash
# qa-part-view-from-viewport.sh — write a camera string into the project's
# qa-part-views.json for a given mode and shot name.
#
# Usage:
#   qa-part-view-from-viewport.sh <mode> --camera tx,ty,tz,rx,ry,rz,dist [--shot NAME]
#
# Options:
#   --camera STR   Seven comma-separated numbers (no spaces)
#   --shot NAME    Store under mode's shots[NAME] (default: "default")
#   --json PATH    Override catalog path (default: project data dir)
#
# The catalog path resolves from the active project via qa-project.sh
# (PLAYGROUND_PROJECT or .playground-active or cwd resolution).
# Override with QA_PART_VIEWS_JSON= or --json.
#
# Called automatically by qa-zoom.sh when QA_CACHE_SHOT= is set.
set -euo pipefail

_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=./qa-project.sh
source "${_SCRIPT_DIR}/qa-project.sh"

MODE="${1:?Usage: qa-part-view-from-viewport.sh <mode> --camera tx,ty,tz,rx,ry,rz,dist [--shot NAME]}"
shift

CAMERA=""
_SHOT="default"
_DATA_JSON_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --camera) CAMERA="${2:?--camera requires a value}"; shift 2 ;;
    --shot)   _SHOT="${2:?--shot requires a value}"; shift 2 ;;
    --json)   _DATA_JSON_ARG="${2:?--json requires a value}"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$CAMERA" ]]; then
  echo "ERROR: provide --camera tx,ty,tz,rx,ry,rz,dist" >&2
  exit 1
fi

# Resolve project to get data dir (unless --json was passed)
if [[ -z "$_DATA_JSON_ARG" ]]; then
  qa_project_resolve || exit $?
  _DATA_JSON="${QA_PART_VIEWS_JSON:-${PROJECT_DATA_DIR}/qa-part-views.json}"
else
  _DATA_JSON="$_DATA_JSON_ARG"
fi

# Create skeleton catalog if missing
if [[ ! -f "$_DATA_JSON" ]]; then
  mkdir -p "$(dirname "$_DATA_JSON")"
  printf '{\n  "schema_version": 1,\n  "defaults": {"view": "iso_fr", "dist": 200},\n  "modes": {}\n}\n' > "$_DATA_JSON"
fi

python3 - "$_DATA_JSON" "$MODE" "$CAMERA" "$_SHOT" <<'PY'
import json, sys

json_path, mode, camera, shot = sys.argv[1], str(sys.argv[2]), sys.argv[3], sys.argv[4]

# Validate camera format
fields = [f.strip() for f in camera.split(",")]
if len(fields) != 7:
    print(f"ERROR: --camera needs 7 comma-separated numbers, got {len(fields)}: {camera}", file=sys.stderr)
    sys.exit(1)
try:
    [float(f) for f in fields]
except ValueError as e:
    print(f"ERROR: non-numeric camera field: {e}", file=sys.stderr)
    sys.exit(1)

with open(json_path, encoding="utf-8") as f:
    data = json.load(f)

if "modes" not in data:
    data["modes"] = {}
modes = data["modes"]
if mode not in modes:
    modes[mode] = {}
entry = modes[mode]
if "shots" not in entry:
    entry["shots"] = {}
entry["shots"][shot] = {"camera": camera}

with open(json_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print(f"Updated mode {mode} shot '{shot}': camera={camera}")
PY
