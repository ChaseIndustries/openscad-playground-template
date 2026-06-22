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

## What to fill in

1. **Real geometry** in `widget.scad` — replace the placeholder cube.
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
├── data/
│   ├── qa-part-views.json
│   ├── overlap-pairs.json      # optional, see verify-design skill
│   └── qa-expected-genus.json  # optional
└── build/                      # gitignored output
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

The sandbox symlinks the project dir — files outside the project won't be
included in the sandbox copy, but symlinks at the project level are preserved.
For larger sharing concerns, factor the shared geometry into its own project
and import as a module.

## Committing

The `.gitignore` at the workbench root already excludes:

- `projects/*/qa.scad` and `*_qa.scad`
- `projects/*/build/`
- `__pycache__/`, `.DS_Store`, etc.

So you can `git add projects/widget/` without picking up local QA state.
