// ============================================================
// LIPO POUCH CELL  +  M.2 NVMe SSD
// ============================================================

use <common.scad>

// ------------------------------------------------------------
// Flat LiPo pouch. Defaults are a 3.7V 6000mAh cell (YELUFT), bare size
// 91 x 60 x 9mm. Pouches swell with age, so pocket them with ~0.5mm per side
// in X/Y and leave Z free rather than clamping the face.
// Frame: origin = -X/-Y corner of the underside, lead tab on the +X edge.
// ------------------------------------------------------------
lipo_6000_size = [91.0, 60.0, 9.0];

module lipo_pouch(size = lipo_6000_size, alpha = undef) {
    color(comp_color("battery", alpha)) cube(size);
    color(comp_color("shield", alpha))
    translate([size[0], size[1] / 2 - 6, size[2] / 2 - 1]) cube([5, 12, 2]);
}

// Pocket cutter: the cell plus margin per side in X/Y, open above.
module lipo_pocket(size = lipo_6000_size, margin = 0.5, depth_extra = 5) {
    translate([-margin, -margin, -0.01])
    cube([size[0] + 2 * margin, size[1] + 2 * margin, size[2] + depth_extra]);
}

// ------------------------------------------------------------
// M.2 M-key NVMe SSD, 22mm wide, 2230 / 2242 / 2260 / 2280. Thickness is a
// double-sided worst case. Frame: origin = -X/-Y corner of the underside,
// edge connector at X = 0, mounting half-moon at X = length.
// ------------------------------------------------------------
m2_ssd_width     = 22.0;
m2_ssd_thickness = 3.8;
m2_ssd_pcb_t     = 0.8;

module m2_ssd(length = 80, alpha = undef) {
    _z = (m2_ssd_thickness - m2_ssd_pcb_t) / 2;
    color(comp_color("dark", alpha)) translate([4, 1, 0]) cube([length - 8, m2_ssd_width - 2, m2_ssd_thickness]);
    color(comp_color("pcb", alpha))
    translate([0, 0, _z]) difference() {
        cube([length, m2_ssd_width, m2_ssd_pcb_t]);
        translate([length, m2_ssd_width / 2, -1]) cylinder(d = 3.5, h = 3, $fn = 20);
        translate([-0.1, m2_ssd_width / 2 + 5.5, -1]) cube([1.6, 1.2, 3]);   // M-key notch
    }
    color(comp_color("brass", alpha)) translate([0, 1.5, _z]) cube([3.5, m2_ssd_width - 3, m2_ssd_pcb_t + 0.02]);
}
