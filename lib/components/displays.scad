// ============================================================
// DISPLAYS: 7" DSI panel (800x480, Hosyond class)  +  3.12" SSD1322 OLED
// ============================================================
// Both use the same frame:
//   origin = rear of the module, -X/-Y corner of the PCB outline
//   +Z = toward the viewer, glass face at z = *_thickness
//   viewed from the front, +X is right and +Y is up
// ============================================================

use <common.scad>

// ------------------------------------------------------------
// 7" DSI module. Source: 7inch-DSI-Display User Manual V1.1, section 3
// dimensional drawing, with the PCB height confirmed at 102.0mm on a real
// panel. Bezels are asymmetric (measured: left 4, right ~7, top 4,
// bottom 8.5), so the viewing area is offset from the PCB centre. The
// offset below is for the panel with its FPC leaving the -X (left) edge;
// rotate the whole module 180 degrees if yours is mounted the other way.
// ------------------------------------------------------------
display7_pcb       = [164.89, 102.0];
display7_view      = [154.68, 87.02];
display7_view_offset = [-1.5, 2.25];      // view centre minus PCB centre
display7_thickness = 9.0;                 // body at the edge, bosses excluded
display7_boss_h    = 5.0;                 // threaded corner bosses behind the PCB
display7_hole_d    = 2.5;                 // M2.5 into those bosses
display7_holes     = comp_rect_holes(display7_pcb, [5.0, 5.04]);   // 154.89 x 91.92 pitch

function display7_view_origin() =
    [(display7_pcb[0] - display7_view[0]) / 2 + display7_view_offset[0],
     (display7_pcb[1] - display7_view[1]) / 2 + display7_view_offset[1]];

module display7_at_holes() { comp_at(display7_holes) children(); }

module display7(alpha = undef, bosses = true) {
    _v = display7_view_origin();
    color(comp_color("lcd", alpha))
    cube([display7_pcb[0], display7_pcb[1], display7_thickness - 0.5]);
    color(comp_color("plastic", alpha))
    translate([0, 0, display7_thickness - 0.5]) cube([display7_pcb[0], display7_pcb[1], 0.5]);
    color(comp_rgba([0.12, 0.85, 0.35, 0.95], alpha))
    translate([_v[0], _v[1], display7_thickness - 0.45]) cube([display7_view[0], display7_view[1], 0.5]);

    if (bosses)
        color(comp_color("shield", alpha))
        display7_at_holes()
        translate([0, 0, -display7_boss_h])
        difference() {
            cylinder(d = 5.0, h = display7_boss_h, $fn = 20);
            translate([0, 0, -0.1]) cylinder(d = display7_hole_d, h = display7_boss_h + 0.2, $fn = 16);
        }

    // FPC tail on the -X edge
    color(comp_rgba([0.85, 0.55, 0.15, 0.9], alpha))
    translate([-8, display7_pcb[1] / 2 - 8, 1]) cube([8, 16, 0.3]);
}

module display7_envelope(bosses = true) {
    _b = bosses ? display7_boss_h : 0;
    translate([0, 0, -_b]) cube([display7_pcb[0], display7_pcb[1], display7_thickness + _b]);
}

// Front-panel window over the viewing area, plus clearance per side.
module display7_window_cutout(clearance = 0.3, depth = 10) {
    _v = display7_view_origin();
    translate([_v[0] - clearance, _v[1] - clearance, display7_thickness - 0.01])
    cube([display7_view[0] + 2 * clearance, display7_view[1] + 2 * clearance, depth]);
}

// ------------------------------------------------------------
// 3.12" SSD1322 OLED, 256x64, on its breakout PCB. The viewing area is drawn
// centred on the PCB, which is how the source build seats it; check your
// board. The 2x8 header leaves the -X edge as a right-angle row, 6mm proud.
// No mounting holes were measured.
// ------------------------------------------------------------
oled312_pcb       = [100.5, 33.5];
oled312_view      = [78.78, 21.18];
oled312_thickness = 5.3;    // rearmost component to glass face
oled312_header_extends = 6.0;

module oled312(alpha = undef) {
    _vx = (oled312_pcb[0] - oled312_view[0]) / 2;
    _vy = (oled312_pcb[1] - oled312_view[1]) / 2;
    _pcb_z = oled312_thickness - 1.6 - 1.6;

    color(comp_rgba([0.30, 0.30, 0.38, 0.25], alpha)) cube([oled312_pcb[0], oled312_pcb[1], _pcb_z]);
    color(comp_rgba([0.15, 0.55, 0.25, 0.95], alpha))
    translate([0, 0, _pcb_z]) cube([oled312_pcb[0], oled312_pcb[1], 1.6]);
    color(comp_color("plastic", alpha))
    translate([_vx - 4, _vy - 3, _pcb_z + 1.6]) cube([oled312_view[0] + 8, oled312_view[1] + 6, 1.6]);
    color(comp_rgba([0.95, 0.80, 0.10, 0.95], alpha))
    translate([_vx, _vy, oled312_thickness - 0.05]) cube([oled312_view[0], oled312_view[1], 0.1]);

    color(comp_color("brass", alpha))
    for (dz = [-1.27, 1.27])
        translate([-oled312_header_extends, (oled312_pcb[1] - 7 * 2.54) / 2, _pcb_z + 0.8 + dz])
        for (i = [0 : 7]) translate([0, i * 2.54, 0]) cube([oled312_header_extends, 0.64, 0.64]);
}

module oled312_envelope(header = true) {
    _h = header ? oled312_header_extends : 0;
    translate([-_h, 0, 0]) cube([oled312_pcb[0] + _h, oled312_pcb[1], oled312_thickness]);
}

module oled312_window_cutout(clearance = 0.3, depth = 10) {
    translate([(oled312_pcb[0] - oled312_view[0]) / 2 - clearance,
               (oled312_pcb[1] - oled312_view[1]) / 2 - clearance,
               oled312_thickness - 0.01])
    cube([oled312_view[0] + 2 * clearance, oled312_view[1] + 2 * clearance, depth]);
}
