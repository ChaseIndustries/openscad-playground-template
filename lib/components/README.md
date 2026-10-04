# Component library

Models of real electronic parts for enclosure work. They were lifted out of the
cyberdeck project, where every number was either taken from a datasheet or
measured with calipers on the part in hand. Browse them in
`projects/component-gallery` (mode 0 shows them all, modes 1 to 22 show one each).

## Using it

From a project under `projects/<slug>/`:

```scad
include <../../lib/components/raspberry_pi_5.scad>;    // one part
include <../../lib/components/components.scad>;        // or all of them
```

`include` gets you the constants and the modules. Every constant carries its
part's prefix (`rpi5_`, `pico_`, `heltec_v4_` and so on), so nothing collides
with your project's own names. QA sandboxes resolve `../../lib` correctly.

## What every part gives you

The same shape of API on every part, so learning one teaches you all of them.

| Name | What it is |
|------|------------|
| `<part>(alpha)` | Ghost model with ports, chips and pins, coloured to read on sight |
| `<part>_envelope()` | Plain worst-case block for clearance and overlap checks. Kept plain on purpose: detailing it would shrink the volume a check is asserting on |
| `<part>_size`, `<part>_height` | PCB outline and overall height |
| `<part>_holes`, `<part>_at_holes()` | Hole list, and a module that places children on every hole |
| `<part>_*_cutout(...)` | Panel cutters with a `clearance` argument |

Standoffs, bores and heat-set pockets all come off the one hole list:

```scad
rpi5_at_holes() cylinder(d = 5, h = 6);                        // standoffs
rpi5_at_holes() cylinder(d = 3.6, h = 5);                      // M2.5 insert bores
```

## Coordinate frames

Boards: origin at the PCB **underside**, on the `-X/-Y` corner. The long edge
runs along `+X`, components face `+Z`. Each file's header says which edge
carries which port. Place a board, its holes and its cutters with the same
transform and they cannot drift apart.

Panel parts (LED, pushbutton, SMA): origin at the hole centre on the panel's
**outer** face, `+Z` pointing out at the user. Put the outer face at `z = 0` and
subtract `*_cutout(panel_t)`.

Displays: origin at the rear of the module, `+Z` toward the viewer.

## Parts

| File | Parts |
|------|-------|
| `raspberry_pi_5.scad` | `rpi5`, `rpi5_active_cooler`, `rpi_ai_hat2`, `rpi5_ai_stack`, port cutters for both port edges |
| `raspberry_pi_pico.scad` | `pico` (Pico / W / 2 / 2 W, optional headers), micro-USB cutter |
| `heltec_lora32_v4.scad` | `heltec_v4`, slide-in rail slot, USB-C cutter |
| `rtl_sdr_bare.scad` | `rtlsdr_bare` (shell off, plug desoldered), SMA cutter |
| `usb_hub_fe11s.scad` | `usb_hub_fe11s`, bare 4-port hub on PH2.0 headers |
| `power_modules.scad` | `tp4056`, `boost5v`, `relay_srd05`, `usbc_pd_breakout` + port slot |
| `terminal_blocks.scad` | `kerwinn_block(positions)`, `perfboard(cols, rows)` |
| `trackpad_tps43.scad` | `tps43`, `tps43_cover`, `fpc6_breakout` |
| `displays.scad` | `display7` (7" DSI), `oled312` (3.12" SSD1322), window cutters |
| `panel_hardware.scad` | `led5_bezel`, `pushbutton16`, `sma_bulkhead` + cutters |
| `batteries_storage.scad` | `lipo_pouch` + pocket, `m2_ssd(length)` |
| `mx_switch.scad` | `mx_switch(units)`, `mx_plate_cutout`, `mx_plate_grid` |
| `common.scad` | `comp_color`, `comp_at`, `comp_rect_holes`, `comp_reserved_cage`, `comp_pin_row` |

## Trust levels

Measured or datasheet: everything that sets a hole, an outline or an overall
height. Silhouette only: chip and connector placement on the top face, drawn so
the board reads at a glance. Each file says which is which. A few you should
know before you lean on them:

- **RTL-SDR bare PCB outline** is approximate, from teardown photos. The hole
  spacing is measured.
- **FE1.1S hub header positions** are indicative. Outline and holes are measured.
- **TPS43 thickness**: calipers say 1.5mm, the part number says 1.0mm.
  The model uses 1.5.
- **3.12" OLED** has its glass drawn centred on the PCB, and no holes.
- **Pi 5 port shells** are sized from the drawing's centres plus typical shells.
  Keep the cutters' `clearance` argument.

## Colours

Each part draws its body in its own colour and borrows three shared detail
colours: silver for connector shells and cans, near-black for chips and
openings, gold for pins and pads. `comp_color("shield" | "dark" | "brass" | ...)`
returns them, with an optional alpha override.

## NopSCADlib

[NopSCADlib](https://github.com/nophead/NopSCADlib) is vendored beside this
library as a git submodule at `lib/NopSCADlib`. It has hundreds of parts this
library does not: more boards, displays, fans, PSUs, screws, inserts,
extrusions and so on. After cloning, or after a merge that adds it:

```bash
git submodule update --init
```

Pull in just what you need, since `lib.scad` loads everything and gets slow:

```scad
include <../../lib/NopSCADlib/core.scad>;
include <../../lib/NopSCADlib/vitamins/pcbs.scad>;
pcb(RPI4);
```

It mixes with this library without name clashes. Two conventions differ:
NopSCADlib's `pcb()` is centred on the board outline, ours sit on a corner,
and its parts are property lists read through accessors (`pcb_length(RPI4)`).
NopSCADlib is GPL-3, which matters if you publish a design built on it.

Gallery modes 40 and 41 hold our boards against NopSCADlib's. What they show:

- **Pi**: NopSCADlib has no Pi 5. Its Pi 4 shares the outline, holes and GPIO
  header, and all of those land exactly on ours, header centre at x = 32.5
  included. The IO edge differs on purpose: the Pi 4 has Ethernet on top.
- **Pico**: holes and the 20x2 pin grid match ours exactly. NopSCADlib draws
  the PCB 1.6mm thick, we use the datasheet's 1.0mm.
- **TP4056**: NopSCADlib models the micro-USB version (26.2 x 17.5). Ours is
  the measured USB-C version (26 x 17).
