// ============================================================
// POWER MODULES: TP4056 charger, 5V boost, SRD-05VDC relay, USB-C PD breakout
// ============================================================
// Module bodies are caliper measured. Top-side details (USB shell, inductor,
// output cap) are representative silhouettes so each board reads on sight,
// not positions to design against.
//
// Every board here uses the same frame:
//   origin = PCB underside, -X/-Y corner, +Z = component side
//   long axis along +X
// ============================================================

use <common.scad>

// ------------------------------------------------------------
// TP4056 LiPo charger with protection (DW01 + 8205A). USB-C on the X = 0
// end. Ignore the connector overhang and the ~1.5mm pad bumps on the other
// end when fitting a pocket; tp4056_size is the PCB.
// ------------------------------------------------------------
tp4056_size   = [26.0, 17.0, 1.6];
tp4056_height = 5.0;    // to the top of the USB-C shell
tp4056_usbc_overhang = 0.8;

module tp4056(alpha = undef) {
    _t = tp4056_size[2];
    color(comp_color("blue", alpha)) cube(tp4056_size);
    color(comp_color("shield", alpha))
    translate([-tp4056_usbc_overhang, tp4056_size[1] / 2 - 4.5, _t]) cube([7.4, 9.0, 3.2]);
    color(comp_color("dark", alpha)) {
        translate([11, tp4056_size[1] / 2 - 2.5, _t]) cube([5, 5, 1.2]);     // TP4056
        translate([18, 3, _t]) cube([3, 3, 1.0]);                            // DW01
        translate([18, tp4056_size[1] - 6, _t]) cube([3, 3, 1.0]);           // 8205A
    }
    // B+ / B- / OUT+ / OUT- pads on the far end
    color(comp_color("brass", alpha))
    for (y = [2.5, 6.5, tp4056_size[1] - 6.5, tp4056_size[1] - 2.5])
        translate([tp4056_size[0] - 2, y, _t]) cylinder(d = 2.0, h = 0.1, $fn = 12);
}

module tp4056_envelope() {
    translate([-tp4056_usbc_overhang, 0, 0])
    cube([tp4056_size[0] + tp4056_usbc_overhang, tp4056_size[1], tp4056_height]);
}

// ------------------------------------------------------------
// Generic 3.7V -> 5V boost converter board (inductor + output cap class).
// ------------------------------------------------------------
boost5v_size   = [22.5, 11.0, 1.6];
boost5v_height = 7.6;   // to the top of the output can

module boost5v(alpha = undef) {
    _t = boost5v_size[2];
    color(comp_color("blue", alpha)) cube(boost5v_size);
    color(comp_color("dark", alpha))
    translate([boost5v_size[0] / 2 - 5, boost5v_size[1] / 2, _t]) cylinder(d = 7.0, h = 4.2, $fn = 24);
    color(comp_color("shield", alpha))
    translate([boost5v_size[0] / 2 + 5.5, boost5v_size[1] / 2, _t]) cylinder(d = 6.3, h = 6.0, $fn = 24);
}

module boost5v_envelope() { cube([boost5v_size[0], boost5v_size[1], boost5v_height]); }

// ------------------------------------------------------------
// 5V single-channel relay module (SRD-05VDC can). Screw terminals
// COM/NO/NC at the X = 0 end, VCC/GND/IN header at the far end.
// Four M3 corner holes; through-hole tails hang 3mm under the PCB.
// ------------------------------------------------------------
relay_size        = [50.0, 26.5, 1.6];
relay_body_h      = 17.0;   // above the PCB top
relay_pins_below  = 3.0;
relay_hole_d      = 4.0;
relay_hole_span   = [44.0, 21.0];
relay_holes       = comp_rect_holes(relay_size,
                        [(relay_size[0] - relay_hole_span[0]) / 2,
                         (relay_size[1] - relay_hole_span[1]) / 2]);

module relay_at_holes() { comp_at(relay_holes) children(); }

module relay_srd05(alpha = undef) {
    _t = relay_size[2];
    _cy = relay_size[1] / 2;
    difference() {
        color(comp_color("blue", alpha)) cube(relay_size);
        relay_at_holes() translate([0, 0, -1]) cylinder(d = relay_hole_d, h = _t + 2, $fn = 20);
    }
    color(comp_color("dark", alpha))
    translate([relay_size[0] / 2 - 9.5, _cy - 7.5, _t]) cube([19, 15, 15]);

    color(comp_color("bone", alpha)) translate([1.5, _cy - 7.5, _t]) cube([11, 15, 10]);
    color(comp_color("brass", alpha))
    for (dy = [-5, 0, 5]) translate([7, _cy + dy, _t + 9.6]) cylinder(d = 3.2, h = 1.0, $fn = 14);

    color(comp_color("plastic", alpha))
    translate([relay_size[0] - 5, _cy - 3.8, _t]) cube([2.6, 7.6, 2.5]);
    color(comp_color("brass", alpha))
    translate([relay_size[0] - 3.7, _cy - 2.54, _t]) rotate([0, 0, 90]) comp_pin_row(3, h = 8.5);
}

module relay_envelope() {
    translate([0, 0, -relay_pins_below])
    cube([relay_size[0], relay_size[1], relay_pins_below + relay_size[2] + relay_body_h]);
}

// ------------------------------------------------------------
// USB-C PD breakout, 22 x 13mm. Receptacle on one 22mm edge (X along that
// edge, receptacle at Y = 13), solder pads along the opposite edge. The
// connector is edge-mounted, so the board has to lie flat behind its port
// hole: a 10 x 4 slot only accepts it one way.
// ------------------------------------------------------------
usbc_pd_size      = [22.0, 13.0, 1.6];
usbc_pd_recept    = [8.9, 7.0, 3.2];   // width, depth onto board, height
usbc_pd_port_hole = [10.0, 4.0];       // panel opening for the plug

module usbc_pd_breakout(alpha = undef) {
    _t = usbc_pd_size[2];
    color(comp_color("pcb", alpha)) cube(usbc_pd_size);
    color(comp_color("shield", alpha))
    translate([(usbc_pd_size[0] - usbc_pd_recept[0]) / 2, usbc_pd_size[1] - usbc_pd_recept[1], _t])
    cube(usbc_pd_recept);
    color(comp_color("brass", alpha))
    for (i = [0 : 5])
        translate([(usbc_pd_size[0] - 15) / 2 + i * 3, 1.2, _t]) cylinder(d = 1.6, h = 0.1, $fn = 12);
}

module usbc_pd_envelope() {
    cube([usbc_pd_size[0], usbc_pd_size[1], usbc_pd_size[2] + usbc_pd_recept[2]]);
}

// Rounded-slot port hole for a wall at Y = 13, centred on the receptacle.
module usbc_pd_port_cutout(depth = 10) {
    _r = usbc_pd_port_hole[1] / 2;
    translate([usbc_pd_size[0] / 2, usbc_pd_size[1], usbc_pd_size[2] + usbc_pd_recept[2] / 2])
    rotate([-90, 0, 0])
    linear_extrude(depth)
    hull() for (dx = [-1, 1]) translate([dx * (usbc_pd_port_hole[0] / 2 - _r), 0]) circle(r = _r, $fn = 24);
}
