// ============================================================
// RASPBERRY PI PICO / PICO W / PICO 2 / PICO 2 W
// ============================================================
// Source: Raspberry Pi Pico datasheet mechanical drawing. All four boards
// share the outline, holes and pinout. Every Pico through Pico 2 W has a
// micro-USB B port, not USB-C.
//
// Board-local frame:
//   origin = PCB underside, corner at the USB end
//   +X along the 51mm edge (USB at X = 0), +Y along the 21mm edge
//   +Z = component side. Castellated pin rows run down both long edges.
// ============================================================

use <common.scad>

pico_size      = [51.0, 21.0, 1.0];   // PCB
pico_height    = 3.9;                 // PCB underside to top of the tallest part
pico_hole_d    = 2.1;
pico_holes     = [[2.0, 4.8], [2.0, 16.2], [49.0, 4.8], [49.0, 16.2]];
pico_pin_pitch = 2.54;
pico_pin_rows_y = [1.61, 19.39];      // 17.78 apart = 0.7" DIP spacing
pico_pin_x0    = 1.37;                // first pin centre from the USB end
pico_usb_body  = [5.6, 7.6, 2.7];     // depth into board, width, height (micro-B)
pico_usb_overhang = 1.3;

module pico_at_holes() { comp_at(pico_holes) children(); }

// headers: "none", "down" (pins under the board, e.g. into a socket) or "up".
// wireless: draws the RF can and antenna keep-out at the far end.
module pico(alpha = undef, headers = "none", wireless = true) {
    _t = pico_size[2];
    difference() {
        color(comp_rgba([0.15, 0.55, 0.30, 0.95], alpha)) cube(pico_size);
        pico_at_holes() translate([0, 0, -1]) cylinder(d = pico_hole_d, h = _t + 2, $fn = 16);
    }

    color(comp_color("shield", alpha))
    translate([-pico_usb_overhang, pico_size[1] / 2 - pico_usb_body[1] / 2, _t])
    cube(pico_usb_body);

    // RP2040 / RP2350
    color(comp_color("dark", alpha))
    translate([pico_size[0] / 2 - 6, pico_size[1] / 2 - 3.5, _t])
    cube([7, 7, 0.9]);

    if (wireless) {
        color(comp_color("shield", alpha))
        translate([pico_size[0] - 17, pico_size[1] / 2 - 5, _t])
        cube([10, 10, pico_height - _t]);
        color(comp_color("dark", alpha))
        translate([pico_size[0] - 4.5, pico_size[1] / 2 - 3, _t])
        cube([3.5, 6, 0.6]);
    }

    // Castellations
    color(comp_color("brass", alpha))
    for (y = pico_pin_rows_y, i = [0 : 19])
        translate([pico_pin_x0 + i * pico_pin_pitch, y, _t - 0.05])
        cylinder(d = 1.6, h = 0.1, $fn = 10);

    if (headers != "none") {
        _dn = headers == "down";
        color(comp_color("plastic", alpha))
        for (y = pico_pin_rows_y)
            translate([pico_pin_x0 - 1.27, y - 1.27, _dn ? -2.5 : _t])
            cube([20 * pico_pin_pitch, 2.54, 2.5]);
        color(comp_color("brass", alpha))
        for (y = pico_pin_rows_y)
            translate([pico_pin_x0, y, _dn ? -8.5 : _t])
            comp_pin_row(20, h = 8.5);
    }
}

module pico_envelope(headers = "none") {
    _below = headers == "down" ? 8.5 : 0;
    _above = headers == "up" ? 8.5 + pico_size[2] : pico_height;
    translate([-pico_usb_overhang, 0, -_below])
    cube([pico_size[0] + pico_usb_overhang, pico_size[1], _below + _above]);
}

// Cutter for the micro-USB opening in an end wall at X = 0.
module pico_usb_cutout(clearance = 0.5, depth = 10) {
    translate([-pico_usb_overhang - depth,
               pico_size[1] / 2 - pico_usb_body[1] / 2 - clearance,
               pico_size[2] - clearance])
    cube([depth + 0.01, pico_usb_body[1] + 2 * clearance, pico_usb_body[2] + 2 * clearance]);
}
