#!/usr/bin/env bash
# qa-zoom.sh — single orthographic shot into an existing QA folder.
#
# Forms:
#   qa-zoom.sh <mode> <qa_dir> <rx> <ry> <rz> <dist> [label]
#   VIEW=iso_fr_lo qa-zoom.sh <mode> <qa_dir> [label]   # DIST defaults to 300
#   VIEW=iso_fr_lo DIST=120 qa-zoom.sh <mode> <qa_dir> [label]   # explicit crop
#   CAMERA=0,0,0,55,0,25,400 qa-zoom.sh <mode> <qa_dir> [label]
#   RX=55 RY=0 RZ=25 DIST=300 qa-zoom.sh <mode> <qa_dir> [label]
#
# Set THROWN=1 for throwntogether preview.
# QA_MANIFEST=1 appends to qa-manifest.json in qa_dir.
set -euo pipefail

_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=./qa-project.sh
source "${_SCRIPT_DIR}/qa-project.sh"
# shellcheck source=./qa-common.sh
source "${_SCRIPT_DIR}/qa-common.sh"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" || "${HELP:-0}" == "1" ]]; then
  cat <<'EOF'
qa-zoom.sh <mode> <qa_dir> [<rx> <ry> <rz> <dist> [label]]

OR (env camera; tx,ty,tz default 0):
  VIEW=iso_fr_lo LABEL=mylabel qa-zoom.sh <mode> <qa_dir>
  CAMERA=tx,ty,tz,rx,ry,rz,dist LABEL=mylabel qa-zoom.sh <mode> <qa_dir>

Environment:
  VIEW=name         Named preset (top|bottom|front|back|left|right|iso_*)
  CAMERA=...        7-field ortho camera (same token as --camera=); bypasses VIEW=
  DIST=300          Camera distance default when only VIEW= is set
  RX,RY,RZ          Euler angles when not using VIEW=
  TX,TY,TZ          Translation (default 0) with RX,RY,RZ form
  THROWN=1          Use --preview=throwntogether instead of --render
  QA_PREVIEW_DEBUG=0  Disable default *_debug.png throwntogether twin
  QA_VIEWALL=1      Primary PNG uses --viewall (auto-fit; DIST in --camera ignored)
  QA_DIAG_VIEWALL=1 Second PNG (*_viewall.png if QA_VIEWALL=0, else *_fixeddist.png)
  QA_VIEW=          --view= value (default axes,scales,edges); 0|none|off to omit
  QA_COLORSCHEME=   --colorscheme= value (Cornfield|Metallic|"Tomorrow Night"|...)
  IMGSIZE=1600,900
  QA_MANIFEST=1     Append qa-manifest.json
  DRY_RUN=1
  PARTS=a,b         Show only these parts (indices or slugs from repl-config.json)
  HIDE=a,b          Hide these parts. Cannot combine with PARTS.
  OPENSCAD=         Path to openscad binary
  PLAYGROUND_PROJECT= Active project slug

Output: build/qa/<qa_dir>/m<mode>_<label>.png under the project dir.
EOF
  exit 0
fi

MODE=${1:?Usage: qa-zoom.sh <mode> <qa_dir> ...}
QA_DIR=${2:?Usage: qa-zoom.sh <mode> <qa_dir> ...}
shift 2

qa_project_resolve || exit $?
OPENSCAD="${OPENSCAD:-openscad}"
IMGSIZE="${IMGSIZE:-1600,900}"
QA_DIR=$(qa_resolve_qa_dir "$QA_DIR" "$PLAYGROUND_PROJECT_DIR")
mkdir -p "$QA_DIR"
cd "$PLAYGROUND_PROJECT_DIR"
qa_ensure_view_camera || exit 1
qa_part_visibility_args

if [[ $# -ge 4 ]]; then
  RX=${1:?}; RY=${2:?}; RZ=${3:?}; DIST=${4:?}
  shift 4
  LABEL=${1:-zoom_$(date +%H%M%S)}
  TX=0; TY=0; TZ=0
elif [[ -n "${CAMERA:-}" ]]; then
  _cam="${CAMERA// /}"
  IFS=',' read -r TX TY TZ RX RY RZ DIST <<< "$_cam"
  if [[ -z "${DIST:-}" ]]; then
    echo "ERROR: CAMERA= must be exactly 7 comma-separated numbers: tx,ty,tz,rx,ry,rz,dist" >&2
    exit 1
  fi
  LABEL=${LABEL:-zoom_camera}
elif [[ -n "${VIEW:-}" ]]; then
  qa_cam_resolve_view "$VIEW" || exit 1
  if [[ -z "${TX:-}" && -z "${TY:-}" && -z "${TZ:-}" && "${QA_BBOX_CENTER:-1}" != "0" ]]; then
    if _bbox=$(qa_bbox_center "$MODE" "$OPENSCAD"); then
      read -r TX TY TZ <<< "$_bbox"
      echo "  (auto-centered on bbox: $TX, $TY, $TZ)" >&2
    fi
  fi
  TX="${TX:-${QA_CAM_TX}}"; TY="${TY:-${QA_CAM_TY}}"; TZ="${TZ:-${QA_CAM_TZ}}"
  RX="${QA_CAM_RX}"; RY="${QA_CAM_RY}"; RZ="${QA_CAM_RZ}"
  if [[ -z "${DIST:-}" ]]; then
    DIST=300
    echo "  (VIEW= without DIST: default DIST=300)" >&2
  fi
  LABEL=${LABEL:-zoom_${VIEW}}
elif [[ -n "${RX:-}" && -n "${RY:-}" && -n "${RZ:-}" && -n "${DIST:-}" ]]; then
  TX="${TX:-0}"; TY="${TY:-0}"; TZ="${TZ:-0}"
  LABEL=${LABEL:-zoom_env}
else
  echo "ERROR: provide 4+ args (rx ry rz dist [label]) or CAMERA= or VIEW= or RX RY RZ DIST env" >&2
  exit 1
fi

PNG_MODE_ARGS=("${OPENSCAD_RENDER_FLAG:---render}")
[[ "${THROWN:-0}" == "1" ]] && PNG_MODE_ARGS=(--preview=throwntogether)

OUT="${QA_DIR}/m${MODE}_${LABEL}.png"
CAM="${TX},${TY},${TZ},${RX},${RY},${RZ},${DIST}"

_EXTRA_ARGS=()
_qv="${QA_VIEW-axes,scales,edges}"
case "$_qv" in
  0|false|none|off) ;;
  *) _EXTRA_ARGS+=(--view="$_qv") ;;
esac
if [[ -n "${QA_COLORSCHEME:-}" ]]; then
  _EXTRA_ARGS+=(--colorscheme="$QA_COLORSCHEME")
fi

_qa_zoom_render() {
  local out="$1"; shift
  if [[ ${#_EXTRA_ARGS[@]} -gt 0 ]]; then
    qa_openscad_png "$out" "$MODE" -- "$OPENSCAD" -o "$out" \
      --projection=ortho --autocenter "$@" \
      "${_EXTRA_ARGS[@]}" \
      --camera="${CAM}" --imgsize="${IMGSIZE}" \
      "${PNG_MODE_ARGS[@]}" \
      -D "mode=${MODE}" "${QA_VIZ_ARGS[@]+"${QA_VIZ_ARGS[@]}"}" "$PROJECT_SCAD"
  else
    qa_openscad_png "$out" "$MODE" -- "$OPENSCAD" -o "$out" \
      --projection=ortho --autocenter "$@" \
      --camera="${CAM}" --imgsize="${IMGSIZE}" \
      "${PNG_MODE_ARGS[@]}" \
      -D "mode=${MODE}" "${QA_VIZ_ARGS[@]+"${QA_VIZ_ARGS[@]}"}" "$PROJECT_SCAD"
  fi
}

_qa_zoom_render_debug() {
  local out="$1"; shift
  local preview=(--preview=throwntogether)
  if [[ ${#_EXTRA_ARGS[@]} -gt 0 ]]; then
    qa_openscad_png "$out" "$MODE" -- "$OPENSCAD" -o "$out" \
      --projection=ortho --autocenter "$@" \
      "${_EXTRA_ARGS[@]}" \
      --camera="${CAM}" --imgsize="${IMGSIZE}" \
      "${preview[@]}" \
      -D "mode=${MODE}" "${QA_VIZ_ARGS[@]+"${QA_VIZ_ARGS[@]}"}" "$PROJECT_SCAD"
  else
    qa_openscad_png "$out" "$MODE" -- "$OPENSCAD" -o "$out" \
      --projection=ortho --autocenter "$@" \
      --camera="${CAM}" --imgsize="${IMGSIZE}" \
      "${preview[@]}" \
      -D "mode=${MODE}" "${QA_VIZ_ARGS[@]+"${QA_VIZ_ARGS[@]}"}" "$PROJECT_SCAD"
  fi
}

qa_manifest_clear
if [[ "${QA_VIEWALL:-0}" == "1" ]] && [[ "${THROWN:-0}" != "1" ]]; then
  _qa_zoom_render "$OUT" --viewall
  qa_manifest_add "$OUT" "${CAM};viewall_primary"
else
  _qa_zoom_render "$OUT"
  qa_manifest_add "$OUT" "$CAM"
fi
if qa_preview_debug_enabled "$MODE" && [[ "${THROWN:-0}" != "1" ]]; then
  OUTDBG="${QA_DIR}/m${MODE}_${LABEL}_debug.png"
  if [[ "${QA_VIEWALL:-0}" == "1" ]]; then
    _qa_zoom_render_debug "$OUTDBG" --viewall
    qa_manifest_add "$OUTDBG" "${CAM};viewall_primary;throwntogether_debug"
  else
    _qa_zoom_render_debug "$OUTDBG"
    qa_manifest_add "$OUTDBG" "${CAM};throwntogether_debug"
  fi
  echo "Preview debug: $OUTDBG"
fi
if [[ "${QA_DIAG_VIEWALL:-0}" == "1" ]] && [[ "${THROWN:-0}" != "1" ]]; then
  if [[ "${QA_VIEWALL:-0}" == "1" ]]; then
    OUTV="${QA_DIR}/m${MODE}_${LABEL}_fixeddist.png"
    _qa_zoom_render "$OUTV"
    qa_manifest_add "$OUTV" "${CAM};fixeddist"
    echo "Zoom diag (fixed DIST): $OUTV"
  else
    OUTV="${QA_DIR}/m${MODE}_${LABEL}_viewall.png"
    _qa_zoom_render "$OUTV" --viewall
    qa_manifest_add "$OUTV" "${CAM};viewall"
    echo "Zoom diag: $OUTV"
  fi
fi
qa_manifest_write "$QA_DIR" "qa-zoom.sh" "$MODE"
echo "Zoom: $OUT"
echo "QA dir: $QA_DIR"
