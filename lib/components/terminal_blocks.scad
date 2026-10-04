// ============================================================
// KERWINN DUAL-ROW BARRIER TERMINAL BLOCK  +  PERFBOARD
// ============================================================
// Barrier block measured on the 4-position sample: 54.5 x 22 x 16mm with
// cover, 8.5mm pitch, 4.5mm mounting hole 5mm in from each end. Longer
// counts extrapolate from the pitch. Dual row: each position lands two
// wires, so 4 positions give 8 landings.
//
// Block frame: origin = underside, -X/-Y corner. Length along +Y, width
// along +X (screw rows either side of the X centreline).
// ============================================================

use <common.scad>

kerwinn_width       = 22.0;
kerwinn_height      = 16.0;   // with cover
kerwinn_pitch       = 8.5;
kerwinn_4pos_length = 54.5;
kerwinn_hole_d      = 4.5;
kerwinn_hole_inset  = 5.0;    // hole centre from each end
function kerwinn_length(n) = kerwinn_4pos_length + (n - 4) * kerwinn_pitch;
function kerwinn_holes(n) = [[kerwinn_width / 2, kerwinn_hole_inset],
                             [kerwinn_width / 2, kerwinn_length(n) - kerwinn_hole_inset]];

module kerwinn_at_holes(positions = 4) { comp_at(kerwinn_holes(positions)) children(); }

// Every detail stays inside the measured envelope, so a clearance read off
// this ghost is still valid.
module kerwinn_block(positions = 4, alpha = undef) {
    _len    = kerwinn_length(positions);
    _fin_h  = 2.0;
    _fin_t  = 1.2;
    _deck_z = kerwinn_height - _fin_h;
    _row_dx = 5.5;
    _y0     = (_len - (positions - 1) * kerwinn_pitch) / 2;

    color(comp_color("bone", alpha)) difference() {
        union() {
            cube([kerwinn_width, _len, _deck_z]);
            for (i = [0 : positions])
                translate([0, _y0 + (i - 0.5) * kerwinn_pitch - _fin_t / 2, _deck_z])
                cube([kerwinn_width, _fin_t, _fin_h]);
        }
        kerwinn_at_holes(positions) translate([0, 0, -1]) cylinder(d = kerwinn_hole_d, h = kerwinn_height + 2, $fn = 20);
    }

    color(comp_color("brass", alpha))
    for (i = [0 : positions - 1], dx = [-_row_dx, _row_dx])
        translate([kerwinn_width / 2 + dx, _y0 + i * kerwinn_pitch, _deck_z - 0.4])
        cylinder(d = 3.6, h = 1.2, $fn = 16);
}

module kerwinn_envelope(positions = 4) { cube([kerwinn_width, kerwinn_length(positions), kerwinn_height]); }

// ------------------------------------------------------------
// Cut-to-size perfboard on the 0.1" grid. Size it in GRID SPACES, not holes:
// the outline falls on hole centres, so the cut runs through the outer row
// and the edges come out scalloped. Reading "21 holes" inclusively gives a
// board one grid unit short on both axes.
//
// Drill M3 mounting holes at 3.5mm, on an existing pad. A 4mm bit breaks into
// the four neighbouring pads. Never punch FR-4: it fractures, it does not shear.
// ------------------------------------------------------------
perfboard_grid = 2.54;
perfboard_t    = 1.6;
function perfboard_size(cols, rows) = [cols * perfboard_grid, rows * perfboard_grid, perfboard_t];
// Corner M3 holes `inset` grid units in from each edge, so each lands on a pad.
function perfboard_corner_holes(cols, rows, inset = 2) =
    comp_rect_holes(perfboard_size(cols, rows), inset * perfboard_grid);

module perfboard(cols, rows, alpha = undef, hole_inset = 2, hole_d = 3.4) {
    _s = perfboard_size(cols, rows);
    difference() {
        color(comp_color("perf", alpha)) cube(_s);
        comp_at(perfboard_corner_holes(cols, rows, hole_inset))
        translate([0, 0, -1]) cylinder(d = hole_d, h = perfboard_t + 2, $fn = 20);
    }
    // Pad grid, every hole a copper dot on the top face
    color(comp_color("brass", alpha))
    for (i = [1 : cols - 1], j = [1 : rows - 1])
        translate([i * perfboard_grid, j * perfboard_grid, perfboard_t])
        cylinder(d = 1.6, h = 0.05, $fn = 8);
}
