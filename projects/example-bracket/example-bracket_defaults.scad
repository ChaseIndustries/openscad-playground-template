// Defaults for everything example-bracket_qa.scad may override: part visibility,
// preview settings and REPL variables. They live in their own include
// because OpenSCAD only lets a later include override an earlier one
// silently. Assigned in the entry SCAD, they either beat the QA file or
// earn a warning per variable.

// ── Per-part visibility defaults (overridable from qa.scad / PARTS=) ─
viz_show_part_1 = true;  // base
viz_show_part_2 = true;  // lid
viz_show_part_3 = true;  // plate

// REPL-exposed variables (qa.scad overrides).
lid_angle = 0;          // degrees, 0 = closed
