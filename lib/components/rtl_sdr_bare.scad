// ============================================================
// RTL-SDR BLOG DONGLE, BARE PCB  (case off, USB-A plug desoldered)
// ============================================================
// For mounting the SDR inside an enclosure: the aluminium shell comes off,
// the USB-A plug is desoldered, and a 4-wire cable lands on its pads.
//
// Hole spacing is caliper-measured. The PCB outline is APPROXIMATE, taken
// from teardown photos, so do not size a tight pocket off it.
// The assembled dongle (shell on) is 85mm long.
//
// Board-local frame:
//   origin = PCB underside, corner at the USB pad end
//   +X along the 25mm width, +Y along the 67mm length
//   USB pads at Y = 0, SMA jack at Y = 67.
// ============================================================

use <common.scad>

rtlsdr_pcb_size     = [25.0, 67.0, 1.6];   // approximate outline
rtlsdr_hole_d       = 2.5;
rtlsdr_hole_span    = [15.5, 62.0];        // measured, centre to centre
rtlsdr_holes = [for (dx = [-1, 1], dy = [0, 1])
    [rtlsdr_pcb_size[0] / 2 + dx * rtlsdr_hole_span[0] / 2,
     (rtlsdr_pcb_size[1] - rtlsdr_hole_span[1]) / 2 + dy * rtlsdr_hole_span[1]]];
rtlsdr_sma_d        = 8.5;                 // across the hex nut, plus clearance
rtlsdr_sma_x        = 12.5;
rtlsdr_sma_len      = 8.0;                 // barrel beyond the PCB edge
rtlsdr_height       = 9.0;                 // PCB underside to top of the SMA barrel
rtlsdr_dongle_length = 85.0;               // assembled, shell on

module rtlsdr_at_holes() { comp_at(rtlsdr_holes) children(); }

module rtlsdr_bare(alpha = undef) {
    _t = rtlsdr_pcb_size[2];
    difference() {
        color(comp_rgba([0.75, 0.45, 0.18, 0.90], alpha)) cube(rtlsdr_pcb_size);
        rtlsdr_at_holes() translate([0, 0, -1]) cylinder(d = rtlsdr_hole_d, h = _t + 2, $fn = 16);
    }

    // SMA jack on the RF end
    color(comp_color("shield", alpha))
    translate([rtlsdr_sma_x, rtlsdr_pcb_size[1] - 2, _t + rtlsdr_sma_d / 2 - 0.5])
    rotate([-90, 0, 0])
    cylinder(d = rtlsdr_sma_d, h = rtlsdr_sma_len + 2, $fn = 6);

    // Tuner and RTL2832U cans
    color(comp_color("shield", alpha))
    for (cy = [rtlsdr_pcb_size[1] * 0.34, rtlsdr_pcb_size[1] * 0.6])
        translate([rtlsdr_pcb_size[0] / 2 - 7, cy - 6, _t])
        cube([14, 12, 1.8]);

    // USB pads where the plug used to be
    color(comp_color("brass", alpha))
    for (dx = [-4.5, -1.5, 1.5, 4.5])
        translate([rtlsdr_pcb_size[0] / 2 + dx - 0.6, 0.5, _t])
        cube([1.2, 5, 0.1]);
}

module rtlsdr_envelope() {
    cube([rtlsdr_pcb_size[0], rtlsdr_pcb_size[1] + rtlsdr_sma_len, rtlsdr_height]);
}

// Hole for the SMA barrel through an end wall past Y = 67.
module rtlsdr_sma_cutout(clearance = 0.4, depth = 10) {
    translate([rtlsdr_sma_x, rtlsdr_pcb_size[1], rtlsdr_pcb_size[2] + rtlsdr_sma_d / 2 - 0.5])
    rotate([-90, 0, 0])
    cylinder(d = rtlsdr_sma_d + 2 * clearance, h = depth, $fn = 32);
}
