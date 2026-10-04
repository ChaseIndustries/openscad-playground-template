// ============================================================
// RASPBERRY PI 5  (+ Active Cooler, AI HAT+ 2)
// ============================================================
// Source: RP-008348 Raspberry Pi 5 product brief, p.4 physical drawing.
// Port positions and holes are from that drawing. Port BODY sizes are
// approximate silhouettes (the drawing gives centres, not shells), so keep
// the clearance argument on the cutout modules when cutting a panel.
//
// Board-local frame:
//   origin = PCB underside, corner nearest the USB-C port
//   +X along the 85mm edge, +Y along the 56mm edge, +Z = component side
//   Y = 0 edge: USB-C, micro-HDMI 0, micro-HDMI 1   (the "power edge")
//   X = 85 edge: Ethernet, USB-A pair, USB-A pair   (the "IO edge")
//   Y = 56 edge: 40-pin GPIO header
// ============================================================

use <common.scad>

rpi5_size        = [85.0, 56.0, 1.6];   // PCB
rpi5_height      = 17.0;                // PCB underside to top of the USB-A stack
rpi5_hole_d      = 2.7;                 // M2.5 clearance
rpi5_holes       = [[3.5, 3.5], [3.5, 52.5], [61.5, 3.5], [61.5, 52.5]];

// Power edge (Y = 0). Centres along X.
rpi5_usbc_x      = 11.2;
rpi5_usbc_body   = [9.0, 7.5, 3.2];     // width along edge, depth into board, height
rpi5_hdmi_x      = [25.8, 39.2];
rpi5_hdmi_body   = [7.5, 7.0, 3.6];
rpi5_power_edge_overhang = 1.0;         // shells stand proud of the board edge

// IO edge (X = 85). Centres along Y.
rpi5_eth_y       = 10.2;
rpi5_eth_body    = [21.0, 16.0, 13.5];  // depth into board, width along edge, height
rpi5_usba_y      = [29.1, 47.0];
rpi5_usba_body   = [17.5, 14.5, 16.0];  // each double-stack
rpi5_io_edge_overhang = 3.0;            // from the drawing's side view

// 2x20 GPIO header. Centred 29mm from the left hole line per the drawing.
rpi5_gpio_center = [32.5, 52.5];
rpi5_gpio_len    = 20 * 2.54;
rpi5_gpio_h      = 8.5;                 // pin tips above the PCB top face

module rpi5_at_holes() { comp_at(rpi5_holes) children(); }

module rpi5(alpha = undef) {
    _t = rpi5_size[2];

    difference() {
        color(comp_color("pcb", alpha)) cube(rpi5_size);
        rpi5_at_holes() translate([0, 0, -1]) cylinder(d = rpi5_hole_d, h = _t + 2, $fn = 20);
    }

    // Power edge
    color(comp_color("shield", alpha)) {
        translate([rpi5_usbc_x - rpi5_usbc_body[0] / 2, -rpi5_power_edge_overhang, _t])
        cube([rpi5_usbc_body[0], rpi5_usbc_body[1], rpi5_usbc_body[2]]);
        for (x = rpi5_hdmi_x)
            translate([x - rpi5_hdmi_body[0] / 2, -rpi5_power_edge_overhang, _t])
            cube([rpi5_hdmi_body[0], rpi5_hdmi_body[1], rpi5_hdmi_body[2]]);
    }

    // IO edge
    _ox = rpi5_size[0] + rpi5_io_edge_overhang;
    color(comp_color("shield", alpha)) {
        translate([_ox - rpi5_eth_body[0], rpi5_eth_y - rpi5_eth_body[1] / 2, _t])
        cube(rpi5_eth_body);
        for (y = rpi5_usba_y)
            translate([_ox - rpi5_usba_body[0], y - rpi5_usba_body[1] / 2, _t])
            cube(rpi5_usba_body);
    }
    color(comp_color("dark", alpha)) {
        translate([_ox - 0.6, rpi5_eth_y - rpi5_eth_body[1] / 2 + 1.5, _t + 1.5])
        cube([1, rpi5_eth_body[1] - 3, rpi5_eth_body[2] - 3]);
        for (y = rpi5_usba_y, dz = [1.4, 1.4 + rpi5_usba_body[2] / 2])
            translate([_ox - 0.6, y - rpi5_usba_body[1] / 2 + 1.5, _t + dz])
            cube([1, rpi5_usba_body[1] - 3, rpi5_usba_body[2] / 2 - 2.8]);
    }

    // GPIO header: insulator plus the two pin rows
    translate([rpi5_gpio_center[0] - rpi5_gpio_len / 2, rpi5_gpio_center[1], _t]) {
        color(comp_color("plastic", alpha))
        translate([0, -2.54, 0]) cube([rpi5_gpio_len, 5.08, 2.5]);
        color(comp_color("brass", alpha))
        for (dy = [-1.27, 1.27])
            translate([1.27, dy, 0]) comp_pin_row(20, h = rpi5_gpio_h);
    }

    // SoC, RP1 and RAM, so the board reads as a Pi from above
    color(comp_color("dark", alpha)) {
        translate([28, 19, _t]) cube([15, 15, 1.4]);
        translate([47, 24, _t]) cube([10, 10, 1.0]);
        translate([28, 36, _t]) cube([14, 10, 1.0]);
    }
}

// Worst-case keep-out block for overlap checks. Plain on purpose: detailing
// it would shrink the volume a clearance check is asserting on.
module rpi5_envelope() {
    translate([0, -rpi5_power_edge_overhang, 0])
    cube([rpi5_size[0] + rpi5_io_edge_overhang,
          rpi5_size[1] + rpi5_power_edge_overhang,
          rpi5_height]);
}

// Panel cutters for the two port edges, in board-local coords. Each opening
// is the port shell plus `clearance` per side, run `depth` outward from the
// shell face. Place them with the same transform as the board.
module rpi5_power_edge_cutouts(clearance = 0.5, depth = 10) {
    _t = rpi5_size[2];
    _y = -rpi5_power_edge_overhang - depth;
    translate([rpi5_usbc_x - rpi5_usbc_body[0] / 2 - clearance, _y, _t - clearance])
    cube([rpi5_usbc_body[0] + 2 * clearance, depth + 0.01, rpi5_usbc_body[2] + 2 * clearance]);
    for (x = rpi5_hdmi_x)
        translate([x - rpi5_hdmi_body[0] / 2 - clearance, _y, _t - clearance])
        cube([rpi5_hdmi_body[0] + 2 * clearance, depth + 0.01, rpi5_hdmi_body[2] + 2 * clearance]);
}

module rpi5_io_edge_cutouts(clearance = 0.5, depth = 10) {
    _t = rpi5_size[2];
    _x = rpi5_size[0] + rpi5_io_edge_overhang - 0.01;
    translate([_x, rpi5_eth_y - rpi5_eth_body[1] / 2 - clearance, _t - clearance])
    cube([depth, rpi5_eth_body[1] + 2 * clearance, rpi5_eth_body[2] + 2 * clearance]);
    for (y = rpi5_usba_y)
        translate([_x, y - rpi5_usba_body[1] / 2 - clearance, _t - clearance])
        cube([depth, rpi5_usba_body[1] + 2 * clearance, rpi5_usba_body[2] + 2 * clearance]);
}

// ------------------------------------------------------------
// Official Active Cooler. Heatsink block with the 30mm fan on top, centred
// for the silhouette (the real fan sits off to one side). Same board-local
// frame as rpi5(); call it at z = rpi5_size[2].
// ------------------------------------------------------------
rpi5_cooler_size  = [72.0, 46.0, 14.0];   // X, Y, height above the Pi PCB top
rpi5_cooler_fan_d = 30.0;

module rpi5_active_cooler(alpha = undef) {
    _x = (rpi5_size[0] - rpi5_cooler_size[0]) / 2;
    _y = (rpi5_size[1] - rpi5_cooler_size[1]) / 2;
    color(comp_color("cooler", alpha))
    translate([_x, _y, 0])
    cube([rpi5_cooler_size[0], rpi5_cooler_size[1], rpi5_cooler_size[2] - 3]);
    color(comp_color("dark", alpha))
    translate([_x + rpi5_cooler_size[0] / 2, _y + rpi5_cooler_size[1] / 2, rpi5_cooler_size[2] - 3])
    cylinder(d = rpi5_cooler_fan_d, h = 3, $fn = 32);
}

// ------------------------------------------------------------
// AI HAT+ 2 (Hailo-10H). HAT+ form factor: 65 x 56.5, holes match the Pi's
// left four. Height includes the bundled heatsink pad over the Hailo module.
// ------------------------------------------------------------
rpi_ai_hat2_size   = [65.0, 56.5, 1.6];
rpi_ai_hat2_height = 12.0;   // PCB underside to heatsink top
// Pi PCB top to HAT PCB underside with a 16mm stacking header, which is what
// it takes to fit the Active Cooler underneath. Measured on a real stack.
rpi_ai_hat2_gap_over_cooler = 14.0;

module rpi_ai_hat2(alpha = undef) {
    _t = rpi_ai_hat2_size[2];
    difference() {
        color(comp_rgba([0.45, 0.18, 0.50, 0.90], alpha))
        cube(rpi_ai_hat2_size);
        rpi5_at_holes() translate([0, 0, -1]) cylinder(d = rpi5_hole_d, h = _t + 2, $fn = 20);
    }
    color(comp_color("cooler", alpha))
    translate([rpi_ai_hat2_size[0] / 2 - 16, rpi_ai_hat2_size[1] / 2 - 14, _t])
    cube([32, 28, rpi_ai_hat2_height - _t]);
    // Stacking socket hanging under the board onto the Pi header
    color(comp_color("plastic", alpha))
    translate([rpi5_gpio_center[0] - rpi5_gpio_len / 2, rpi5_gpio_center[1] - 2.54, -8.5])
    cube([rpi5_gpio_len, 5.08, 8.5]);
}

// Pi 5 + Active Cooler + AI HAT+ 2, in the Pi's board-local frame.
module rpi5_ai_stack(alpha = undef, cooler = true, hat = true) {
    rpi5(alpha);
    if (cooler) translate([0, 0, rpi5_size[2]]) rpi5_active_cooler(alpha);
    if (hat) translate([0, 0, rpi5_size[2] + rpi_ai_hat2_gap_over_cooler]) rpi_ai_hat2(alpha);
}
