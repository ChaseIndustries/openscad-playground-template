// ============================================================
// CHERRY MX STYLE SWITCH + KEYCAP GHOST, PLATE CUTOUT
// ============================================================
// Frame: origin = centre of the switch on the plate's TOP face. The
// switch body hangs below the plate, the keycap sits above it.
// ============================================================

use <common.scad>

mx_pitch        = 19.05;
mx_cutout       = 14.0;    // plate hole, square
mx_plate_t      = 1.5;     // the clip-in plate thickness MX latches expect
mx_below_plate  = 5.0;     // housing under the plate, pins excluded
mx_pins_below   = 3.3;     // below the housing
mx_keycap       = [18.0, 18.0, 8.0];   // 1u, generic profile
mx_cap_lift     = 6.6;     // plate top to keycap underside, switch released

module mx_switch(alpha = undef, keycap = true, units = 1) {
    color(comp_color("plastic", alpha)) {
        translate([-mx_cutout / 2, -mx_cutout / 2, -mx_plate_t - mx_below_plate])
        cube([mx_cutout, mx_cutout, mx_below_plate + mx_plate_t]);
        translate([-7.5, -7.5, 0]) cube([15, 15, 5.0]);
    }
    color(comp_color("brass", alpha))
    for (p = [[-3.81, 2.54], [2.54, 5.08]])
        translate([p[0], p[1], -mx_plate_t - mx_below_plate - mx_pins_below])
        cylinder(d = 1.5, h = mx_pins_below, $fn = 8);
    if (keycap) {
        _w = (units - 1) * mx_pitch + mx_keycap[0];
        color(comp_color("keycap", alpha))
        translate([-_w / 2, -mx_keycap[1] / 2, mx_cap_lift])
        cube([_w, mx_keycap[1], mx_keycap[2]]);
    }
}

module mx_plate_cutout(plate_t = mx_plate_t, clearance = 0) {
    translate([-mx_cutout / 2 - clearance, -mx_cutout / 2 - clearance, -plate_t - 0.5])
    cube([mx_cutout + 2 * clearance, mx_cutout + 2 * clearance, plate_t + 1]);
}

// Grid of cutouts on the MX pitch, first switch centred on the origin.
module mx_plate_grid(cols, rows, plate_t = mx_plate_t) {
    for (c = [0 : cols - 1], r = [0 : rows - 1])
        translate([c * mx_pitch, r * mx_pitch, 0]) mx_plate_cutout(plate_t);
}
