#!/usr/bin/env bash
# qa-project.sh — resolve the active openscad-playground project and export
# the canonical environment vars used by every QA script:
#
#   PLAYGROUND_ROOT          absolute path to the workbench root (this repo)
#   PLAYGROUND_PROJECT       project slug (folder name under projects/)
#   PLAYGROUND_PROJECT_DIR   absolute path to projects/<slug>/
#   PROJECT_SCAD             entry SCAD filename (e.g. "bracket.scad")
#   PROJECT_QA_SCAD          local QA include filename (e.g. "bracket_qa.scad")
#   PROJECT_QA_TEMPLATE      template for PROJECT_QA_SCAD
#   PROJECT_DATA_DIR         absolute path to per-project data/ (catalogs, etc.)
#   PROJECT_BUILD_DIR        absolute path to per-project build/
#
# Source this from another script:
#
#   source "${_SCRIPT_DIR}/qa-project.sh"
#   qa_project_resolve              # populates the vars above; exits 2 on error
#
# Resolution order (first match wins):
#   1. PLAYGROUND_PROJECT env var (sticky across a shell session)
#   2. cwd is under <workbench>/projects/<name>/  → use that
#   3. .playground-active file at workbench root  → one line: project name
#   4. exactly one project exists in projects/    → use it
#
# Project config lives in projects/<slug>/playground.json:
#
#   {
#     "scad_entry": "bracket.scad",
#     "qa_scad":    "bracket_qa.scad",
#     "qa_scad_template": "bracket_qa.scad.template",
#     "data_dir":   "data",
#     "build_dir":  "build"
#   }
#
# All keys are optional; defaults derive from the project slug.
#
# Compatible with bash 3.2 (macOS).

set -u

qa_project__find_workbench_root() {
  # Walks up from the script dir to find the workbench root (marked by the
  # projects/ directory and the .agents/skills/verify-design tree).
  local d="${_SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
  while [[ "$d" != "/" && "$d" != "" ]]; do
    if [[ -d "$d/projects" && -d "$d/.agents/skills/verify-design" ]]; then
      printf '%s' "$d"
      return 0
    fi
    d=$(dirname "$d")
  done
  # Last resort: git toplevel
  local g
  g=$(git rev-parse --show-toplevel 2>/dev/null || true)
  if [[ -n "$g" && -d "$g/projects" ]]; then
    printf '%s' "$g"
    return 0
  fi
  return 1
}

qa_project__from_cwd() {
  local root="$1"
  local cwd
  cwd=$(pwd -P)
  case "$cwd" in
    "$root/projects/"*)
      local rest="${cwd#$root/projects/}"
      printf '%s' "${rest%%/*}"
      return 0
      ;;
  esac
  return 1
}

qa_project__read_active_pointer() {
  local root="$1"
  local f="$root/.playground-active"
  if [[ -f "$f" ]]; then
    head -n1 "$f" | tr -d ' \t\r\n'
    return 0
  fi
  return 1
}

qa_project__only_project() {
  local root="$1"
  local count=0 only=""
  local d
  for d in "$root/projects"/*/; do
    [[ -d "$d" ]] || continue
    count=$((count + 1))
    only=$(basename "$d")
  done
  if [[ $count -eq 1 ]]; then
    printf '%s' "$only"
    return 0
  fi
  return 1
}

qa_project__read_config_value() {
  # Args: project_dir key default
  local pd="$1" key="$2" default="$3"
  local cfg="$pd/playground.json"
  if [[ ! -f "$cfg" ]]; then
    printf '%s' "$default"
    return 0
  fi
  python3 - "$cfg" "$key" "$default" <<'PY' 2>/dev/null || printf '%s' "$default"
import json, sys
cfg, key, default = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(cfg, encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    print(default, end="")
    sys.exit(0)
v = data.get(key)
print(default if v is None else v, end="")
PY
}

qa_project_resolve() {
  local root
  if ! root=$(qa_project__find_workbench_root); then
    echo "ERROR: cannot find openscad-playground workbench root (no projects/ dir found upwards)" >&2
    return 2
  fi
  PLAYGROUND_ROOT="$root"

  local slug=""
  if [[ -n "${PLAYGROUND_PROJECT:-}" ]]; then
    slug="$PLAYGROUND_PROJECT"
  elif slug=$(qa_project__from_cwd "$root"); then
    :
  elif slug=$(qa_project__read_active_pointer "$root"); then
    :
  elif slug=$(qa_project__only_project "$root"); then
    :
  else
    echo "ERROR: no active project. Set PLAYGROUND_PROJECT=<slug>, run from a projects/<slug>/ subdir, or write the slug to $root/.playground-active." >&2
    echo "       Available projects:" >&2
    local d
    for d in "$root/projects"/*/; do
      [[ -d "$d" ]] && echo "         $(basename "$d")" >&2
    done
    return 2
  fi

  local pd="$root/projects/$slug"
  if [[ ! -d "$pd" ]]; then
    echo "ERROR: project '$slug' not found under $root/projects/" >&2
    return 2
  fi

  PLAYGROUND_PROJECT="$slug"
  PLAYGROUND_PROJECT_DIR="$pd"

  PROJECT_SCAD=$(qa_project__read_config_value "$pd" scad_entry "${slug}.scad")
  PROJECT_QA_SCAD=$(qa_project__read_config_value "$pd" qa_scad "${slug}_qa.scad")
  PROJECT_QA_TEMPLATE=$(qa_project__read_config_value "$pd" qa_scad_template "${PROJECT_QA_SCAD}.template")
  local data_rel build_rel
  data_rel=$(qa_project__read_config_value "$pd" data_dir "data")
  build_rel=$(qa_project__read_config_value "$pd" build_dir "build")
  PROJECT_DATA_DIR="$pd/$data_rel"
  PROJECT_BUILD_DIR="$pd/$build_rel"

  if [[ ! -f "$pd/$PROJECT_SCAD" ]]; then
    echo "ERROR: project '$slug' has no entry SCAD: $pd/$PROJECT_SCAD" >&2
    echo "       (Override with playground.json: { \"scad_entry\": \"...\" })" >&2
    return 2
  fi

  export PLAYGROUND_ROOT PLAYGROUND_PROJECT PLAYGROUND_PROJECT_DIR
  export PROJECT_SCAD PROJECT_QA_SCAD PROJECT_QA_TEMPLATE
  export PROJECT_DATA_DIR PROJECT_BUILD_DIR
  return 0
}

# When sourced into a script, the caller calls qa_project_resolve explicitly.
# When executed (rare), print the resolved environment.
if [[ "${BASH_SOURCE[0]}" == "${0:-}" ]]; then
  _SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  if qa_project_resolve; then
    cat <<EOF
PLAYGROUND_ROOT=$PLAYGROUND_ROOT
PLAYGROUND_PROJECT=$PLAYGROUND_PROJECT
PLAYGROUND_PROJECT_DIR=$PLAYGROUND_PROJECT_DIR
PROJECT_SCAD=$PROJECT_SCAD
PROJECT_QA_SCAD=$PROJECT_QA_SCAD
PROJECT_QA_TEMPLATE=$PROJECT_QA_TEMPLATE
PROJECT_DATA_DIR=$PROJECT_DATA_DIR
PROJECT_BUILD_DIR=$PROJECT_BUILD_DIR
EOF
  else
    exit $?
  fi
fi
