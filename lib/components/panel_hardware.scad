// ============================================================
// PANEL HARDWARE: 5mm LED bezel, 16mm latching pushbutton, SMA bulkhead jack
// ============================================================
// All three share one frame, built around the panel they pass through:
//   origin = centre of the hole on the panel's OUTER face
//   +Z = out of the panel toward the user, -Z = into the enclosure
// So place the part with the panel's outer face at z = 0 and subtract
// *_cutout(panel_t) from the panel.
// ============================================================

use <common.scad>

// ------------------------------------------------------------
// 5mm LED in a chrome bezel (DaierTek class): 10mm front flange, 8.5mm
// barrel through the panel, 12mm deep behind it including the LED leads.
// ------------------------------------------------------------
led5_d          = 5.0;
led5_flange_d   = 10.0;
led5_flange_t   = 1.5;
led5_barrel_d   = 8.5;
led5_depth      = 12.0;   // behind the panel
led5_min_pitch  = 14.0;   // centre to centre, so the flanges and nuts clear

module led5_bezel(alpha = undef, lens = "led") {
    color(comp_color("shield", alpha)) {
        cylinder(d = led5_flange_d, h = led5_flange_t, $fn = 32);
        translate([0, 0, -led5_depth]) cylinder(d = led5_barrel_d, h = led5_depth, $fn = 32);
    }
    color(comp_color(lens, alpha))
    translate([0, 0, led5_flange_t]) {
        cylinder(d = led5_d, h = 1.5, $fn = 24);
        translate([0, 0, 1.5]) sphere(d = led5_d, $fn = 24);
    }
}

module led5_cutout(panel_t = 3, clearance = 0.2) {
    translate([0, 0, -panel_t - 0.5]) cylinder(d = led5_barrel_d + 2 * clearance, h = panel_t + 1, $fn = 48);
}

// ------------------------------------------------------------
// 16mm latching pushbutton (APIELE class): M16x1 thread, 21.6mm bezel,
// 33mm deep behind the panel including the solder tags.
// ------------------------------------------------------------
pushbutton16_thread_d = 16.0;
pushbutton16_bezel_d  = 21.6;
pushbutton16_depth    = 33.0;

module pushbutton16(alpha = undef) {
    color(comp_rgba([0.55, 0.42, 0.20, 0.95], alpha))
    translate([0, 0, -pushbutton16_depth])
    cylinder(d = pushbutton16_thread_d - 0.4, h = pushbutton16_depth, $fn = 48);
    color(comp_color("shield", alpha)) cylinder(d = pushbutton16_bezel_d, h = 1.5, $fn = 48);
    color(comp_color("led", alpha)) translate([0, 0, 1.5]) cylinder(d = pushbutton16_bezel_d - 7, h = 1.5, $fn = 48);
}

module pushbutton16_cutout(panel_t = 3, clearance = 0.3) {
    translate([0, 0, -panel_t - 0.5])
    cylinder(d = pushbutton16_thread_d + 2 * clearance, h = panel_t + 1, $fn = 64);
}

// ------------------------------------------------------------
// SMA female bulkhead jack, 1/4-36 thread. Catalogue nominals, not calipers:
// the part that matters inside is the flange, barrel and crimp ferrule
// hanging off the inner face once the nut is done up.
// ------------------------------------------------------------
sma_hole_d      = 6.5;
sma_flange_d    = 9.0;    // across the hex
sma_body_len    = 14.0;   // panel inner face to the end of the ferrule
sma_outside_len = 9.0;    // thread and nut on the outside

module sma_bulkhead(panel_t = 3, alpha = undef) {
    color(comp_color("shield", alpha)) {
        cylinder(d = sma_hole_d - 0.15, h = sma_outside_len, $fn = 24);
        cylinder(d = sma_flange_d, h = 2.5, $fn = 6);
        translate([0, 0, -panel_t - 2.5]) cylinder(d = sma_flange_d, h = 2.5, $fn = 6);
        translate([0, 0, -panel_t - (sma_body_len - 4)]) cylinder(d = sma_hole_d, h = sma_body_len - 4, $fn = 24);
    }
    color(comp_color("dark", alpha))
    translate([0, 0, -panel_t - sma_body_len]) cylinder(d = 3.6, h = 4, $fn = 16);
}

module sma_cutout(panel_t = 3, clearance = 0.15) {
    translate([0, 0, -panel_t - 0.5]) cylinder(d = sma_hole_d + 2 * clearance, h = panel_t + 1, $fn = 48);
}
