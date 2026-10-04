// component-gallery.scad — browse and QA the shared component library.
//
// Mode 0 lays every part out on one grid. Modes 1..22 show one part alone,
// in its own board-local frame, so the origin and axes are what you would
// build against. Mode 30 is a cutter check: a panel cut with every *_cutout
// module and the matching parts placed through it. Modes 40 and 41 hold our
// boards up against NopSCADlib's versions of the same parts.
//
// The library itself lives in lib/components/ at the workbench root, and
// NopSCADlib is a git submodule beside it in lib/NopSCADlib/.

include <component-gallery_qa.scad>;
include <../../lib/components/components.scad>;
include <../../lib/NopSCADlib/core.scad>;
include <../../lib/NopSCADlib/vitamins/pcbs.scad>;

$fn = 48;

// ── Mode constants ────────────────────────────────────────────────
SHOW_GALLERY      = 0;
SHOW_RPI5         = 1;
SHOW_RPI5_STACK   = 2;
SHOW_PICO         = 3;
SHOW_HELTEC_V4    = 4;
SHOW_RTLSDR       = 5;
SHOW_USB_HUB      = 6;
SHOW_TP4056       = 7;
SHOW_BOOST        = 8;
SHOW_RELAY        = 9;
SHOW_USBC_PD      = 10;
SHOW_KERWINN      = 11;
SHOW_PERFBOARD    = 12;
SHOW_TPS43        = 13;
SHOW_FPC6         = 14;
SHOW_DISPLAY7     = 15;
SHOW_OLED312      = 16;
SHOW_LED5         = 17;
SHOW_PUSHBUTTON16 = 18;
SHOW_SMA          = 19;
SHOW_LIPO         = 20;
SHOW_M2_SSD       = 21;
SHOW_MX_SWITCH    = 22;
SHOW_CUTTER_CHECK = 30;
SHOW_NOP_SIDE_BY_SIDE = 40;
SHOW_NOP_OVERLAY      = 41;

module gallery_part(m) {
    if      (m == SHOW_RPI5)         rpi5();
    else if (m == SHOW_RPI5_STACK)   rpi5_ai_stack();
    else if (m == SHOW_PICO)         pico(headers = "down");
    else if (m == SHOW_HELTEC_V4)    heltec_v4();
    else if (m == SHOW_RTLSDR)       rtlsdr_bare();
    else if (m == SHOW_USB_HUB)      usb_hub_fe11s();
    else if (m == SHOW_TP4056)       tp4056();
    else if (m == SHOW_BOOST)        boost5v();
    else if (m == SHOW_RELAY)        relay_srd05();
    else if (m == SHOW_USBC_PD)      usbc_pd_breakout();
    else if (m == SHOW_KERWINN)      kerwinn_block(4);
    else if (m == SHOW_PERFBOARD)    perfboard(21, 23);
    else if (m == SHOW_TPS43)        tps43();
    else if (m == SHOW_FPC6)         fpc6_breakout();
    else if (m == SHOW_DISPLAY7)     display7();
    else if (m == SHOW_OLED312)      oled312();
    else if (m == SHOW_LED5)         led5_bezel();
    else if (m == SHOW_PUSHBUTTON16) pushbutton16();
    else if (m == SHOW_SMA)          sma_bulkhead();
    else if (m == SHOW_LIPO)         lipo_pouch();
    else if (m == SHOW_M2_SSD)       m2_ssd(80);
    else if (m == SHOW_MX_SWITCH)    mx_switch();
}

// [mode, x, y] on a loose grid, big parts on the back row
gallery_layout = [
    [SHOW_DISPLAY7,     0,   190], [SHOW_RPI5_STACK, 190, 190], [SHOW_LIPO,     300, 190],
    [SHOW_OLED312,      0,   130], [SHOW_RPI5,       120, 120], [SHOW_RTLSDR,   230, 110],
    [SHOW_USB_HUB,    270,   120], [SHOW_RELAY,      350, 120],
    [SHOW_PICO,         0,    80], [SHOW_HELTEC_V4,   70,  80], [SHOW_TPS43,    140,  60],
    [SHOW_PERFBOARD,  200,    30], [SHOW_KERWINN,    270,  30], [SHOW_M2_SSD,   310,  60],
    [SHOW_TP4056,       0,    30], [SHOW_BOOST,       40,  30], [SHOW_USBC_PD,   75,  30],
    [SHOW_FPC6,       105,    20],
    [SHOW_LED5,        10,     0], [SHOW_PUSHBUTTON16, 40,  0], [SHOW_SMA,       75,   0],
    [SHOW_MX_SWITCH,  110,     0],
];

module gallery() {
    for (g = gallery_layout) translate([g[1], g[2], 0]) gallery_part(g[0]);
}

// Every cutter in use. The panel stands in the XZ plane like an enclosure
// wall; the Pi's IO edge points at it, and the panel parts go through it.
module cutter_check() {
    _wall_t = 3;
    // Pi IO edge against the wall's inner face (wall from y = 0 to y = _wall_t)
    _pi_x = -(rpi5_size[0] + rpi5_io_edge_overhang);
    rotate([0, 0, 90]) translate([_pi_x, -rpi5_size[1] / 2, 0]) rpi5();

    color([0.6, 0.6, 0.65, 0.6]) difference() {
        translate([-40, 0, -5]) cube([130, _wall_t, 40]);
        rotate([0, 0, 90]) translate([_pi_x, -rpi5_size[1] / 2, 0]) rpi5_io_edge_cutouts(depth = 20);
        for (p = [[45, 10], [60, 10]]) translate([p[0], _wall_t, p[1]]) rotate([-90, 0, 0]) led5_cutout(_wall_t);
        translate([75, _wall_t, 18]) rotate([-90, 0, 0]) pushbutton16_cutout(_wall_t);
        translate([45, _wall_t, 25]) rotate([-90, 0, 0]) sma_cutout(_wall_t);
    }
    for (p = [[45, 10], [60, 10]]) translate([p[0], _wall_t, p[1]]) rotate([-90, 0, 0]) led5_bezel();
    translate([75, _wall_t, 18]) rotate([-90, 0, 0]) pushbutton16();
    translate([45, _wall_t, 25]) rotate([-90, 0, 0]) sma_bulkhead(_wall_t);
}

// Ours beside NopSCADlib's, row by row. NopSCADlib has no Pi 5, so the Pi 4
// stands in: it shares the Pi 5's outline, holes and GPIO header, while its
// Ethernet and USB stacks sit the other way round on the IO edge.
// NopSCADlib's pcb() is centred on its outline, ours sits on a corner, so
// each of theirs is shifted by half its size to share our origin.
nop_pairs = [
    // [our mode, NopSCADlib type, row y]
    [SHOW_RPI5,   RPI4,     0],
    [SHOW_PICO,   RPI_Pico, 80],
    [SHOW_TP4056, TP4056,   120],
];

module nop_board(type) {
    translate([pcb_length(type) / 2, pcb_width(type) / 2, 0]) pcb(type);
}

module nop_side_by_side() {
    for (p = nop_pairs) translate([0, p[2], 0]) {
        gallery_part(p[0]);
        translate([110, 0, 0]) nop_board(p[1]);
    }
}

// Same boards stacked in one place, ours see-through, with NopSCADlib's hole
// positions drawn as red pins. A pin that misses our hole is a disagreement.
module nop_overlay() {
    for (p = nop_pairs) translate([0, p[2], 0]) {
        nop_board(p[1]);
        translate([0, 0, 0.02]) gallery_part_ghost(p[0]);
        color("red")
        translate([pcb_length(p[1]) / 2, pcb_width(p[1]) / 2, 0])
        pcb_screw_positions(p[1]) cylinder(d = 0.8, h = 12, $fn = 12);
    }
}

module gallery_part_ghost(m) {
    if      (m == SHOW_RPI5)   rpi5(alpha = 0.35);
    else if (m == SHOW_PICO)   pico(alpha = 0.35);
    else if (m == SHOW_TP4056) tp4056(alpha = 0.35);
}

// ── Mode dispatch ────────────────────────────────────────────────
if (mode == SHOW_GALLERY) gallery();
else if (mode == SHOW_CUTTER_CHECK) cutter_check();
else if (mode == SHOW_NOP_SIDE_BY_SIDE) nop_side_by_side();
else if (mode == SHOW_NOP_OVERLAY) nop_overlay();
else if (mode >= SHOW_RPI5 && mode <= SHOW_MX_SWITCH) gallery_part(mode);
else assert(false, str("Unknown mode: ", mode));
