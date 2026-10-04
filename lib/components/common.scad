// ============================================================
// COMPONENT LIBRARY: shared helpers
// ============================================================
// Pulled in by every component file with `use <common.scad>`, so it exposes
// only functions and modules. Constants here would be invisible to callers.
//
// Ghost colours follow one rule across the library: each part draws its body
// in its own colour, then borrows the shared detail colours for the features
// that identify it. A silver box on an edge is always a connector, a dark
// block is always an IC or opening, and gold is always a contact. That is
// what lets you read a board you have never seen before.
// ============================================================

_comp_palette = [
    ["shield",  [0.72, 0.74, 0.78, 1.00]],   // connector shells, cans, screw heads
    ["dark",    [0.10, 0.10, 0.13, 1.00]],   // port openings, ICs, inductors, holes
    ["brass",   [0.80, 0.64, 0.22, 1.00]],   // terminal screws, header pins, pads
    ["pcb",     [0.12, 0.45, 0.18, 0.90]],   // generic green FR-4
    ["perf",    [0.16, 0.46, 0.26, 0.96]],   // perfboard
    ["blue",    [0.12, 0.42, 0.98, 0.96]],   // blue module boards (TP4056, relay)
    ["bone",    [0.88, 0.83, 0.68, 0.96]],   // terminal block bodies, JST housings
    ["cooler",  [0.55, 0.55, 0.58, 0.90]],   // heatsinks
    ["lcd",     [0.28, 0.38, 0.92, 0.90]],   // display module PCB
    ["glass",   [0.08, 0.08, 0.10, 0.95]],   // display glass
    ["battery", [0.75, 0.75, 0.15, 0.90]],   // LiPo pouch
    ["led",     [0.98, 0.88, 0.22, 0.92]],   // LED lenses
    ["plastic", [0.18, 0.18, 0.20, 0.95]],   // black plastic bodies
    ["keycap",  [0.88, 0.88, 0.92, 0.95]],
];

// Named palette colour, optionally with its alpha replaced.
//   color(comp_color("shield")) ...
//   color(comp_color("pcb", 0.4)) ...
function comp_color(name, alpha = undef) =
    let (hit = [for (p = _comp_palette) if (p[0] == name) p[1]],
         c   = len(hit) > 0 ? hit[0] : [1, 0, 1, 1])
    is_undef(alpha) ? c : [c[0], c[1], c[2], alpha];

// Same alpha override for an arbitrary RGBA.
function comp_rgba(c, alpha = undef) =
    is_undef(alpha) ? c : [c[0], c[1], c[2], alpha];

// Reserved volume drawn as the twelve edges of its box. Use it for parts you
// have not measured: an envelope that is a guess should not look like a part,
// and a cage keeps whatever sits inside visible from every angle.
module comp_reserved_cage(size, bar = 1.2) {
    for (i = [0, 1], j = [0, 1]) {
        translate([i * (size[0] - bar), j * (size[1] - bar), 0])
        cube([bar, bar, size[2]]);

        translate([i * (size[0] - bar), 0, j * (size[2] - bar)])
        cube([bar, size[1], bar]);

        translate([0, i * (size[1] - bar), j * (size[2] - bar)])
        cube([size[0], bar, bar]);
    }
}

// Place children at every [x, y] (or [x, y, z]) in a list. Every component's
// *_at_holes() module is this with its own hole list, so standoffs, bores and
// heat-set insert pockets all come from one pattern:
//   rpi5_at_holes() cylinder(d = 2.7, h = 10, center = true);
module comp_at(points) {
    for (p = points)
        translate([p[0], p[1], len(p) > 2 ? p[2] : 0])
        children();
}

// Four holes on a rectangle, as an [x, y] list. inset is per axis.
function comp_rect_holes(size, inset) =
    let (ix = is_list(inset) ? inset[0] : inset,
         iy = is_list(inset) ? inset[1] : inset)
    [[ix, iy], [size[0] - ix, iy], [ix, size[1] - iy], [size[0] - ix, size[1] - iy]];

// Hole markers that read on top of a board ghost.
module comp_hole_marks(points, d, z, $fn = 16) {
    comp_at(points)
    translate([0, 0, z - 0.1])
    cylinder(d = d, h = 0.3);
}

// A straight run of 0.1" header pins standing up from z = 0, along +X.
module comp_pin_row(n, pitch = 2.54, h = 6.0, d = 0.64) {
    for (i = [0 : n - 1])
        translate([i * pitch - d / 2, -d / 2, 0])
        cube([d, d, h]);
}
