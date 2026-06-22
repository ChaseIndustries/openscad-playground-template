#!/usr/bin/env bash
# Shared helpers for openscad-playground QA scripts (sourced, not executed).
# Generalized from cyberdeck/.agents/skills/verify-design/scripts/qa-common.sh.
# macOS /bin/bash 3.2 compatible — no associative arrays.
#
# This file expects qa_project_resolve() to have populated:
#   PLAYGROUND_ROOT, PLAYGROUND_PROJECT, PLAYGROUND_PROJECT_DIR,
#   PROJECT_SCAD, PROJECT_QA_SCAD, PROJECT_QA_TEMPLATE,
#   PROJECT_DATA_DIR, PROJECT_BUILD_DIR
# Most scripts source qa-project.sh and call qa_project_resolve before this.

# Canonical orthographic camera presets: name:tx,ty,tz,rx,ry,rz (distance is separate; use DIST).
QA_CAMERA_VIEWS=(
  "top:0,0,0,0,0,0"
  "bottom:0,0,0,180,0,0"
  "front:0,0,0,90,0,0"
  "back:0,0,0,90,0,180"
  "left:0,0,0,90,0,-90"
  "right:0,0,0,90,0,90"
  "iso_fr:0,0,0,55,0,25"
  "iso_fl:0,0,0,55,0,-25"
  "iso_br:0,0,0,55,0,155"
  "iso_bl:0,0,0,55,0,-155"
  "iso_fr_hi:0,0,0,70,0,25"
  "iso_fl_hi:0,0,0,70,0,-25"
  "iso_br_hi:0,0,0,70,0,155"
  "iso_bl_hi:0,0,0,70,0,-155"
  "iso_fr_lo:0,0,0,30,0,25"
  "iso_fl_lo:0,0,0,30,0,-25"
  "iso_br_lo:0,0,0,30,0,155"
  "iso_bl_lo:0,0,0,30,0,-155"
)

# Default colorscheme for QA renders (dark background, better contrast).
: "${QA_COLORSCHEME:=Tomorrow Night}"

qa_json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g;s/"/\\"/g'
}

# Sets QA_CAM_TX..QA_CAM_RZ from a preset name.
qa_cam_resolve_view() {
  local want="$1"
  local entry view rest
  for entry in "${QA_CAMERA_VIEWS[@]}"; do
    view="${entry%%:*}"
    rest="${entry#*:}"
    if [[ "$view" == "$want" ]]; then
      IFS=',' read -r QA_CAM_TX QA_CAM_TY QA_CAM_TZ QA_CAM_RX QA_CAM_RY QA_CAM_RZ <<< "$rest"
      return 0
    fi
  done
  echo "ERROR: unknown VIEW '$want' (see --help for names)" >&2
  return 1
}

qa_cam_list_names() {
  local entry
  for entry in "${QA_CAMERA_VIEWS[@]}"; do
    printf '  %s\n' "${entry%%:*}"
  done
}

# Compute auto-fit ortho distance for a mode via --viewall + --summary all.
# Args: <mode> <view_preset_name> [openscad_bin]
qa_viewall_distance() {
  local mode="$1"
  local view="$2"
  local openscad="${3:-${OPENSCAD:-openscad}}"
  if [[ -z "${mode:-}" || -z "${view:-}" ]]; then
    echo "ERROR: qa_viewall_distance: usage: qa_viewall_distance <mode> <view_preset> [openscad]" >&2
    return 2
  fi
  if ! qa_cam_resolve_view "$view"; then
    return 1
  fi
  local tmpdir jsn png cam rc
  tmpdir=$(mktemp -d -t qa_vdist.XXXXXX) || return 1
  jsn="${tmpdir}/cam.json"
  png="${tmpdir}/cam.png"
  cam="${QA_CAM_TX},${QA_CAM_TY},${QA_CAM_TZ},${QA_CAM_RX},${QA_CAM_RY},${QA_CAM_RZ},999"
  if ! "$openscad" --summary all --summary-file "$jsn" \
       -o "$png" --render --imgsize=64,64 \
       --projection=ortho --autocenter --viewall \
       --camera="$cam" \
       -D "mode=${mode}" "${PROJECT_SCAD:?qa_viewall_distance needs PROJECT_SCAD (run qa_project_resolve)}" >/dev/null 2>&1; then
    rm -rf "$tmpdir"; return 1
  fi
  if [[ ! -s "$jsn" ]]; then rm -rf "$tmpdir"; return 1; fi
  python3 -c "
import json, sys
d = json.load(open('$jsn'))
cam = d.get('camera') or {}
dist = cam.get('distance')
if dist is None: sys.exit(1)
print(f'{float(dist):.4f}')
" 2>/dev/null
  rc=$?
  rm -rf "$tmpdir"
  return $rc
}

# Bounding-box center via --summary all. Prints "cx cy cz" on success.
qa_bbox_center() {
  local mode="$1"
  local openscad="${2:-${OPENSCAD:-openscad}}"
  local tmpdir jsn png rc
  tmpdir=$(mktemp -d -t qa_bbox.XXXXXX) || return 1
  jsn="${tmpdir}/bbox.json"
  png="${tmpdir}/bbox.png"
  if ! "$openscad" --summary all --summary-file "$jsn" \
       -o "$png" --render --imgsize=64,64 \
       -D "mode=${mode}" "${PROJECT_SCAD:?qa_bbox_center needs PROJECT_SCAD (run qa_project_resolve)}" >/dev/null 2>&1; then
    rm -rf "$tmpdir"; return 1
  fi
  if [[ ! -s "$jsn" ]]; then rm -rf "$tmpdir"; return 1; fi
  python3 -c "
import json, sys
d = json.load(open('$jsn'))
bb = (d.get('geometry') or {}).get('bounding_box') or {}
mn = bb.get('min'); mx = bb.get('max')
if not (mn and mx): sys.exit(1)
print(f'{(mn[0]+mx[0])/2:.4f} {(mn[1]+mx[1])/2:.4f} {(mn[2]+mx[2])/2:.4f}')
" 2>/dev/null
  rc=$?
  rm -rf "$tmpdir"
  return $rc
}

# Ensure the project's local QA include file exists (PROJECT_QA_SCAD). Copies
# from PROJECT_QA_TEMPLATE if not present. Optional arg overrides the project
# dir; defaults to PLAYGROUND_PROJECT_DIR.
qa_ensure_view_camera() {
  local pd="${1:-${PLAYGROUND_PROJECT_DIR:-}}"
  if [[ -z "$pd" ]]; then
    echo "ERROR: qa_ensure_view_camera: PLAYGROUND_PROJECT_DIR not set (call qa_project_resolve first)" >&2
    return 1
  fi
  local qa_name="${PROJECT_QA_SCAD:-qa.scad}"
  local tmpl_name="${PROJECT_QA_TEMPLATE:-${qa_name}.template}"
  local dest="$pd/$qa_name"
  local tmpl="$pd/$tmpl_name"
  if [[ -f "$dest" ]]; then return 0; fi
  if [[ ! -f "$tmpl" ]]; then
    echo "ERROR: missing template $tmpl (commit one so $qa_name can be created on demand)" >&2
    return 1
  fi
  cp "$tmpl" "$dest"
  echo "Created $dest from $tmpl_name (local only; gitignored)." >&2
}

# Run OpenSCAD or echo when DRY_RUN=1.
qa_run_openscad() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    printf 'DRY_RUN:'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

# File size in bytes (macOS + GNU stat).
_qa_file_size() {
  local p="$1"
  if stat -f%z "$p" >/dev/null 2>&1; then stat -f%z "$p"
  elif stat -c%s "$p" >/dev/null 2>&1; then stat -c%s "$p"
  else wc -c <"$p" | tr -d ' '; fi
}

_qa_png_hints() {
  local mode="$1"
  cat <<EOF >&2
  Hints — failed export (missing file or tiny PNG):
  - Try OPENSCAD_RENDER_FLAG=--render=true (some 2025.x builds want a value).
  - Ensure cwd is the project dir and ${PROJECT_SCAD:-<entry>.scad} exists.
  - Lower QA_PNG_MIN_BYTES only if IMGSIZE is very small.

  Hints — PNG exists but viewport looks empty:
  - Run qa-compile.sh ${mode} — zero triangles means nothing to render.
  - Wrong mode branch in ${PROJECT_SCAD:-<entry>.scad} (grep -n 'mode ==' against your -D mode=${mode}).
  - Camera: raise DIST= (try 500–900), or try another VIEW=; keep --projection=ortho --autocenter.
  - Re-run qa-views with QA_DIAG_VIEWALL=1 — writes *_viewall.png twins (--viewall reframes).
  - THROWN=1 qa-zoom.sh same mode — quick hull preview.
EOF
}

# Verify a PNG is non-trivial.
qa_verify_png() {
  local path="$1"
  local min_b="${QA_PNG_MIN_BYTES:-5000}"
  if [[ ! -f "$path" ]]; then
    echo "ERROR: PNG was not written: $path" >&2; return 1
  fi
  local sz; sz=$(_qa_file_size "$path")
  if [[ -z "${sz:-}" || "$sz" -lt "$min_b" ]]; then
    echo "ERROR: PNG missing or export likely failed — file too small (${sz:-0} bytes, min ${min_b}): $path" >&2
    return 1
  fi
  if command -v file >/dev/null 2>&1; then
    if ! file "$path" 2>/dev/null | grep -qi 'PNG image'; then
      echo "ERROR: Not a PNG (file(1)): $path" >&2; return 1
    fi
  fi
  return 0
}

# Run OpenSCAD for one PNG, verify, optionally retry with --render=true.
_qa_exec_png_loop() {
  local out="$1" mode="$2" attempt="$3"
  shift 3
  local args=("$@")
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    qa_run_openscad "${args[@]}"; return 0
  fi
  set +e
  "${args[@]}"
  local ec=$?
  set -e
  if [[ $ec -ne 0 ]]; then
    echo "ERROR: OpenSCAD exited $ec." >&2
    _qa_png_hints "$mode"
    return "$ec"
  fi
  if qa_verify_png "$out"; then return 0; fi
  _qa_png_hints "$mode"
  if [[ "$attempt" -ge 1 ]]; then return 1; fi
  if [[ "${OPENSCAD_PNG_AUTO_RETRY:-1}" != "1" ]]; then return 1; fi

  local has_preview=0 i nd=0 retry=0
  nd=${#args[@]}
  for ((i=0; i<nd; i++)); do
    case "${args[$i]}" in *throwntogether*) has_preview=1; break ;; esac
  done
  if [[ $has_preview -eq 1 ]]; then return 1; fi
  for ((i=0; i<nd; i++)); do
    if [[ "${args[$i]}" == "--render" ]]; then
      args[$i]="--render=true"; retry=1; break
    fi
  done
  if [[ $retry -eq 0 ]]; then return 1; fi
  echo "NOTICE: Retrying once with --render=true (disable: OPENSCAD_PNG_AUTO_RETRY=0)." >&2
  _qa_exec_png_loop "$out" "$mode" 1 "${args[@]}"
}

qa_openscad_png() {
  local out="$1" mode="$2"
  if [[ "${3:-}" != "--" ]]; then
    echo "ERROR: qa_openscad_png internal: expected -- before argv" >&2; return 2
  fi
  shift 3
  _qa_exec_png_loop "$out" "$mode" 0 "$@"
}

# Throwntogether *_debug.png twin. Only enabled for catalog shots that flag
# part_slug starting with "assembly_" by default. Set QA_PREVIEW_DEBUG=all to
# force on for everything; QA_PREVIEW_DEBUG=0 to disable entirely.
qa_preview_debug_enabled() {
  local v mode="${1-}"
  v="${QA_PREVIEW_DEBUG-}"
  case "$(printf '%s' "$v" | tr '[:upper:]' '[:lower:]')" in
    0|false|no|off) return 1 ;;
    all) return 0 ;;
  esac
  if [[ -n "$mode" ]]; then
    local json="${QA_PART_VIEWS_JSON:-${PROJECT_DATA_DIR:-.}/qa-part-views.json}"
    if [[ -f "$json" ]]; then
      local slug
      slug=$(python3 -c "import json,sys;d=json.load(open('$json'));print(d.get('modes',{}).get('$mode',{}).get('part_slug',''))" 2>/dev/null)
      case "$slug" in
        assembly_*) return 0 ;;
        *) return 1 ;;
      esac
    fi
  fi
  return 0
}

# Throwntogether twin for a CGAL ortho shot.
qa_maybe_emit_throwntogether_debug_ortho() {
  local primary="$1" mode="$2" openscad="$3" cam="$4" imgsize="$5"
  shift 5
  qa_preview_debug_enabled "$mode" || return 0
  [[ "${THROWN:-0}" == "1" ]] && return 0
  local dbg="${primary%.png}_debug.png"
  local _cs_args=()
  if [[ -n "${QA_COLORSCHEME:-}" ]]; then
    _cs_args=(--colorscheme="$QA_COLORSCHEME")
  fi
  if [[ ${#_cs_args[@]} -gt 0 ]]; then
    qa_openscad_png "$dbg" "$mode" -- "$openscad" -o "$dbg" \
      --projection=ortho --autocenter "$@" \
      "${_cs_args[@]}" --view=axes,scales \
      --camera="${cam}" --imgsize="${imgsize}" \
      --preview=throwntogether \
      -D "mode=${mode}" "${QA_VIZ_ARGS[@]+"${QA_VIZ_ARGS[@]}"}" "$PROJECT_SCAD"
  else
    qa_openscad_png "$dbg" "$mode" -- "$openscad" -o "$dbg" \
      --projection=ortho --autocenter "$@" \
      --view=axes,scales \
      --camera="${cam}" --imgsize="${imgsize}" \
      --preview=throwntogether \
      -D "mode=${mode}" "${QA_VIZ_ARGS[@]+"${QA_VIZ_ARGS[@]}"}" "$PROJECT_SCAD"
  fi
}

QA_MF_ENTRIES=()
qa_manifest_clear() { QA_MF_ENTRIES=(); }
qa_manifest_add()   { QA_MF_ENTRIES+=("$1|$2"); }

# Relative qa_dir is resolved from PLAYGROUND_PROJECT_DIR.
qa_resolve_qa_dir() {
  local d="$1" root="$2"
  if [[ "$d" = /* ]]; then printf '%s' "$d"
  else printf '%s/%s' "$root" "$d"; fi
}

qa_manifest_write() {
  [[ "${QA_MANIFEST:-0}" != "1" ]] && return 0
  local qdir="$1" script="$2" mode="$3"
  mkdir -p "$qdir"
  local out="$qdir/qa-manifest.json"
  local iso dr tmp
  iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  dr="${DRY_RUN:-0}"
  tmp=$(mktemp "${TMPDIR:-/tmp}/qa-manifest.XXXXXX.json")
  {
    echo "{"
    echo "  \"generated_utc\": \"$(qa_json_escape "$iso")\","
    echo "  \"script\": \"$(qa_json_escape "$script")\","
    echo "  \"project\": \"$(qa_json_escape "${PLAYGROUND_PROJECT:-}")\","
    echo "  \"mode\": $mode,"
    echo "  \"dry_run\": $dr,"
    echo "  \"outputs\": ["
    local first=1 line path cam ep ec
    for line in "${QA_MF_ENTRIES[@]:-}"; do
      path="${line%%|*}"; cam="${line#*|}"
      ep=$(qa_json_escape "$path"); ec=$(qa_json_escape "$cam")
      if [[ $first -eq 1 ]]; then first=0; else echo ","; fi
      printf '    {"path":"%s","camera":"%s"}' "$ep" "$ec"
    done
    echo ""
    echo "  ]"
    echo "}"
  } >"$tmp"

  if [[ -f "$out" ]] && command -v python3 >/dev/null 2>&1; then
    python3 -c "
import json, os, sys
outp, newp = sys.argv[1], sys.argv[2]
with open(newp, encoding='utf-8') as f: new = json.load(f)
if os.path.isfile(outp):
    try:
        with open(outp, encoding='utf-8') as f: old = json.load(f)
        new['outputs'] = list(old.get('outputs', [])) + list(new.get('outputs', []))
    except json.JSONDecodeError: pass
with open(outp, 'w', encoding='utf-8') as f: json.dump(new, f, indent=2)
" "$out" "$tmp" && rm -f "$tmp"
  else
    mv -f "$tmp" "$out"
  fi
  echo "Manifest: $out"
}

# ── Part visibility (PARTS / HIDE) ───────────────────────────────────
# QA_PART_REGISTRY is populated from the project's repl-config.json on demand.
# Format: "index:name" strings.

QA_PART_REGISTRY=()
QA_PART_REGISTRY_LOADED=0

qa_load_part_registry() {
  [[ "$QA_PART_REGISTRY_LOADED" == "1" ]] && return 0
  QA_PART_REGISTRY=()
  local cfg="${PLAYGROUND_PROJECT_DIR:-}/repl-config.json"
  if [[ -z "$cfg" || ! -f "$cfg" ]]; then
    QA_PART_REGISTRY_LOADED=1
    return 0
  fi
  local line
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    QA_PART_REGISTRY+=("$line")
  done < <(python3 - "$cfg" <<'PY' 2>/dev/null
import json, re, sys
with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
for p in data.get("parts") or []:
    idx = p.get("idx")
    name = p.get("slug") or p.get("name") or ""
    name = re.sub(r"[^a-zA-Z0-9_]+", "_", str(name).strip().lower()).strip("_")
    if idx is None or not name:
        continue
    print(f"{idx}:{name}")
PY
)
  QA_PART_REGISTRY_LOADED=1
}

_qa_resolve_part_token() {
  qa_load_part_registry
  local token="$1" entry pidx pname
  for entry in "${QA_PART_REGISTRY[@]:-}"; do
    pidx="${entry%%:*}"; pname="${entry#*:}"
    if [[ "$pname" == "$token" ]]; then printf '%s' "$pidx"; return 0; fi
  done
  case "$token" in
    *[!0-9]*) ;;
    *)
      # Numeric tokens always pass through (lets projects without repl-config still use indices)
      printf '%s' "$token"; return 0
      ;;
  esac
  echo "ERROR: unknown part '$token'. Valid names/indices for project '${PLAYGROUND_PROJECT:-?}':" >&2
  for entry in "${QA_PART_REGISTRY[@]:-}"; do
    pidx="${entry%%:*}"; pname="${entry#*:}"
    echo "  $pidx  $pname" >&2
  done
  return 1
}

# Populates QA_VIZ_ARGS from PARTS=/HIDE= env vars (or one comma-separated arg).
QA_VIZ_ARGS=()
qa_part_visibility_args() {
  QA_VIZ_ARGS=()
  local catalog_parts="${1:-}"
  if [[ -n "${PARTS:-}" && -n "${HIDE:-}" ]]; then
    echo "ERROR: set PARTS= or HIDE=, not both." >&2; exit 2
  fi
  local mode="" raw=""
  if [[ -n "${PARTS:-}" ]]; then mode="show"; raw="$PARTS"
  elif [[ -n "${HIDE:-}" ]]; then mode="hide"; raw="$HIDE"
  elif [[ -n "$catalog_parts" ]]; then mode="show"; raw="$catalog_parts"
  else return 0; fi

  qa_load_part_registry
  local resolved=()
  local token idx
  while IFS= read -r token; do
    token=$(printf '%s' "$token" | tr -d ' ')
    [[ -z "$token" ]] && continue
    idx=$(_qa_resolve_part_token "$token") || exit 1
    resolved+=("$idx")
  done < <(printf '%s\n' "$raw" | tr ',' '\n')

  if [[ "$mode" == "show" ]]; then
    # Hide everything in the registry NOT in resolved; if registry is empty
    # (project has no repl-config), this is a no-op and PARTS= has no effect.
    local entry pidx found r
    for entry in "${QA_PART_REGISTRY[@]:-}"; do
      pidx="${entry%%:*}"
      found=0
      for r in "${resolved[@]:-}"; do
        if [[ "$r" == "$pidx" ]]; then found=1; break; fi
      done
      if [[ $found -eq 0 ]]; then
        QA_VIZ_ARGS+=(-D "viz_show_part_${pidx}=false")
      fi
    done
  else
    local r
    for r in "${resolved[@]}"; do
      QA_VIZ_ARGS+=(-D "viz_show_part_${r}=false")
    done
  fi
}

# ── QA Sandbox (agent isolation) ─────────────────────────────────────
# Creates a temporary directory that mirrors the project dir via symlinks,
# with a private copy of PROJECT_SCAD and PROJECT_QA_SCAD.

qa_create_sandbox() {
  local pd="${1:-${PLAYGROUND_PROJECT_DIR:-}}"
  if [[ -z "$pd" ]]; then
    echo "ERROR: qa_create_sandbox: PLAYGROUND_PROJECT_DIR not set" >&2; return 1
  fi
  if [[ ! -f "$pd/$PROJECT_SCAD" ]]; then
    echo "ERROR: qa_create_sandbox: $pd/$PROJECT_SCAD does not exist" >&2; return 1
  fi
  local sandbox
  sandbox=$(mktemp -d "${TMPDIR:-/tmp}/qa_sandbox.XXXXXX") || return 1

  local item name
  for item in "$pd"/*; do
    name=$(basename "$item")
    case "$name" in
      "$PROJECT_SCAD"|"$PROJECT_QA_SCAD") ;;
      *) ln -s "$item" "$sandbox/$name" ;;
    esac
  done
  for item in "$pd"/.[!.]* "$pd"/..?*; do
    [[ -e "$item" ]] || continue
    name=$(basename "$item")
    ln -s "$item" "$sandbox/$name" 2>/dev/null || true
  done

  cp "$pd/$PROJECT_SCAD" "$sandbox/$PROJECT_SCAD"

  local tmpl="$pd/$PROJECT_QA_TEMPLATE"
  if [[ ! -f "$tmpl" ]]; then
    echo "ERROR: qa_create_sandbox: missing $tmpl" >&2
    rm -rf "$sandbox"; return 1
  fi
  cp "$tmpl" "$sandbox/$PROJECT_QA_SCAD"

  printf '%s\n' "$sandbox"
}

qa_cleanup_sandbox() {
  local sandbox="$1"
  if [[ -z "$sandbox" || "$sandbox" == "/" ]]; then return 1; fi
  case "$sandbox" in
    */qa_sandbox.*) rm -rf "$sandbox" ;;
    *) echo "WARNING: qa_cleanup_sandbox: refusing to remove '$sandbox'" >&2; return 1 ;;
  esac
}
