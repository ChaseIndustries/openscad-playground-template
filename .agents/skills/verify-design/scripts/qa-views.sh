#!/usr/bin/env bash
# qa-views.sh <mode> <part-name> [view ...]
# Render ortho QA shots from the project's qa-part-views.json catalog (or
# from named preset cameras when explicit view args are given).
set -euo pipefail

_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=./qa-project.sh
source "${_SCRIPT_DIR}/qa-project.sh"
# shellcheck source=./qa-common.sh
source "${_SCRIPT_DIR}/qa-common.sh"

qa_project_resolve || exit $?
_DATA_JSON="${QA_PART_VIEWS_JSON:-${PROJECT_DATA_DIR}/qa-part-views.json}"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" || "${HELP:-0}" == "1" ]]; then
  cat <<EOF
qa-views.sh <mode> <part-name> [view ...]

Renders --render --projection=ortho PNGs from the project's catalog
($_DATA_JSON) into build/qa/YYYY-MM-DD_HHMM_<part-name>/.

Modes:
  qa-views.sh <mode> <part-name>                     All catalog shots for the mode
  qa-views.sh --shot NAME <mode> <part-name>         Single named catalog shot
  qa-views.sh <mode> <part-name> iso_fr top          Preset views from positional args
  ONLY="iso_fr,top" qa-views.sh <mode> <part-name>   Same via env var
  qa-views.sh --list                                  TSV of all modes/shots
  qa-views.sh --batch [--all-shots] [qa_dir]         Default shot per mode (or every shot)

Env:
  QA_DIR=path                Output folder (created). Default: build/qa/<dated>/
  DIST=300                   Camera distance default
  IMGSIZE=1600,900           PNG size
  ONLY=a,b                   Comma-separated view/shot names
  QA_MANIFEST=1              Write qa-manifest.json
  DRY_RUN=1                  Print openscad invocations without running
  OPENSCAD_RENDER_FLAG=      Default --render; use --render=true if PNGs are empty
  QA_DIAG_VIEWALL=1          Extra *_viewall.png per view
  QA_PREVIEW_DEBUG=          *_debug.png throwntogether twin (default: assembly_* modes only)
  PARTS=a,b                  Show only these parts (indices or slugs from repl-config.json)
  HIDE=a,b                   Hide these parts (cannot combine with PARTS)
  OPENSCAD=                  openscad binary
  PLAYGROUND_PROJECT=        active project slug

Named views:
EOF
  qa_cam_list_names
  exit 0
fi

if [[ "${1:-}" == "--list" ]]; then
  if [[ ! -f "$_DATA_JSON" ]]; then
    echo "ERROR: missing $_DATA_JSON" >&2; exit 2
  fi
  python3 - "$_DATA_JSON" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
defaults = data.get("defaults") or {}
def dist_for_list(sub, fallback):
    cam = sub.get("camera")
    if cam:
        parts = [p.strip() for p in str(cam).split(",") if p.strip()]
        if len(parts) == 7:
            return int(round(float(parts[6])))
    return int(sub.get("dist", fallback))

for m in sorted(data.get("modes", {}).keys(), key=lambda x: int(x)):
    e = data["modes"][m]
    slug = e.get("part_slug", "")
    shots = e.get("shots")
    if not isinstance(shots, dict) or len(shots) == 0: continue
    for sk in sorted(shots.keys()):
        sub = shots[sk]
        d = dist_for_list(sub, int(e.get("dist", defaults.get("dist", 300))))
        fd = "yes" if sub.get("fixed_dist") else ""
        if sub.get("camera"):
            print(f"{m}\t{sk}\t(camera)\t{d}\t{slug}\t{fd}")
        else:
            v = sub.get("view", defaults.get("view", "iso_fr"))
            print(f"{m}\t{sk}\t{v}\t{d}\t{slug}\t{fd}")
PY
  exit 0
fi

BATCH_ALL_SHOTS="${QA_BATCH_ALL_SHOTS:-0}"
if [[ "${1:-}" == "--batch" ]]; then
  shift
  if [[ "${1:-}" == "--all-shots" ]]; then BATCH_ALL_SHOTS=1; shift; fi
  if [[ -n "${1:-}" ]]; then QA_BASE="$1"
  else QA_BASE="${PROJECT_BUILD_DIR}/qa/$(date +%Y-%m-%d_%H%M)_recommended_all"; fi
  mkdir -p "$QA_BASE"
  if [[ "$BATCH_ALL_SHOTS" == "1" ]]; then
    while IFS=$'\t' read -r _m _sk; do
      [[ -z "${_m:-}" ]] && continue
      if [[ -n "${_sk}" ]]; then
        QA_DIR="$QA_BASE" "$_SCRIPT_DIR/qa-views.sh" --shot "$_sk" "$_m" "batch_${_m}_${_sk}"
      else
        QA_DIR="$QA_BASE" "$_SCRIPT_DIR/qa-views.sh" --shot default "$_m" "batch_${_m}"
      fi
    done < <(_QA_JSON="$_DATA_JSON" python3 <<'PY'
import json, os
with open(os.environ["_QA_JSON"], encoding="utf-8") as f: data = json.load(f)
for m in sorted(data.get("modes", {}).keys(), key=int):
    e = data["modes"][m]
    shots = e.get("shots")
    if isinstance(shots, dict) and len(shots) > 0:
        for sk in sorted(shots.keys()): print(f"{m}\t{sk}")
    else: print(f"{m}\t")
PY
)
  else
    modes=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1],encoding='utf-8')); print(' '.join(sorted(d.get('modes',{}).keys(), key=int)))" "$_DATA_JSON")
    for m in $modes; do
      QA_DIR="$QA_BASE" "$_SCRIPT_DIR/qa-views.sh" --shot default "$m" "batch_${m}"
    done
  fi
  echo "Batch QA dir: $QA_BASE"
  exit 0
fi

_SHOT="${QA_SHOT:-}"
_USE_VIEWALL_FLAG=""
while true; do
  case "${1:-}" in
    --shot) _SHOT="${2:?--shot requires a name}"; shift 2 ;;
    --viewall) _USE_VIEWALL_FLAG=1; shift ;;
    *) break ;;
  esac
done

MODE=${1:?Usage: qa-views.sh <mode> <part-name> [view ...] | --list | --batch | --shot NAME <mode> <part-name>}
PART=${2:?Usage: qa-views.sh <mode> <part-name> [view ...]}
shift 2
export OPENSCAD="${OPENSCAD:-openscad}"
export QA_SCRIPT_DIR="$_SCRIPT_DIR"
DIST="${DIST:-300}"
IMGSIZE="${IMGSIZE:-1600,900}"
if [[ $# -gt 0 ]]; then ONLY=$(IFS=','; echo "$*"); else ONLY="${ONLY:-}"; fi

if [[ ! -f "$_DATA_JSON" ]]; then
  echo "ERROR: missing $_DATA_JSON" >&2; exit 2
fi

# --shot path delegates to qa-zoom.sh with resolved camera
if [[ -n "$_SHOT" ]]; then
  _qa_out=$(python3 - "$_DATA_JSON" "$MODE" "$_SHOT" <<'PY'
import json, os, sys
sys.path.insert(0, os.environ.get("QA_SCRIPT_DIR", ""))
try:
    from qa_fit_helper import resolve_fit
except ImportError:
    resolve_fit = None

def norm_camera(s):
    parts = [p.strip() for p in s.strip().split(",")]
    if len(parts) != 7:
        raise SystemExit(f"catalog camera must have 7 comma-separated numbers, got {len(parts)}")
    out = []
    for i, p in enumerate(parts):
        x = float(p)
        if i < 6: out.append(str(int(x)) if x == int(x) else str(x))
        else: out.append(str(int(round(x))))
    return ",".join(out)

path, mode, shot_arg = sys.argv[1], sys.argv[2], (sys.argv[3] if len(sys.argv) > 3 else "").strip()
with open(path, encoding="utf-8") as f: data = json.load(f)
defaults = data.get("defaults") or {}
modes = data.get("modes") or {}
entry = modes.get(str(mode))
if not entry:
    v = defaults.get("view", "iso_fr"); d = int(defaults.get("dist", 300))
    print(f"{v}\t{d}\tmode_{mode}\t0\t1\t"); sys.exit(0)
base_slug = entry.get("part_slug") or f"mode_{mode}"
shots = entry.get("shots")
if not isinstance(shots, dict) or len(shots) == 0:
    raise SystemExit(f"ERROR: mode {mode} has no shots catalog")
keys = sorted(shots.keys())
if shot_arg:
    if shot_arg not in shots:
        raise SystemExit(f"ERROR: mode {mode}: unknown shot {shot_arg!r}; valid: {keys}")
    sk = shot_arg
elif "default" in shots: sk = "default"
elif len(keys) == 1: sk = keys[0]
else: raise SystemExit(f"ERROR: mode {mode} has multiple shots {keys}; use --shot NAME")
sub = shots[sk]
twin = "1" if (sub.get("fixeddist_twin") or sub.get("viewall") or entry.get("fixeddist_twin") or entry.get("viewall")) else "0"
label_stem = base_slug if sk == "default" else f"{base_slug}_{sk}"
parts_csv = ",".join(str(p) for p in sub.get("parts", []))
fixed_va = "0" if (sub.get("fixed_dist") or "fit" in sub) else "1"
if sub.get("camera"):
    print(f"RAW\t{norm_camera(str(sub['camera']))}\t{label_stem}\t{twin}\t{fixed_va}\t{parts_csv}"); sys.exit(0)
v = sub.get("view") or defaults.get("view", "iso_fr")
if "fit" in sub:
    if resolve_fit is None:
        raise SystemExit("ERROR: fit shot requires qa_fit_helper.py")
    dist_f = resolve_fit(int(mode), v, sub["fit"])
    if dist_f is None:
        raise SystemExit(f"ERROR: could not resolve fit for mode {mode} shot {sk!r}: {sub['fit']!r}")
    d = int(round(dist_f))
else:
    d = int(sub.get("dist", defaults.get("dist", 300)))
print(f"{v}\t{d}\t{label_stem}\t{twin}\t{fixed_va}\t{parts_csv}")
PY
) || exit $?
  IFS=$'\t' read -r C1 C2 C3 C4 C5 C6 <<< "$_qa_out"
  if [[ -n "${QA_DIR:-}" ]]; then
    QA_DIR=$(qa_resolve_qa_dir "$QA_DIR" "$PLAYGROUND_PROJECT_DIR")
  else
    QA_DIR="${PROJECT_BUILD_DIR}/qa/$(date +%Y-%m-%d_%H%M)_recommended_${C3}"
  fi
  SLUG="$C3"
  USE_VA="$C4"
  if [[ "$C1" == "RAW" ]]; then
    export CAMERA="$C2"; unset VIEW; unset DIST
  else
    export VIEW="$C1"; export DIST="$C2"; unset CAMERA
  fi
  export LABEL="recommended_${SLUG}"
  if [[ -z "${QA_VIEWALL+x}" ]]; then
    if [[ "${C5:-1}" == "0" ]]; then export QA_VIEWALL=0
    else export QA_VIEWALL=1; fi
  fi
  if [[ "${_USE_VIEWALL_FLAG:-}" == "1" ]]; then export QA_VIEWALL=1; fi
  if [[ -z "${QA_VIEW+x}" ]]; then export QA_VIEW=0; fi
  if [[ "$USE_VA" == "1" ]] && [[ -z "${QA_DIAG_VIEWALL+x}" ]]; then export QA_DIAG_VIEWALL=1; fi
  if [[ -z "${PARTS:-}" && -z "${HIDE:-}" && -n "${C6:-}" ]]; then export PARTS="$C6"; fi
  exec "$_SCRIPT_DIR/qa-zoom.sh" "$MODE" "$QA_DIR"
fi

# Catalog plan or preset render
if [[ -n "${QA_DIR:-}" ]]; then
  QA_DIR=$(qa_resolve_qa_dir "$QA_DIR" "$PLAYGROUND_PROJECT_DIR")
else
  QA_DIR="${PROJECT_BUILD_DIR}/qa/$(date +%Y-%m-%d_%H%M)_${PART}"
fi
mkdir -p "$QA_DIR"
cd "$PLAYGROUND_PROJECT_DIR"
qa_ensure_view_camera || exit 1
qa_part_visibility_args

ALL_VIEWS=("${QA_CAMERA_VIEWS[@]}")
qa_manifest_clear

_render_one_ortho() {
  local out="$1" camfull="$2" tag="$3"
  local extra_flags=()
  if [[ "${_USE_VIEWALL_FLAG:-}" == "1" ]]; then extra_flags+=(--viewall); fi
  qa_openscad_png "$out" "$MODE" -- "$OPENSCAD" -o "$out" \
    "${OPENSCAD_RENDER_FLAG:---render}" \
    --projection=ortho --autocenter \
    "${extra_flags[@]+"${extra_flags[@]}"}" \
    --view=axes,scales --camera="${camfull}" --imgsize="${IMGSIZE}" \
    -D "mode=${MODE}" "${QA_VIZ_ARGS[@]+"${QA_VIZ_ARGS[@]}"}" "$PROJECT_SCAD"
  qa_manifest_add "$out" "$camfull"
  echo "  $out"
  if qa_preview_debug_enabled "$MODE" && [[ "${THROWN:-0}" != "1" ]]; then
    qa_maybe_emit_throwntogether_debug_ortho "$out" "$MODE" "$OPENSCAD" "$camfull" "$IMGSIZE" "${extra_flags[@]+"${extra_flags[@]}"}"
    qa_manifest_add "${out%.png}_debug.png" "${camfull};throwntogether_debug"
  fi
  if [[ "${QA_DIAG_VIEWALL:-0}" == "1" ]]; then
    local outv="${out%.png}_viewall.png"
    qa_openscad_png "$outv" "$MODE" -- "$OPENSCAD" -o "$outv" \
      "${OPENSCAD_RENDER_FLAG:---render}" \
      --projection=ortho --autocenter --viewall \
      --view=axes,scales --camera="${camfull}" --imgsize="${IMGSIZE}" \
      -D "mode=${MODE}" "${QA_VIZ_ARGS[@]+"${QA_VIZ_ARGS[@]}"}" "$PROJECT_SCAD"
    qa_manifest_add "$outv" "${camfull};viewall"
    echo "  $outv"
  fi
}

if [[ -n "$ONLY" ]]; then
  _is_preset=0
  IFS=',' read -ra _ONLY_NAMES <<< "$ONLY"
  for _n in "${_ONLY_NAMES[@]}"; do
    for _e in "${ALL_VIEWS[@]}"; do
      if [[ "${_e%%:*}" == "$_n" ]]; then _is_preset=1; break 2; fi
    done
  done

  if [[ $_is_preset -eq 1 ]]; then
    VIEWS=()
    for name in "${_ONLY_NAMES[@]}"; do
      matched=0
      for entry in "${ALL_VIEWS[@]}"; do
        view="${entry%%:*}"
        if [[ "$view" == "$name" ]]; then VIEWS+=("$entry"); matched=1; break; fi
      done
      if [[ $matched -eq 0 ]]; then echo "WARNING: unknown view '$name' - skipping" >&2; fi
    done
    echo "=== ortho render: mode $MODE ($PART) -- ${#VIEWS[@]} preset view(s) ==="
    for entry in "${VIEWS[@]}"; do
      view="${entry%%:*}"; cam6="${entry#*:}"
      OUT="${QA_DIR}/m${MODE}_${view}.png"
      _render_one_ortho "$OUT" "${cam6},${DIST}" "$view"
    done
  else
    _tmp_plan=$(mktemp "${TMPDIR:-/tmp}/qa_views_plan.XXXXXX")
    python3 - "$_DATA_JSON" "$MODE" "$_tmp_plan" "$ONLY" <<'PY' || { rm -f "$_tmp_plan"; echo "WARNING: catalog plan failed" >&2; exit 1; }
import json, os, re, sys
sys.path.insert(0, os.environ.get("QA_SCRIPT_DIR", ""))
try: from qa_fit_helper import resolve_fit
except ImportError: resolve_fit = None
path, mode_s, plan_path = sys.argv[1], sys.argv[2], sys.argv[3]
only_filter = set(sys.argv[4].split(",")) if len(sys.argv) > 4 and sys.argv[4] else set()
with open(path, encoding="utf-8") as f: data = json.load(f)
defaults = data.get("defaults") or {}
entry = (data.get("modes") or {}).get(mode_s)
def safe_lab(s): return re.sub(r"[^a-zA-Z0-9_]", "_", str(s))
def _shot_preset_dist(mode_s, sub, defaults):
    v = sub.get("view") or defaults.get("view", "iso_fr")
    if "fit" in sub:
        if resolve_fit is None: raise SystemExit("ERROR: fit shot requires qa_fit_helper.py")
        d = resolve_fit(int(mode_s), v, sub["fit"])
        if d is None: raise SystemExit(f"ERROR: fit failed for mode {mode_s}")
        return v, int(round(d))
    return v, int(sub.get("dist", defaults.get("dist", 300)))
lines = []
if entry:
    shots = entry.get("shots")
    if isinstance(shots, dict) and shots:
        def _k(sk): return (0, sk) if sk == "default" else (1, sk)
        for sk in sorted(shots.keys(), key=_k):
            if only_filter and safe_lab(sk) not in only_filter and sk not in only_filter: continue
            sub = shots[sk]
            cam = sub.get("camera")
            parts_csv = ",".join(str(p) for p in sub.get("parts", []))
            if cam:
                lines.append([safe_lab(sk), "camera", str(cam).strip().replace("\t", " "), "", parts_csv])
            else:
                v, d = _shot_preset_dist(mode_s, sub, defaults)
                lines.append([safe_lab(sk), "preset", str(v), str(d), parts_csv])
with open(plan_path, "w", encoding="utf-8") as out:
    for row in lines: out.write("\t".join(row) + "\n")
PY
    if [[ -s "$_tmp_plan" ]]; then
      _n=$(wc -l < "$_tmp_plan" | tr -d ' ')
      echo "=== ortho render: mode $MODE ($PART) -- ${_n} catalog shot(s) ==="
      while IFS=$'\t' read -r label kind a1 a2 parts_csv || [[ -n "${label:-}" ]]; do
        [[ -z "${label:-}" ]] && continue
        safe_label=${label//[^a-zA-Z0-9_]/_}
        OUT="${QA_DIR}/m${MODE}_${safe_label}.png"
        if [[ "$kind" == "camera" ]]; then
          [[ -n "${parts_csv:-}" ]] && qa_part_visibility_args "$parts_csv"
          _render_one_ortho "$OUT" "$a1" "$safe_label"
        elif [[ "$kind" == "preset" ]]; then
          view="$a1"; d="${a2:-300}"
          [[ "${QA_VIEWS_IGNORE_CATALOG_DIST:-}" == "1" ]] && d="$DIST"
          qa_cam_resolve_view "$view" || continue
          camfull="${QA_CAM_TX},${QA_CAM_TY},${QA_CAM_TZ},${QA_CAM_RX},${QA_CAM_RY},${QA_CAM_RZ},${d}"
          [[ -n "${parts_csv:-}" ]] && qa_part_visibility_args "$parts_csv"
          _render_one_ortho "$OUT" "$camfull" "$safe_label"
        fi
      done < "$_tmp_plan"
    fi
    rm -f "$_tmp_plan"
  fi
else
  _tmp_plan=$(mktemp "${TMPDIR:-/tmp}/qa_views_plan.XXXXXX")
  python3 - "$_DATA_JSON" "$MODE" "$_tmp_plan" <<'PY' || { rm -f "$_tmp_plan"; echo "ERROR: catalog plan failed for mode $MODE" >&2; exit 1; }
import json, os, re, sys
sys.path.insert(0, os.environ.get("QA_SCRIPT_DIR", ""))
try: from qa_fit_helper import resolve_fit
except ImportError: resolve_fit = None
path, mode_s, plan_path = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, encoding="utf-8") as f: data = json.load(f)
defaults = data.get("defaults") or {}
entry = (data.get("modes") or {}).get(mode_s)
def safe_lab(s): return re.sub(r"[^a-zA-Z0-9_]", "_", str(s))
def _shot_preset_dist(mode_s, sub, defaults):
    v = sub.get("view") or defaults.get("view", "iso_fr")
    if "fit" in sub:
        if resolve_fit is None: raise SystemExit("ERROR: fit shot requires qa_fit_helper.py")
        d = resolve_fit(int(mode_s), v, sub["fit"])
        if d is None: raise SystemExit(f"ERROR: fit failed for mode {mode_s}")
        return v, int(round(d))
    return v, int(sub.get("dist", defaults.get("dist", 300)))
lines = []
if entry:
    shots = entry.get("shots")
    if isinstance(shots, dict) and shots:
        def _k(sk): return (0, sk) if sk == "default" else (1, sk)
        for sk in sorted(shots.keys(), key=_k):
            sub = shots[sk]
            cam = sub.get("camera")
            parts_csv = ",".join(str(p) for p in sub.get("parts", []))
            if cam:
                lines.append([safe_lab(sk), "camera", str(cam).strip().replace("\t", " "), "", parts_csv])
            else:
                v, d = _shot_preset_dist(mode_s, sub, defaults)
                lines.append([safe_lab(sk), "preset", str(v), str(d), parts_csv])
else:
    v = defaults.get("view", "iso_fr"); d = int(defaults.get("dist", 300))
    lines.append([safe_lab(v), "preset", str(v), str(d), ""])
with open(plan_path, "w", encoding="utf-8") as out:
    for row in lines: out.write("\t".join(row) + "\n")
PY
  if [[ -s "$_tmp_plan" ]]; then
    _n=$(wc -l < "$_tmp_plan" | tr -d ' ')
    echo "=== ortho render: mode $MODE ($PART) -- ${_n} catalog shot(s) ==="
    while IFS=$'\t' read -r label kind a1 a2 parts_csv || [[ -n "${label:-}" ]]; do
      [[ -z "${label:-}" ]] && continue
      safe_label=${label//[^a-zA-Z0-9_]/_}
      OUT="${QA_DIR}/m${MODE}_${safe_label}.png"
      if [[ "$kind" == "camera" ]]; then
        [[ -n "${parts_csv:-}" ]] && qa_part_visibility_args "$parts_csv"
        _render_one_ortho "$OUT" "$a1" "$safe_label"
      elif [[ "$kind" == "preset" ]]; then
        view="$a1"; d="${a2:-300}"
        [[ "${QA_VIEWS_IGNORE_CATALOG_DIST:-}" == "1" ]] && d="$DIST"
        qa_cam_resolve_view "$view" || continue
        camfull="${QA_CAM_TX},${QA_CAM_TY},${QA_CAM_TZ},${QA_CAM_RX},${QA_CAM_RY},${QA_CAM_RZ},${d}"
        [[ -n "${parts_csv:-}" ]] && qa_part_visibility_args "$parts_csv"
        _render_one_ortho "$OUT" "$camfull" "$safe_label"
      fi
    done < "$_tmp_plan"
  fi
  rm -f "$_tmp_plan"
fi

qa_manifest_write "$QA_DIR" "qa-views.sh" "$MODE"
echo "QA dir: $QA_DIR"
