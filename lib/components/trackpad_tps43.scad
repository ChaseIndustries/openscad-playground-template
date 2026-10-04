// ============================================================
// AZOTEQ TPS43-201A-S I2C TRACKPAD  +  0.5mm 6-PIN FPC BREAKOUT
// ============================================================
// Thin capacitive PCB. The top face is the touch side with adhesive backing;
// it needs a 0.5-1mm opaque non-conductive cover bonded to it. The whole
// outline is active, there is no border. A 6-pin 0.5mm ZIF on the solder
// side sits ~10mm from each edge of one corner, turned 45 degrees, with the
// ribbon leaving along the diagonal. Keep an FPC bend radius of 3mm or more.
//
// 3x 1mm holes in an asymmetric triangle for M1/M1.2 self-tappers, or skip
// them and use the adhesive.
//
// Open question carried over from the source build: the bare PCB measured
// 1.5mm with calipers, while the part number says 1.0mm. tps43_size uses
// the caliper reading.
//
// Pad frame: origin = PCB underside, -X/-Y corner. +X along 43.5, +Y along
// 40.5, +Z = touch face. Connector corner is (+X, +Y).
// ============================================================

use <common.scad>

tps43_size          = [43.5, 40.5, 1.5];
tps43_connector_z   = 2.0;     // ZIF body below the PCB, sets the Z envelope
tps43_hole_d        = 1.0;
tps43_holes         = [[6.0, 20.0], [37.5, 6.0], [37.5, 34.5]];
tps43_conn_inset    = 10.0;
tps43_conn_body     = [5.0, 9.0];   // across pins, along pins
tps43_conn_angle    = 45;

module tps43_at_holes() { comp_at(tps43_holes) children(); }

module tps43(alpha = undef) {
    difference() {
        color(comp_rgba([1.0, 0.42, 0.08, 0.95], alpha)) cube(tps43_size);
        tps43_at_holes() translate([0, 0, -1]) cylinder(d = tps43_hole_d, h = tps43_size[2] + 2, $fn = 12);
    }
    color(comp_color("dark", alpha))
    translate([tps43_size[0] - tps43_conn_inset, tps43_size[1] - tps43_conn_inset, -tps43_connector_z])
    rotate([0, 0, tps43_conn_angle])
    translate([-tps43_conn_body[0] / 2, -tps43_conn_body[1] / 2, 0])
    cube([tps43_conn_body[0], tps43_conn_body[1], tps43_connector_z]);
}

module tps43_envelope() {
    translate([0, 0, -tps43_connector_z])
    cube([tps43_size[0], tps43_size[1], tps43_size[2] + tps43_connector_z]);
}

// Rounded cover plate that bonds to the touch face. Centred on the origin,
// Z = 0..t. inset trims each side so the plate does not overhang the pad.
module tps43_cover(t = 0.8, inset = 0.5, r = 2.0) {
    linear_extrude(t)
    offset(r = r, $fn = 48)
    square([tps43_size[0] - 2 * inset - 2 * r, tps43_size[1] - 2 * inset - 2 * r], center = true);
}

// ------------------------------------------------------------
// 0.5mm 6-pin FPC to 0.1" DIP adapter. The ZIF takes the trackpad ribbon on
// the +X end; the DIP row breaks it out to Dupont wire. Outline and thickness
// are measured; where the DIP row sits on the board is a silhouette.
// Frame: origin = PCB underside, -X/-Y corner, +Z = ZIF side.
// ------------------------------------------------------------
fpc6_breakout_size = [26.5, 18.0, 1.5];
fpc6_pins          = 6;
fpc6_pitch         = 2.54;

module fpc6_breakout(alpha = undef) {
    _t = fpc6_breakout_size[2];
    _run = (fpc6_pins - 1) * fpc6_pitch;
    color(comp_color("perf", alpha)) cube(fpc6_breakout_size);
    color(comp_color("dark", alpha))
    translate([fpc6_breakout_size[0] - tps43_conn_body[0], (fpc6_breakout_size[1] - tps43_conn_body[1]) / 2, _t])
    cube([tps43_conn_body[0], tps43_conn_body[1], tps43_connector_z]);
    color(comp_color("brass", alpha))
    translate([3, (fpc6_breakout_size[1] - _run) / 2, -6]) rotate([0, 0, 90])
    comp_pin_row(fpc6_pins, h = 6 + _t + 2.5);
}
