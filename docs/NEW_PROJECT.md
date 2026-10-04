# Adding a new project to the monorepo

## Fast path

```bash
bash scripts/new-project.sh widget
export PLAYGROUND_PROJECT=widget
$EDITOR projects/widget/widget.scad
$EDITOR projects/widget/repl-config.json
```

That gives you a working skeleton with:

- `widget.scad` — entry SCAD with one example part and a mode switch
- `widget_qa.scad.template` — committed QA template
- `widget_qa.scad` — created on first QA run from the template (gitignored)
- `playground.json` — paths
- `repl-config.json` — minimal parts/modes/variables/color_schemes
- `data/qa-part-views.json` — empty catalog with two shots
- `qa-repl.py` — symlink to `scripts/qa-repl.py`; run `./qa-repl.py` from the project folder
- `Makefile` — symlink to the root `Makefile`; `make start` opens the REPL

## What to fill in

1. **Real geometry** in `widget.scad` — replace the placeholder cube.
   Pull every bought part (boards, sensors, servos, displays, screws) from
   `lib/components/` or `lib/NopSCADlib/` before modelling it yourself.
   See [Electronic component library](#electronic-component-library).
2. **Modes** — every printable variant gets a `mode == PRINT_X` branch.
   Mirror them in `repl-config.json` `modes` with `type: "print"` so
   `export_parts.sh` picks them up.
3. **Parts** — for each independently visible part, add:
   - A `viz_show_part_N = true;` line in the qa.scad.template
   - A guarded call (`if (viz_show_part_N) my_part();`) in the SCAD
   - An entry in `repl-config.json` `parts`
4. **Variables** the REPL should slider — declare the default in both files
   and add a `variables` entry in `repl-config.json`. See `docs/REPL.md`.
5. **Catalog views** — add per-mode shots to `data/qa-part-views.json`. Start
   with `default`; add named ones as you discover useful angles.

## File layout

```
projects/widget/
├── widget.scad
├── widget_qa.scad.template     # committed
├── widget_qa.scad              # gitignored; auto-created
├── playground.json
├── repl-config.json
├── README.md
├── ASSEMBLY.md                 # parts list + build steps, when needed (see AGENTS.md)
├── data/
│   ├── qa-part-views.json
│   ├── overlap-pairs.json      # optional, see verify-design skill
│   └── qa-expected-genus.json  # optional
└── build/                      # gitignored QA output (STLs go to the root build/<slug>/)
```

## Naming conventions

- **Slug** (the folder name) is the canonical project ID. Use only `a-z0-9_-`.
- **Entry SCAD** matches the slug by default: `widget/widget.scad`. Override
  via `playground.json.scad_entry` if needed.
- **QA include** matches `<slug>_qa.scad` by default. Same override path.
- **STL output names** come from `repl-config.json` `modes[].stl_name`.

## Multiple projects sharing geometry

Each project is self-contained. If two projects share a library of helpers,
put them in `<workbench>/lib/` (create it as needed) and include from each:

```scad
include <../../lib/shared/helpers.scad>;
```

The sandbox mirrors the workbench layout (`<tmp>/projects/<slug>` next to a
`<tmp>/lib` symlink), so `../../lib/...` resolves the same in QA renders as it
does in the GUI. Anything else outside the project dir is not carried over.

### Electronic component library

`lib/components/` holds ready-made models of real boards and panel parts:
Raspberry Pi 5 (with Active Cooler and AI HAT+ 2), Pico, Heltec LoRa 32 V4,
displays, power modules, terminal blocks, panel LEDs/buttons/SMA jacks and
more. Each one comes with its dimensions, a ghost model, a keep-out envelope,
a hole pattern and panel cutters. See `lib/components/README.md`, and browse
them all in `projects/component-gallery`.

NopSCADlib is vendored as a submodule at `lib/NopSCADlib` for everything the
component library does not cover. Run `git submodule update --init` after
cloning. Search it with `grep -rn 'Pi Zero' lib/NopSCADlib/vitamins` and
include just the one vitamin file you need:

```scad
include <../../lib/NopSCADlib/core.scad>;
include <../../lib/NopSCADlib/vitamins/pcbs.scad>;
pcb(RPI0);   // centred on the board outline, unlike lib/components
```

Check both libraries before modelling a bought part from scratch. A ghost
from the library, with your holes and cutouts driven off its dimensions,
keeps the print honest.

## Committing

The `.gitignore` at the workbench root already excludes:

- `projects/*/qa.scad` and `*_qa.scad`
- `projects/*/build/`
- `__pycache__/`, `.DS_Store`, etc.

So you can `git add projects/widget/` without picking up local QA state.
