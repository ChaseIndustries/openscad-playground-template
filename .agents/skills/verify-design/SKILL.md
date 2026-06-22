---
name: verify-design
description: Use BEFORE and DURING any OpenSCAD geometry change. Mandatory screenshot-driven loop using qa-zoom / qa-views / qa-orbit, sandbox isolation for agents, and PNG inspection. Apply when the user asks about wall thickness, fit, clearance, overlap, when a design "looks wrong," or whenever you're about to edit a `.scad` module.
---

# verify-design — screenshot-driven OpenSCAD QA

Generalized from the cyberdeck verify-design skill. Works against any project
under `openscad-playground/projects/<slug>/`.

## The loop

1. **Resolve the project** — `PLAYGROUND_PROJECT=<slug>` (or `cd` into
   `projects/<slug>/`). All scripts auto-detect from cwd or env.
2. **Sandbox first** — wrap every QA command in `qa-sandbox.sh` so you don't
   trample the user's interactive GUI session (which owns the canonical
   `<project>_qa.scad`).
3. **Baseline** — render a shot of the part you're about to touch with
   `qa-zoom.sh` or `qa-views.sh --shot NAME` and *open the PNG*.
4. **Edit** the SCAD.
5. **Re-render** the same shot.
6. **Inspect** the new PNG against the baseline. "OpenSCAD compiled" is **not**
   verification — pixels are.
7. Iterate until the geometry matches intent.

## Commands

```bash
# One-shot sandboxed render:
bash .agents/skills/verify-design/scripts/qa-sandbox.sh -- \
  bash .agents/skills/verify-design/scripts/qa-views.sh 5 example_bracket

# Long session: open sandbox, set env, run many commands, clean up:
eval "$(bash .agents/skills/verify-design/scripts/qa-sandbox.sh --env)"
bash .agents/skills/verify-design/scripts/qa-zoom.sh 5 build/qa/sess \
     0 0 0 55 0 25 200 close_iso
bash .agents/skills/verify-design/scripts/qa-orbit.sh 5
bash .agents/skills/verify-design/scripts/qa-sandbox.sh --cleanup "$QA_SANDBOX"
```

## Compile checks

| Script | Purpose |
|--------|---------|
| `qa-compile.sh <mode>` | Exit 0 only on clean STL with non-zero triangles |
| `qa-zfloor.sh <mode>`  | Fail if any vertex Z < 0 (geometry below print bed) |
| `qa-thrown.sh <mode> <qa_dir>` | ThrownTogether preview (purple = bad normal / non-manifold) |

## Catalog views

`projects/<slug>/data/qa-part-views.json` declares per-mode shots:

```json
{
  "schema_version": 1,
  "defaults": {"view": "iso_fr", "dist": 200},
  "modes": {
    "5": {
      "part_slug": "print_bracket",
      "shots": {
        "default": {"view": "iso_fr_lo", "fit": "viewall"},
        "top":     {"view": "top",       "fit": "viewall"},
        "side":    {"view": "right",     "dist": 120}
      }
    }
  }
}
```

`schema_version` and `defaults` (fallback `view`/`dist` for shots that omit
them) are optional but present in the generated catalogs. Each shot is one of:
- `{view, dist}` — baked named preset + camera distance
- `{view, fit: "viewall"}` — auto-fit at render time
- `{view, fit: {scale: 1.25}}` — viewall * scale
- `{camera: "tx,ty,tz,rx,ry,rz,dist"}` — explicit 7-field ortho camera

Render all shots for a mode: `qa-views.sh 5 print_bracket`
Render one named shot:      `qa-views.sh --shot top 5 print_bracket`

## Reading a QA_VIEWPORT paste from the user

The user can copy a `QA_VIEWPORT tx,ty,tz,rx,ry,rz,dist[,mode[,projection]]`
line from OpenSCAD's console (F5 echo, requires `qa_dump_viewport = true` in
their qa.scad). To reproduce that camera headlessly:

```bash
CAMERA=$(printf '%s\n' '<paste>' | \
  python3 .agents/skills/verify-design/scripts/qa_viewport_format.py camera-csv-from-text)
CAMERA="$CAMERA" LABEL=user_repro \
  bash .agents/skills/verify-design/scripts/qa-zoom.sh <mode> build/qa/repro
```

`qa-zoom.sh` always renders ortho. For a perspective match, call `openscad`
directly with `--projection=perspective` and the same 7-field camera (see
`docs/OPENSCAD_CLI.md`).

## Named camera presets

`top bottom front back left right iso_fr iso_fl iso_br iso_bl iso_fr_hi
iso_fl_hi iso_br_hi iso_bl_hi iso_fr_lo iso_fl_lo iso_br_lo iso_bl_lo`

## Rules of thumb

- **`build/qa/` only**, never `/tmp`. The QA scripts already do this.
- **`--camera=` is ONE token** — comma-separated. Spaces between numbers are
  invalid (`docs/OPENSCAD_CLI.md`).
- **Sandbox before any QA work** that touches camera or `mode`. Touching the
  canonical `<project>_qa.scad` while the user has the GUI open will yank
  their camera mid-session.
- **`PARTS=` / `HIDE=`** work against the project's `repl-config.json` parts
  list (or numeric indices when no config exists).
