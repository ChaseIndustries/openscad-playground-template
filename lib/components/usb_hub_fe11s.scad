// ============================================================
// FE1.1S 4-PORT USB 2.0 HUB MODULE  (bare board, JST PH2.0 headers)
// ============================================================
// No USB-A sockets. Five 4-pin PH2.0 headers wired GND / D- / D+ / 5V: one
// upstream at the -X end, four downstream along the -Y edge. Because the
// upstream header breaks 5V out separately, the hub can be powered from its
// own rail while data comes from the host.
//
// Outline, thickness, hole pattern and tallest-part height are caliper
// measured. Header positions are INDICATIVE: the downstream strip width falls
// out of the offset hole pattern, but individual header spacing was never
// measured. The 11mm body height is drawn as a translucent keep-out because
// where the electrolytics stand is unknown.
//
// Measuring tip that fixed a 1mm error here: measure to a hole WALL and add
// the radius. Calipers cannot find a hole centre on a board this small.
//
// Board-local frame:
//   origin = PCB underside, corner at the upstream end, downstream edge
//   +X along 65mm, +Y along 30.2mm, +Z = component side
// ============================================================

use <common.scad>

usb_hub_size      = [65.0, 30.2, 1.6];
usb_hub_body_h    = 11.0;    // above the PCB top (electrolytics)
usb_hub_hole_d    = 3.0;     // M2.5/M3 clearance, not M2
usb_hub_hole_edge_x = 3.5;   // from each short edge: 58.0 span
usb_hub_hole_edge_y = 4.0;   // first row from the +Y edge
usb_hub_hole_span_y = 14.0;  // row to row
usb_hub_holes = [for (x = [usb_hub_hole_edge_x, usb_hub_size[0] - usb_hub_hole_edge_x],
                      y = [usb_hub_size[1] - usb_hub_hole_edge_y,
                           usb_hub_size[1] - usb_hub_hole_edge_y - usb_hub_hole_span_y]) [x, y]];
usb_hub_jst_strip_w = usb_hub_size[1] - usb_hub_hole_edge_y - usb_hub_hole_span_y;   // 12.2
usb_hub_jst_h     = 5.8;     // PH2.0 shroud height (datasheet nominal)

module usb_hub_at_holes() { comp_at(usb_hub_holes) children(); }

module usb_hub_fe11s(alpha = undef) {
    _t = usb_hub_size[2];
    _a = is_undef(alpha) ? 1 : alpha;

    difference() {
        color(comp_rgba([0.09, 0.42, 0.28, 1], alpha)) cube(usb_hub_size);
        usb_hub_at_holes() translate([0, 0, -1]) cylinder(d = usb_hub_hole_d, h = _t + 2, $fn = 20);
    }

    // Downstream D1..D4 strip, drawn as one band
    color(comp_color("bone", alpha))
    translate([0, 0, _t]) cube([usb_hub_size[0], usb_hub_jst_strip_w, usb_hub_jst_h]);

    // Upstream header
    color(comp_color("bone", alpha))
    translate([0, (usb_hub_size[1] - 9.4) / 2, _t]) cube([4.5, 9.4, usb_hub_jst_h]);

    // Tallest-part keep-out
    color([0.30, 0.30, 0.38, _a * 0.22])
    translate([0, usb_hub_jst_strip_w, _t])
    cube([usb_hub_size[0], usb_hub_size[1] - usb_hub_jst_strip_w, usb_hub_body_h]);
}

module usb_hub_envelope() {
    cube([usb_hub_size[0], usb_hub_size[1], usb_hub_size[2] + usb_hub_body_h]);
}
