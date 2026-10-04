// ============================================================
// HELTEC WiFi LoRa 32 V4  (ESP32-S3 + SX1262, 0.96" OLED)
// ============================================================
// Source: Heltec WiFi LoRa 32 V4.2.0 datasheet: 51.7 x 25.4 x 10.7mm.
// The board has no mounting holes. Hold it by its edges (slide-in C-channel
// rails) or by its headers in a socket. heltec_v4_rail_slot() gives the slot
// a rail has to cut.
//
// OLED and header positions are a representative silhouette; outline,
// thickness and overall height are from the datasheet.
//
// Board-local frame:
//   origin = PCB underside, corner at the USB-C end
//   +X along the 51.7mm edge (USB-C at X = 0), +Y along 25.4mm
//   +Z = OLED side. Header pins hang below the PCB.
// ============================================================

use <common.scad>

heltec_v4_size       = [51.7, 25.4, 1.6];   // PCB
heltec_v4_height     = 10.7;                // PCB underside to OLED top
heltec_v4_pins_below = 5.0;                 // header pins under the PCB
heltec_v4_oled_view  = [22.0, 11.0];        // 0.96" active area
heltec_v4_usbc_body  = [7.3, 9.0, 3.2];     // depth into board, width, height
heltec_v4_usbc_overhang = 1.0;
heltec_v4_ufl_pos    = [heltec_v4_size[0] - 4, 12.7];   // LoRa antenna U.FL

module heltec_v4(alpha = undef, pins = true) {
    _t = heltec_v4_size[2];
    _sx = heltec_v4_size[0];
    _sy = heltec_v4_size[1];

    color(comp_rgba([0.95, 0.20, 0.15, 0.95], alpha)) cube(heltec_v4_size);

    // OLED module: carrier, glass, and the active area that faces up
    color(comp_color("plastic", alpha))
    translate([12, 1.5, _t]) cube([30, _sy - 3, heltec_v4_height - _t - 0.8]);
    color(comp_color("glass", alpha))
    translate([12 + (30 - heltec_v4_oled_view[0]) / 2 + 2, (_sy - heltec_v4_oled_view[1]) / 2,
               heltec_v4_height - 0.8])
    cube([heltec_v4_oled_view[0], heltec_v4_oled_view[1], 0.8]);

    color(comp_color("shield", alpha))
    translate([-heltec_v4_usbc_overhang, _sy / 2 - heltec_v4_usbc_body[1] / 2, _t])
    cube(heltec_v4_usbc_body);

    color(comp_color("shield", alpha))
    translate([heltec_v4_ufl_pos[0], heltec_v4_ufl_pos[1], _t])
    cylinder(d = 3.0, h = 1.8, $fn = 16);

    if (pins)
        color(comp_color("brass", alpha))
        for (y = [1.27, _sy - 1.27])
            translate([(_sx - 17 * 2.54) / 2, y, -heltec_v4_pins_below])
            comp_pin_row(18, h = heltec_v4_pins_below);
}

module heltec_v4_envelope(pins = true) {
    _below = pins ? heltec_v4_pins_below : 0;
    translate([-heltec_v4_usbc_overhang, 0, -_below])
    cube([heltec_v4_size[0] + heltec_v4_usbc_overhang, heltec_v4_size[1], heltec_v4_height + _below]);
}

// The groove a slide-in rail needs along one long edge: board thickness plus
// clearance, `grip` deep into the board margin. Mirror it for the other edge.
module heltec_v4_rail_slot(grip = 1.0, clearance = 0.15) {
    translate([-1, -clearance, -clearance])
    cube([heltec_v4_size[0] + 2, grip + clearance, heltec_v4_size[2] + 2 * clearance]);
}

module heltec_v4_usbc_cutout(clearance = 0.5, depth = 10) {
    translate([-heltec_v4_usbc_overhang - depth,
               heltec_v4_size[1] / 2 - heltec_v4_usbc_body[1] / 2 - clearance,
               heltec_v4_size[2] - clearance])
    cube([depth + 0.01, heltec_v4_usbc_body[1] + 2 * clearance, heltec_v4_usbc_body[2] + 2 * clearance]);
}
