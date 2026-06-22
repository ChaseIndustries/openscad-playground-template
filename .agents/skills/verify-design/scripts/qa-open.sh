#!/usr/bin/env bash
# qa-open.sh — interactive project picker that opens a project in the OpenSCAD GUI.
#
# Lists every project under projects/, lets you pick one (arrow-key menu:
# Up/Down to move, Enter to open, q to quit; 1-9 jump), makes it the active
# project (writes .playground-active), materializes its <slug>_qa.scad from the
# committed template if needed, points the global viewer at it (writes
# playground-active.scad), and opens playground.scad in the OpenSCAD GUI — one
# window that follows whatever project you select (here or via the REPL's g).
#
# Usage:
#   qa-open.sh                 # interactive menu
#   qa-open.sh <slug>          # open a named project directly (no menu)
#   qa-open.sh -l | --list     # just list projects and exit
#   qa-open.sh -n | --no-open  # set active + materialize qa.scad, but don't launch GUI
#   qa-open.sh -h | --help
#
# Env:
#   OPENSCAD=          override the OpenSCAD binary (default: open -a OpenSCAD on
#                      macOS, else the `openscad` binary launched as a GUI).
#
# The file opened in the GUI is <slug>_qa.scad — the user-facing QA include
# (gitignored, per-project). Agents must never hand-edit that file; this script
# only creates it from the template when it does not yet exist.
#
# Compatible with bash 3.2 (macOS).

set -u

_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=qa-project.sh
source "${_SCRIPT_DIR}/qa-project.sh"

_qa_open_usage() {
  # Print the leading comment block (skip the shebang, stop at first non-comment).
  awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "${BASH_SOURCE[0]}"
}

# Collect project slugs (directories under projects/ that contain a playground.json
# or an entry .scad) into the global array QA_OPEN_PROJECTS.
_qa_open_collect() {
  local root="$1"
  QA_OPEN_PROJECTS=()
  local d slug
  for d in "$root/projects"/*/; do
    [[ -d "$d" ]] || continue
    slug=$(basename "$d")
    # Skip dotfile/build dirs that aren't real projects.
    case "$slug" in .*) continue;; esac
    QA_OPEN_PROJECTS+=("$slug")
  done
}

# Print the entry SCAD filename for a slug, honouring playground.json.
_qa_open_entry_for() {
  local root="$1" slug="$2"
  qa_project__read_config_value "$root/projects/$slug" scad_entry "${slug}.scad"
}

# Pretty-print the project list with an active marker.
_qa_open_print_list() {
  local root="$1" active="$2"
  local i=1 slug entry mark
  for slug in "${QA_OPEN_PROJECTS[@]}"; do
    entry=$(_qa_open_entry_for "$root" "$slug")
    mark="  "
    [[ "$slug" == "$active" ]] && mark="* "
    if [[ -f "$root/projects/$slug/$entry" ]]; then
      printf '  %s%2d) %s\n' "$mark" "$i" "$slug"
    else
      printf '  %s%2d) %s  (no entry SCAD: %s)\n' "$mark" "$i" "$slug" "$entry"
    fi
    i=$((i + 1))
  done
}

# Interactive arrow-key menu. Sets QA_OPEN_MENU_RESULT to the chosen slug and
# returns 0; returns 1 if the user cancels (q / Esc). Puts the terminal in raw
# mode for the duration (restored on every exit path, including Ctrl-C) so the
# multi-byte arrow-key escape sequences read reliably. Also accepts j/k to move
# and 1-9 to jump. Uses raw ANSI escapes; no tput dependency.
_qa_open_menu() {
  local root="$1" active="$2"
  local n=${#QA_OPEN_PROJECTS[@]}
  local labels=() i slug entry mark
  for ((i = 0; i < n; i++)); do
    slug="${QA_OPEN_PROJECTS[$i]}"
    entry=$(_qa_open_entry_for "$root" "$slug")
    mark=" "; [[ "$slug" == "$active" ]] && mark="*"
    if [[ -f "$root/projects/$slug/$entry" ]]; then
      labels+=("$mark $slug")
    else
      labels+=("$mark $slug  (no entry SCAD: $entry)")
    fi
  done

  # Start the cursor on the active project if there is one.
  local sel=0
  for ((i = 0; i < n; i++)); do
    [[ "${QA_OPEN_PROJECTS[$i]}" == "$active" ]] && { sel=$i; break; }
  done

  local saved_stty
  saved_stty=$(stty -g 2>/dev/null || true)
  _qa_menu_restore() {
    [[ -n "$saved_stty" ]] && stty "$saved_stty" 2>/dev/null
    printf '\033[?25h' >&2          # show cursor
    trap - INT
  }
  trap '_qa_menu_restore; return 130' INT
  # Char-at-a-time, no echo. min 1 / time 0 => each read blocks for one byte.
  stty -echo -icanon min 1 time 0 2>/dev/null

  _qa_menu_draw() {
    local j
    for ((j = 0; j < n; j++)); do
      if [[ $j -eq $sel ]]; then
        printf '  \033[7m> %s\033[0m\n' "${labels[$j]}" >&2
      else
        printf '    %s\n' "${labels[$j]}" >&2
      fi
    done
  }

  printf 'Select a project to open in OpenSCAD  (* = active):\n' >&2
  printf '  Up/Down move \xc2\xb7 1-9 jump \xc2\xb7 Enter open \xc2\xb7 q quit\n' >&2
  printf '\033[?25l' >&2            # hide cursor
  _qa_menu_draw

  local key rest ret=1
  while :; do
    key=""
    IFS= read -rsn1 key || { ret=1; break; }
    case "$key" in
      $'\x1b')
        # Integer timeout only: macOS bash 3.2 rejects fractional `read -t`.
        # In raw mode the arrow tail bytes are already buffered, so this returns
        # immediately for real arrows; only a lone Esc waits (q cancels instantly).
        rest=""
        IFS= read -rsn2 -t 1 rest
        case "$rest" in
          '[A'|'OA') ((sel > 0)) && sel=$((sel - 1)) || sel=$((n - 1));;
          '[B'|'OB') ((sel < n - 1)) && sel=$((sel + 1)) || sel=0;;
          '') ret=1; break;;          # bare Esc = cancel
        esac
        ;;
      k|K) ((sel > 0)) && sel=$((sel - 1)) || sel=$((n - 1));;
      j|J) ((sel < n - 1)) && sel=$((sel + 1)) || sel=0;;
      q|Q) ret=1; break;;
      ''|$'\n'|$'\r') ret=0; break;;   # Enter (raw mode sends CR)
      [1-9]) [[ "$key" -ge 1 && "$key" -le $n ]] && sel=$((key - 1));;
    esac
    printf '\033[%dA' "$n" >&2        # move cursor back up over the list
    _qa_menu_draw
  done

  _qa_menu_restore
  if [[ $ret -eq 0 ]]; then
    QA_OPEN_MENU_RESULT="${QA_OPEN_PROJECTS[$sel]}"
    return 0
  fi
  return 1
}

# Launch the OpenSCAD GUI on a file, detached.
_qa_open_launch_gui() {
  local file="$1"
  if [[ -n "${OPENSCAD:-}" ]]; then
    echo "Opening in GUI: $OPENSCAD $file" >&2
    "$OPENSCAD" "$file" >/dev/null 2>&1 &
    return 0
  fi
  case "$(uname -s)" in
    Darwin)
      if [[ -d "/Applications/OpenSCAD.app" ]] || command -v open >/dev/null 2>&1; then
        echo "Opening in OpenSCAD GUI: $file" >&2
        open -a OpenSCAD "$file"
        return 0
      fi
      ;;
  esac
  if command -v openscad >/dev/null 2>&1; then
    echo "Opening in GUI: openscad $file" >&2
    openscad "$file" >/dev/null 2>&1 &
    return 0
  fi
  echo "ERROR: could not find OpenSCAD. Set OPENSCAD=/path/to/openscad." >&2
  return 1
}

main() {
  local want="" list_only=0 no_open=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) _qa_open_usage; return 0;;
      -l|--list) list_only=1;;
      -n|--no-open) no_open=1;;
      -*) echo "ERROR: unknown option: $1" >&2; _qa_open_usage >&2; return 2;;
      *) want="$1";;
    esac
    shift
  done

  local root
  if ! root=$(qa_project__find_workbench_root); then
    echo "ERROR: cannot find openscad-playground workbench root (no projects/ dir found upwards)" >&2
    return 2
  fi

  _qa_open_collect "$root"
  if [[ ${#QA_OPEN_PROJECTS[@]} -eq 0 ]]; then
    echo "ERROR: no projects found under $root/projects/" >&2
    return 2
  fi

  local active=""
  active=$(qa_project__read_active_pointer "$root" 2>/dev/null || true)

  if [[ $list_only -eq 1 ]]; then
    echo "Projects in $root/projects/  (* = active):" >&2
    _qa_open_print_list "$root" "$active"
    return 0
  fi

  local slug=""
  if [[ -n "$want" ]]; then
    # Direct selection by slug (validate against the list).
    local s
    for s in "${QA_OPEN_PROJECTS[@]}"; do
      [[ "$s" == "$want" ]] && slug="$want" && break
    done
    if [[ -z "$slug" ]]; then
      echo "ERROR: no such project: $want" >&2
      echo "Available:" >&2
      _qa_open_print_list "$root" "$active"
      return 2
    fi
  elif [[ ${#QA_OPEN_PROJECTS[@]} -eq 1 ]]; then
    slug="${QA_OPEN_PROJECTS[0]}"
    echo "Only one project — selecting: $slug" >&2
  else
    # Interactive menu with arrow-key navigation.
    if [[ ! -t 0 ]]; then
      echo "ERROR: no project given and stdin is not a TTY (can't show menu)." >&2
      echo "Pass a slug: qa-open.sh <slug>   (or use -l to list)" >&2
      return 2
    fi
    if ! _qa_open_menu "$root" "$active"; then
      echo "Cancelled." >&2
      return 1
    fi
    slug="$QA_OPEN_MENU_RESULT"
  fi

  # Make it the active project so subsequent QA scripts default to it.
  printf '%s\n' "$slug" > "$root/.playground-active"
  echo "Active project -> $slug  (wrote $root/.playground-active)" >&2

  # Resolve the project's config (entry, qa include, template) via the shared
  # resolver, scoped to this slug.
  PLAYGROUND_PROJECT="$slug"
  if ! qa_project_resolve; then
    return 2
  fi

  # Ensure the per-project GUI QA include exists (materialize from template).
  if ! qa_ensure_view_camera_standalone "$PLAYGROUND_PROJECT_DIR"; then
    return 2
  fi

  # Point the global viewer (playground.scad) at this project so a single open
  # OpenSCAD window follows whatever you select here (and in the REPL).
  printf '%s\n%s\n%s\n' \
    "// AUTO-GENERATED by qa-repl.py / qa-open.sh — do not edit." \
    "// Points the global playground.scad viewer at the active project." \
    "include <projects/$slug/$PROJECT_SCAD>;" \
    > "$root/playground-active.scad"

  # Open the global viewer if it exists; otherwise fall back to the per-project
  # QA include (or entry SCAD).
  local gui_file="$root/playground.scad"
  if [[ ! -f "$gui_file" ]]; then
    gui_file="$PLAYGROUND_PROJECT_DIR/$PROJECT_QA_SCAD"
    [[ -f "$gui_file" ]] || gui_file="$PLAYGROUND_PROJECT_DIR/$PROJECT_SCAD"
  fi

  if [[ $no_open -eq 1 ]]; then
    echo "Active project ready (not opening, --no-open). Viewer: $gui_file" >&2
    return 0
  fi

  _qa_open_launch_gui "$gui_file"
}

# Self-contained copy of qa_ensure_view_camera (qa-common.sh) so this script has
# no dependency on the larger common library just to materialize one file.
qa_ensure_view_camera_standalone() {
  local pd="$1"
  local qa_name="${PROJECT_QA_SCAD:-qa.scad}"
  local tmpl_name="${PROJECT_QA_TEMPLATE:-${qa_name}.template}"
  local dest="$pd/$qa_name"
  local tmpl="$pd/$tmpl_name"
  if [[ -f "$dest" ]]; then return 0; fi
  if [[ ! -f "$tmpl" ]]; then
    echo "NOTICE: no $qa_name and no template $tmpl_name; will open the entry SCAD instead." >&2
    return 0
  fi
  cp "$tmpl" "$dest"
  echo "Created $dest from $tmpl_name (local only; gitignored)." >&2
}

main "$@"
