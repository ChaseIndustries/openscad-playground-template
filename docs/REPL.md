# REPL — `repl-config.json` schema

The REPL (`scripts/qa-repl.py`) is a config-driven TTY control panel. Each
project under `projects/<slug>/` declares what knobs to expose in
`repl-config.json`. The REPL reads that file, renders a panel, and writes
changes back to `<slug>_qa.scad` so OpenSCAD's auto-reload picks them up
live.

## Schema

```json
{
  "parts": [
    {
      "idx":   1,
      "name":  "Base wall",
      "slug":  "base",
      "group": "Bracket",
      "orient": "+Y face = back; hinge along top edge"
    }
  ],
  "modes": [
    {"id": 0, "name": "Assembly",      "type": "pose"},
    {"id": 5, "name": "Print: body",   "type": "print", "stl_name": "PRINT_BODY"}
  ],
  "variables": [
    {
      "name":   "lid_angle",
      "type":   "float",
      "label":  "Lid angle (deg)",
      "min":    0,
      "max":    130,
      "step":   5,
      "default": 0,
      "hotkey": "l"
    }
  ],
  "color_schemes": ["qa", "mono", "tactical"]
}
```

### `parts`

| Field    | Type   | Notes |
|----------|--------|-------|
| `idx`    | int    | Part index; the REPL toggles `viz_show_part_<idx> = true/false` in `qa.scad` |
| `name`   | string | Display name in the panel |
| `slug`   | string | Lowercase identifier used by `PARTS=`/`HIDE=` env vars |
| `group`  | string | Optional grouping header in the panel |
| `orient` | string | Optional one-liner reminding which side faces where |

For each part the SCAD entry file (and the `_qa.scad.template`) must declare a
matching boolean: `viz_show_part_1 = true;`. The geometry then checks
`if (viz_show_part_1) base_part();` to honor it.

### `modes`

| Field      | Type   | Notes |
|------------|--------|-------|
| `id`       | int    | The `mode = N;` value the entry SCAD dispatches on |
| `name`     | string | Display name |
| `type`     | string | `pose` (assembly view) or `print` (STL export) or `test` |
| `stl_name` | string | Output base filename for `print`/`test` modes (`export_parts.sh`) |

### `variables`

| Field     | Type    | Notes |
|-----------|---------|-------|
| `name`    | string  | The SCAD variable name (must exist in the entry SCAD and qa.scad.template) |
| `type`    | string  | `float`, `int`, or `bool` |
| `label`   | string  | Display name |
| `min`     | number  | Inclusive lower bound (float/int only) |
| `max`     | number  | Inclusive upper bound (float/int only) |
| `step`    | number  | Adjust delta for arrow keys (float/int only) |
| `default` | any     | Default value if not present in qa.scad |
| `hotkey`  | string  | Lowercase letter; lowercase = decrement, uppercase = increment |

`bool` variables don't take `min`/`max`/`step` — the hotkey toggles.

### `color_schemes`

A list of human-readable scheme names matching the indices your entry SCAD
recognizes (via `color_scheme = N;`). Press `c` in the REPL to cycle.

## Required `qa.scad` markers

The REPL only edits SCAD lines it can find unambiguously:

```scad
// QA_REPL_MODE
//mode = 5;
mode = 0;     // ← REPL rewrites this line on mode switch
```

The `// QA_REPL_MODE` line is the marker. The REPL finds the first
`mode = N;` (un-commented) on a line after it and rewrites the integer.

Per-part / per-variable lines just need to exist anywhere in the file:

```scad
viz_show_part_1 = true;
viz_show_part_2 = true;
lid_angle = 0;
color_scheme = 0;
```

The REPL rewrites the value in place, preserving indentation.

## Key bindings

The panel is split into sections (Modes, Parts, Variables, Color scheme). Drive
it with the arrow keys (a highlighted selection) or the letter/number hotkeys —
both do the same thing.

### Arrow navigation

| Key                 | Action |
|---------------------|--------|
| `↑` / `↓`           | Move the selection within the current section |
| `Tab` / `Shift-Tab` | Switch to the next / previous section |
| `←` / `→`           | Adjust the selected item (mode prev/next · part hide/show · variable −/+ `step` · color cycle) |
| `Enter` / `Space`   | Activate the selected item (set mode · toggle part · toggle bool var · pick color) |

### Hotkeys

| Key   | Action |
|-------|--------|
| `q`, `Ctrl-C` | Quit |
| `g`           | Switch project (opens an arrow-key picker; reloads the panel for the chosen project and updates `.playground-active`) |
| `e`           | Export this project's `print` parts to STLs (runs `export_parts.sh`; output shown inline, then the panel returns automatically with a summary) |
| `E`           | Export **all** projects' `print` parts to STLs |
| `x`           | Toggle xray (see-through) — sets `viz_opacity` low so you can see inside; honored by geometry that wraps parts in `color(..., viz_opacity)` |
| `n` / `p`     | Next / previous mode |
| `c`           | Cycle color scheme |
| `a`           | Show all parts |
| `o`           | Open `playground.scad` (the global viewer) in the OpenSCAD GUI |
| `1`–`9`       | Toggle the Nth part in the config |
| `<hotkey>`    | Decrement that variable by `step` |
| `<HOTKEY>`    | Increment that variable by `step` |

The REPL is the single QA console: `g` switches between every project under
`projects/` without restarting, and `e` / `E` export STLs headlessly. Reserved
command letters (`q n p c a o g e x`) can't be used as variable hotkeys.
Sections with no entries (and projects without a `repl-config.json`) are
omitted — the panel shows only what a given project actually exposes. The
Modes and Color rows wrap across lines at the terminal width, so a long list
stays fully visible and every entry is reachable with `↑`/`↓` (and `Enter` to
pick, `←`/`→` to cycle).

Numeric keys collide with the first nine parts; if you have ten or more
parts, use `PARTS=name` / `HIDE=name` env vars at the command line instead
(the REPL panel still shows visibility).

## Adding a new variable end-to-end

1. Declare a default in the entry SCAD: `my_var = 0;`
2. Reference it where it matters: `rotate([my_var, 0, 0]) ...`
3. Add a line to `<slug>_qa.scad.template`: `my_var = 0;`
4. Add an entry to `repl-config.json`:

```json
{"name": "my_var", "type": "float", "label": "My var",
 "min": 0, "max": 100, "step": 5, "default": 0, "hotkey": "m"}
```

Restart the REPL — `m` decrements, `M` increments.
