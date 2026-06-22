# example-bracket

A tiny hinged L-bracket — the worked example for openscad-playground.

Demonstrates:

- **Mode dispatch** in `example-bracket.scad` (`SHOW_ASSEMBLY`, `PRINT_BASE`, …)
- **Per-part visibility** via `viz_show_part_N` booleans
- **REPL-exposed variable** (`lid_angle`) that the TTY panel sliders 0–90°
- **Catalog views** in `data/qa-part-views.json`

## Try it

```bash
export PLAYGROUND_PROJECT=example-bracket

# Render every catalog shot for the assembly:
bash scripts/qa-views.sh 0 assembly

# Just one named shot:
bash scripts/qa-views.sh --shot top 0 assembly

# Compile check for a print mode:
bash scripts/qa-compile.sh 5

# Live control panel (writes to example-bracket_qa.scad; OpenSCAD auto-reloads):
python3 scripts/qa-repl.py

# Export all STL print parts:
bash scripts/export_parts.sh
```

## Adding a new variable

1. Declare it in `example-bracket.scad` with a default (`my_var = 0;`).
2. Add a matching line to `example-bracket_qa.scad.template`.
3. Add an entry under `variables` in `repl-config.json`:

```json
{"name": "my_var", "type": "float", "label": "My var",
 "min": 0, "max": 100, "step": 5, "default": 0, "hotkey": "m"}
```

The REPL picks it up on next launch.
