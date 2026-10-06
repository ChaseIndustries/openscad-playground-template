#!/usr/bin/env bash
# Scaffold a new project under projects/<slug>/.
#
#   ./scripts/new-project.sh widget
#
# Creates:
#   projects/widget/widget.scad           — entry point with mode switch
#   projects/widget/widget_qa.scad.template — committed QA template
#   projects/widget/playground.json       — entry SCAD, qa.scad paths, etc.
#   projects/widget/repl-config.json      — empty parts/modes/variables
#   projects/widget/data/qa-part-views.json — empty catalog
#   projects/widget/qa-repl.py            — symlink to scripts/qa-repl.py
#   projects/widget/Makefile              — symlink to Makefile (`make start`)
set -euo pipefail

SLUG="${1:?Usage: new-project.sh <slug>}"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DIR="$ROOT/projects/$SLUG"

if [[ -e "$DIR" ]]; then
  echo "ERROR: $DIR already exists." >&2
  exit 1
fi

case "$SLUG" in
  *[!a-zA-Z0-9_-]*)
    echo "ERROR: slug must be alphanumeric, dash or underscore only" >&2
    exit 1 ;;
esac

mkdir -p "$DIR/data"

cat > "$DIR/${SLUG}.scad" <<EOF
// ${SLUG}.scad — entry point for the '${SLUG}' project.
// Switch what gets rendered/exported via -D mode=N (or set mode in ${SLUG}_qa.scad).

include <${SLUG}_defaults.scad>;
include <${SLUG}_qa.scad>;
// Bought parts: check lib/components (README) and lib/NopSCADlib/vitamins
// before modelling one. For example:
// include <../../lib/components/raspberry_pi_pico.scad>;
// include <../../lib/NopSCADlib/core.scad>;
// include <../../lib/NopSCADlib/vitamins/pcbs.scad>;

\$fn = 64;

// ── Mode constants ────────────────────────────────────────────────
SHOW_ASSEMBLY = 0;
PRINT_BODY    = 5;
// Add more print modes (and tie them to repl-config.json "modes" array).

// ── Parameters ────────────────────────────────────────────────────
body_size = [40, 30, 8];
hole_dia  = 4;

// ── Geometry ──────────────────────────────────────────────────────
module body() {
  difference() {
    cube(body_size, center=true);
    cylinder(d=hole_dia, h=body_size.z+1, center=true, \$fn=32);
  }
}

// ── Mode dispatch ────────────────────────────────────────────────
if (mode == SHOW_ASSEMBLY) body();
else if (mode == PRINT_BODY) body();
else assert(false, str("Unknown mode: ", mode));
EOF

cat > "$DIR/${SLUG}_defaults.scad" <<EOF
// Defaults for everything ${SLUG}_qa.scad may override: part visibility,
// preview settings and REPL variables. They live in their own include
// because OpenSCAD only lets a later include override an earlier one
// silently. Assigned in the entry SCAD, they either beat the QA file or
// earn a warning per variable.

// Per-part visibility, one line per repl-config.json "parts" entry.
//viz_show_part_1 = true;

// REPL variables, one line per repl-config.json "variables" entry.
//lid_angle = 0;
EOF

cat > "$DIR/${SLUG}_qa.scad.template" <<EOF
// Local-only QA include (gitignored: ${SLUG}_qa.scad).
// Copied to ${SLUG}_qa.scad on first use by qa-* scripts and the REPL.

// Visibility & assembly preview.
viz_opacity = 1;
show_color_coded = true;
color_scheme = 0;

// Per-part visibility (the REPL toggles these via 'viz_show_part_N' vars).
// Add lines matching the indices in repl-config.json "parts".
//viz_show_part_1 = true;

// QA_REPL_MODE
// REPL rewrites the first \`mode = N;\` line after this marker.
//mode = 5;
mode = 0;

// Variables surfaced by the REPL (one line per repl-config.json "variables" entry).
//lid_angle = 0;

// Echo QA_VIEWPORT after F5 (see docs/OPENSCAD_CLI.md).
qa_dump_viewport = true;
qa_capture_projection = "ortho";

// QA_INTERACTIVE_CAMERA_BEGIN
_orbit_vpt = [0, 0, 0];
_orbit_vpr = [55, 0, 25];
_orbit_vpd = 140;
// QA_INTERACTIVE_CAMERA_END
EOF

cat > "$DIR/playground.json" <<EOF
{
  "scad_entry":       "${SLUG}.scad",
  "qa_scad":          "${SLUG}_qa.scad",
  "qa_scad_template": "${SLUG}_qa.scad.template",
  "data_dir":         "data",
  "build_dir":        "build"
}
EOF

cat > "$DIR/repl-config.json" <<'EOF'
{
  "parts": [],
  "modes": [
    {"id": 0, "name": "Assembly", "type": "pose"},
    {"id": 5, "name": "Print: body", "type": "print", "stl_name": "PRINT_BODY"}
  ],
  "variables": [],
  "color_schemes": ["qa"]
}
EOF

cat > "$DIR/data/qa-part-views.json" <<'EOF'
{
  "schema_version": 1,
  "defaults": {"view": "iso_fr", "dist": 200},
  "modes": {
    "0": {"part_slug": "assembly", "shots": {"default": {"view": "iso_fr_lo", "fit": "viewall"}}},
    "5": {"part_slug": "print_body", "shots": {"default": {"view": "iso_fr_lo", "fit": "viewall"}}}
  }
}
EOF

ln -s ../../scripts/qa-repl.py "$DIR/qa-repl.py"
ln -s ../../Makefile "$DIR/Makefile"

echo "Created $DIR"
echo ""
echo "Next:"
echo "  export PLAYGROUND_PROJECT=$SLUG"
echo "  \$EDITOR projects/$SLUG/${SLUG}.scad"
echo "  bash scripts/qa-views.sh 5 ${SLUG}"
