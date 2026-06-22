#!/usr/bin/env bash
# qa-orbit.sh — sweep camera rotation or translation over N frames.
# Default = turntable: rz 0→330, 12 frames, iso_fr_lo.
set -euo pipefail

_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=./qa-project.sh
source "${_SCRIPT_DIR}/qa-project.sh"
# shellcheck source=./qa-common.sh
source "${_SCRIPT_DIR}/qa-common.sh"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" || "${HELP:-0}" == "1" ]]; then
  cat <<'EOF'
qa-orbit.sh <mode> [qa_dir]

Rotation sweep (default):
  RAXIS=rx|ry|rz   Default rz
  R_FROM=0  R_TO=330  STEPS=12

Translation sweep (set AXIS to activate):
  AXIS=x|y|z RANGE=200 STEPS=5 VIEW=front DIST=300 qa-orbit.sh 5

Base orientation: VIEW=preset OR explicit RX, RY, RZ (and TX, TY, TZ).
DIST is auto-read from qa-part-views.json catalog when unset; falls back to 300.

Env: DIST=  THROWN=1  IMGSIZE=1600,900  LABEL=  QA_MANIFEST=1  DRY_RUN=1
     PARTS=  HIDE=  OPENSCAD=  PLAYGROUND_PROJECT=
EOF
  exit 0
fi

MODE=${1:?Usage: qa-orbit.sh <mode> [qa_dir]}
QA_DIR_ARG="${2:-}"
qa_project_resolve || exit $?
_DATA_JSON="${QA_PART_VIEWS_JSON:-${PROJECT_DATA_DIR}/qa-part-views.json}"
OPENSCAD="${OPENSCAD:-openscad}"
IMGSIZE="${IMGSIZE:-1600,900}"

AXIS="${AXIS:-}"
RAXIS="${RAXIS:-${ORBIT_AXIS:-}}"
if [[ -n "$AXIS" ]]; then
  SWEEP="translate"
  AXIS=$(printf '%s' "$AXIS" | tr '[:upper:]' '[:lower:]')
  case "$AXIS" in x|y|z) ;; *) echo "ERROR: AXIS must be x|y|z" >&2; exit 1 ;; esac
  RANGE="${RANGE:?Set RANGE= total sweep mm}"
  STEPS="${STEPS:?Set STEPS= (>=2)}"
  LABEL="${LABEL:-pan_${AXIS}}"
else
  SWEEP="rotate"
  RAXIS="${RAXIS:-rz}"
  RAXIS=$(printf '%s' "$RAXIS" | tr '[:upper:]' '[:lower:]')
  case "$RAXIS" in rx|ry|rz) ;; *) echo "ERROR: RAXIS must be rx|ry|rz" >&2; exit 1 ;; esac
  R_FROM="${R_FROM:-0}"
  R_TO="${R_TO:-330}"
  STEPS="${STEPS:-12}"
  VIEW="${VIEW:-iso_fr_lo}"
  LABEL="${LABEL:-orbit_${RAXIS}}"
fi
if [ "$STEPS" -lt 2 ]; then echo "ERROR: STEPS must be >= 2" >&2; exit 1; fi

if [[ -z "${DIST:-}" ]] && command -v python3 &>/dev/null && [[ -f "$_DATA_JSON" ]]; then
  _dist=$(python3 - "$_DATA_JSON" "$MODE" <<'PY'
import json, sys
path, mode = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as f: data = json.load(f)
defaults = data.get("defaults") or {}
entry = (data.get("modes") or {}).get(str(mode)) or {}
shots = entry.get("shots")
if isinstance(shots, dict) and len(shots) > 0:
    keys = sorted(shots.keys())
    sk = "default" if "default" in keys else keys[0]
    sub = shots[sk]
    if sub.get("camera"):
        parts = [p.strip() for p in str(sub["camera"]).split(",")]
        d = int(round(float(parts[6])))
    else:
        d = int(sub.get("dist", defaults.get("dist", 300)))
else:
    d = int(defaults.get("dist", 300))
print(d)
PY
  ) || true
  [[ -n "$_dist" ]] && DIST="$_dist"
fi
DIST="${DIST:-300}"

if [[ -n "$QA_DIR_ARG" ]]; then QA_DIR="$QA_DIR_ARG"
else QA_DIR="${PROJECT_BUILD_DIR}/qa/$(date +%Y-%m-%d_%H%M)_${LABEL}_m${MODE}"; fi
QA_DIR=$(qa_resolve_qa_dir "$QA_DIR" "$PLAYGROUND_PROJECT_DIR")
mkdir -p "$QA_DIR"
cd "$PLAYGROUND_PROJECT_DIR"
qa_ensure_view_camera || exit 1
qa_part_visibility_args

if [[ -n "${VIEW:-}" ]]; then
  qa_cam_resolve_view "$VIEW" || exit 1
  if [[ -z "${TX:-}" && -z "${TY:-}" && -z "${TZ:-}" && "${QA_BBOX_CENTER:-1}" != "0" ]]; then
    if _bbox=$(qa_bbox_center "$MODE" "$OPENSCAD"); then
      read -r TX TY TZ <<< "$_bbox"
      echo "  (auto-centered on bbox: $TX, $TY, $TZ)" >&2
    fi
  fi
  TX="${TX:-${QA_CAM_TX}}"; TY="${TY:-${QA_CAM_TY}}"; TZ="${TZ:-${QA_CAM_TZ}}"
  RX="${QA_CAM_RX}"; RY="${QA_CAM_RY}"; RZ="${QA_CAM_RZ}"
elif [[ -n "${RX:-}" && -n "${RY:-}" && -n "${RZ:-}" ]]; then
  TX="${TX:-0}"; TY="${TY:-0}"; TZ="${TZ:-0}"
else
  echo "ERROR: set VIEW= or RX,RY,RZ" >&2; exit 1
fi

PNG_MODE_ARGS=("${OPENSCAD_RENDER_FLAG:---render}")
[[ "${THROWN:-0}" == "1" ]] && PNG_MODE_ARGS=(--preview=throwntogether)

qa_manifest_clear

if [[ "$SWEEP" == "translate" ]]; then
  echo "=== Pan sweep: mode $MODE, axis=$AXIS, range=$RANGE, steps=$STEPS ==="
  HALF=$(awk -v r="$RANGE" 'BEGIN { printf "%.4f", r / 2 }')
  STEP_SIZE=$(awk -v r="$RANGE" -v n="$STEPS" 'BEGIN { printf "%.4f", r / (n - 1) }')
  for i in $(seq 0 $((STEPS - 1))); do
    OFFSET=$(awk -v half="$HALF" -v step="$STEP_SIZE" -v i="$i" 'BEGIN { printf "%.2f", -half + step * i }')
    FTX="$TX"; FTY="$TY"; FTZ="$TZ"
    case "$AXIS" in
      x) FTX=$(awk -v b="$TX" -v o="$OFFSET" 'BEGIN { printf "%.2f", b + o }') ;;
      y) FTY=$(awk -v b="$TY" -v o="$OFFSET" 'BEGIN { printf "%.2f", b + o }') ;;
      z) FTZ=$(awk -v b="$TZ" -v o="$OFFSET" 'BEGIN { printf "%.2f", b + o }') ;;
    esac
    FRAME=$(printf "%03d" "$i")
    OUT="${QA_DIR}/m${MODE}_${LABEL}_${FRAME}.png"
    CAM="${FTX},${FTY},${FTZ},${RX},${RY},${RZ},${DIST}"
    qa_openscad_png "$OUT" "$MODE" -- "$OPENSCAD" -o "$OUT" \
      --projection=ortho --autocenter \
      --view=axes,scales --camera="${CAM}" --imgsize="${IMGSIZE}" \
      "${PNG_MODE_ARGS[@]}" \
      -D "mode=${MODE}" "${QA_VIZ_ARGS[@]+"${QA_VIZ_ARGS[@]}"}" "$PROJECT_SCAD"
    qa_manifest_add "$OUT" "$CAM"
    echo "  frame $FRAME  ${AXIS}=${OFFSET}"
  done
else
  echo "=== Orbit sweep: mode $MODE RAXIS=$RAXIS $R_FROM -> $R_TO ($STEPS frames) ==="
  STEP_D=$(awk -v a="$R_FROM" -v b="$R_TO" -v n="$STEPS" 'BEGIN { printf "%.6f", (b - a) / (n - 1) }')
  for i in $(seq 0 $((STEPS - 1))); do
    ANG=$(awk -v a="$R_FROM" -v s="$STEP_D" -v i="$i" 'BEGIN { printf "%.4f", a + s * i }')
    FRX="$RX"; FRY="$RY"; FRZ="$RZ"
    case "$RAXIS" in
      rx) FRX="$ANG" ;; ry) FRY="$ANG" ;; rz) FRZ="$ANG" ;;
    esac
    FRAME=$(printf "%03d" "$i")
    OUT="${QA_DIR}/m${MODE}_${LABEL}_${FRAME}.png"
    CAM="${TX},${TY},${TZ},${FRX},${FRY},${FRZ},${DIST}"
    qa_openscad_png "$OUT" "$MODE" -- "$OPENSCAD" -o "$OUT" \
      --projection=ortho --autocenter \
      --view=axes,scales --camera="${CAM}" --imgsize="${IMGSIZE}" \
      "${PNG_MODE_ARGS[@]}" \
      -D "mode=${MODE}" "${QA_VIZ_ARGS[@]+"${QA_VIZ_ARGS[@]}"}" "$PROJECT_SCAD"
    qa_manifest_add "$OUT" "$CAM"
    echo "  frame $FRAME  ${RAXIS}=${ANG}"
  done
fi

qa_manifest_write "$QA_DIR" "qa-orbit.sh" "$MODE"
echo "Sweep done: $STEPS frames"
echo "QA dir: $QA_DIR"
