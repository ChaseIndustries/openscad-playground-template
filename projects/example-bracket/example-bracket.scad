// example-bracket.scad — a worked example for openscad-playground.
//
// A hinged L-bracket with two halves and a mounting plate. Demonstrates:
//   * `mode = N;` dispatch (assembly + per-part print modes)
//   * Per-part visibility via viz_show_part_N booleans (toggled by REPL/PARTS=)
//   * A single tunable variable (`lid_angle`) the REPL exposes as a slider
//   * Catalog views (qa-part-views.json) for repeatable QA shots
//
// To run interactively:
//   export PLAYGROUND_PROJECT=example-bracket
//   open Cyberdeck.scad equivalent: open OpenSCAD on this file
//   python3 scripts/qa-repl.py    # opens a TTY control panel

include <example-bracket_qa.scad>;

$fn = 64;

// ── Mode constants (mirrored in repl-config.json "modes") ─────────
SHOW_ASSEMBLY    = 0;
SHOW_EXPLODED    = 1;
PRINT_BASE       = 5;
PRINT_LID        = 6;
PRINT_PLATE      = 7;

// ── Part indices for visibility (mirrored in repl-config.json "parts") ─
PART_BASE  = 1;
PART_LID   = 2;
PART_PLATE = 3;

// ── Parameters ────────────────────────────────────────────────────
plate_w = 60;
plate_d = 40;
plate_t = 3;

base_w = 50;
base_h = 25;
base_t = 4;

lid_w = base_w;
lid_h = 30;
lid_t = base_t;

hinge_r = 4;
hole_d  = 4;
hole_inset = 5;

// ── Per-part visibility defaults (overridable from qa.scad / PARTS=) ─
viz_show_part_1 = true;  // base
viz_show_part_2 = true;  // lid
viz_show_part_3 = true;  // plate

// REPL-exposed variables (declared here as defaults; qa.scad overrides).
lid_angle = 0;          // degrees, 0 = closed

// ── Primitive parts ───────────────────────────────────────────────
module base_part() {
  difference() {
    union() {
      // Wall
      translate([-base_w/2, 0, 0]) cube([base_w, base_t, base_h]);
      // Hinge knuckle along +Y top edge
      translate([-base_w/2, base_t/2, base_h])
        rotate([0, 90, 0]) cylinder(r=hinge_r, h=base_w);
    }
    // Mounting holes through wall
    for (x = [-base_w/2 + hole_inset, base_w/2 - hole_inset])
      translate([x, base_t + 0.1, hole_inset])
        rotate([90, 0, 0]) cylinder(d=hole_d, h=base_t + 0.5);
  }
}

module lid_part() {
  // Origin at the hinge axis; rotate around X by lid_angle.
  difference() {
    union() {
      translate([-lid_w/2, -lid_t/2, 0]) cube([lid_w, lid_t, lid_h]);
      // Hinge knuckle (will mate with base knuckle in assembly)
      translate([-lid_w/2, 0, 0]) rotate([0, 90, 0])
        cylinder(r=hinge_r * 0.98, h=lid_w);
    }
    for (x = [-lid_w/2 + hole_inset, lid_w/2 - hole_inset])
      translate([x, 0, lid_h - hole_inset])
        rotate([90, 0, 0]) cylinder(d=hole_d, h=lid_t + 0.5, center=true);
  }
}

module plate_part() {
  difference() {
    translate([-plate_w/2, -plate_d/2, 0]) cube([plate_w, plate_d, plate_t]);
    for (x = [-plate_w/2 + hole_inset, plate_w/2 - hole_inset])
      for (y = [-plate_d/2 + hole_inset, plate_d/2 - hole_inset])
        translate([x, y, -0.1]) cylinder(d=hole_d, h=plate_t + 0.5);
  }
}

// ── Assembly: parts shown together with hinge angle and explosion offset ─
module assembly(explode = 0) {
  // Plate sits flat on Z=0
  if (viz_show_part_3) plate_part();
  // Base wall stands at front edge of plate
  if (viz_show_part_1)
    translate([0, -plate_d/2, plate_t + explode]) base_part();
  // Lid pivots from base hinge axis
  if (viz_show_part_2)
    translate([0, -plate_d/2 + base_t/2, plate_t + base_h + explode * 1.5])
      rotate([lid_angle, 0, 0])
        lid_part();
}

// ── Mode dispatch ─────────────────────────────────────────────────
if (mode == SHOW_ASSEMBLY)         assembly(0);
else if (mode == SHOW_EXPLODED)    assembly(15);
else if (mode == PRINT_BASE)       base_part();
else if (mode == PRINT_LID)        lid_part();
else if (mode == PRINT_PLATE)      plate_part();
else assert(false, str("Unknown mode: ", mode));
