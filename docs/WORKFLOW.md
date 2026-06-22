# Workflow — openscad-playground

The whole monorepo is built around one loop:

> **edit → render → look at the pixels → iterate**

That sounds trivial, but the entire QA toolset exists to enforce it. "OpenSCAD
compiled" is *not* verification. PNGs are.

## Picking the active project

Every QA command needs to know which project under `projects/` you're working
on. Resolution order:

1. `PLAYGROUND_PROJECT=<slug>` (sticky for the shell session)
2. `cd projects/<slug>/` (auto-detected from `pwd`)
3. `<workbench>/.playground-active` file (one line: slug)
4. The single project, if `projects/` contains exactly one
5. Error — set it explicitly

Easiest pattern at session start:

```bash
export PLAYGROUND_PROJECT=example-bracket
```

To pick a project interactively and open it in the OpenSCAD GUI, use the
project picker — it lists every project under `projects/`, lets you choose one
(or pass a slug), writes `.playground-active`, materializes the project's
`<slug>_qa.scad` from its template if needed, and launches OpenSCAD on it:

```bash
bash scripts/qa-open.sh                 # interactive arrow-key menu (↑/↓, Enter, q)
bash scripts/qa-open.sh faucet-index-plug   # open a named project directly
bash scripts/qa-open.sh --list          # just list projects (* = active)
bash scripts/qa-open.sh --no-open <slug> # set active only, don't launch the GUI
```

### The global viewer (`playground.scad`)

`playground.scad` at the repo root is **one file you open in OpenSCAD and leave
open**. It always renders the active project. Behind it, a generated
`playground-active.scad` (gitignored) points at the active project's entry SCAD;
the REPL (on startup and on every `g` switch) and `qa-open.sh` rewrite that
pointer, so OpenSCAD auto-reloads to the project you just selected — no need to
open each project's file separately. If OpenSCAD says `playground-active.scad`
is missing, run the REPL once or `qa-open.sh` to generate it.

## The screenshot-driven loop

1. **Baseline.** Capture a shot of the part you're about to edit:
   ```bash
   bash scripts/qa-views.sh --shot default 5 my_part
   ```
   The script prints `QA dir: …` — open the PNG.
2. **Edit** the SCAD.
3. **Re-render** the same shot. The same `QA dir:` path is reused if you pass
   it via `QA_DIR=`.
4. **Inspect the new PNG.** Visually. If it's wrong, go back to step 2.
5. **Compile check** when you think you're done:
   ```bash
   bash scripts/qa-compile.sh 5      # fails on warnings or zero triangles
   bash scripts/qa-zfloor.sh 5       # fails if anything is below Z=0
   ```

## Sandbox for agents

The user owns the canonical `<project>_qa.scad`. Their OpenSCAD GUI session
auto-reloads any change to that file. If an agent changes the camera or mode
mid-session, the user gets yanked around. Don't.

Wrap every QA command in `qa-sandbox.sh`:

```bash
# Single command, auto-cleanup:
bash scripts/qa-sandbox.sh -- bash scripts/qa-views.sh 5 my_part

# Session form:
eval "$(bash scripts/qa-sandbox.sh --env)"
bash scripts/qa-zoom.sh 5 build/qa/sess
bash scripts/qa-orbit.sh 5
bash scripts/qa-sandbox.sh --cleanup "$QA_SANDBOX"
```

The sandbox is a temp directory that symlinks everything from the project dir
except `<project>.scad` (copied) and `<project>_qa.scad` (fresh from
`*.template`). Renders still go to the real `build/qa/...` (it's symlinked
through).

## Catalog views

Each project's `data/qa-part-views.json` declares per-mode shots. Render them
all for a mode:

```bash
bash scripts/qa-views.sh 5 my_part        # all catalog shots, sorted
bash scripts/qa-views.sh --shot top 5 my_part   # one named shot
bash scripts/qa-views.sh --list           # TSV of all catalog shots
bash scripts/qa-views.sh --batch          # default shot for every mode
```

A shot is one of:

```json
{"view": "iso_fr_lo", "dist": 120}              // baked
{"view": "iso_fr_lo", "fit": "viewall"}         // auto-fit each render
{"view": "iso_fr_lo", "fit": {"scale": 1.25}}   // viewall * 1.25
{"camera": "tx,ty,tz,rx,ry,rz,dist"}            // exact 7-field camera
```

Optional `"parts": [1, 3]` solos the listed parts (same as `PARTS=`).

## Live REPL

`python3 scripts/qa-repl.py` opens a curses-style panel that edits the
project's `<project>_qa.scad` in place. OpenSCAD picks up every change via
auto-reload. Surface what shows up by editing `repl-config.json`. Full schema
in `docs/REPL.md`.

## STL export

```bash
bash scripts/export_parts.sh        # every print mode in repl-config.json
bash scripts/export_parts.sh tests  # every test mode
bash scripts/export_parts.sh 5 6 8  # explicit mode ids
```

Output: `projects/<slug>/build/<stl_name>.stl`.

## When something looks wrong

Quick first-pass checks:

| Symptom | Try |
|---------|-----|
| Empty viewport in PNG | `qa-compile.sh <mode>` to confirm geometry exists |
| PNG huge but blank | `QA_DIAG_VIEWALL=1 qa-zoom.sh ...` to auto-fit |
| Geometry "looks weird" | `THROWN=1 qa-zoom.sh ...` — purple = non-manifold |
| Part won't print | `qa-zfloor.sh <mode>` to detect underground geometry |
| `--render` produces no PNG | Try `OPENSCAD_RENDER_FLAG=--render=true` |
| `--camera` ignored | Make sure it's ONE comma-separated token — no spaces |

## Folder conventions

```
projects/<slug>/
├── <slug>.scad                  # entry point with mode switch
├── <slug>_qa.scad.template      # committed; ephemeral state goes in <slug>_qa.scad
├── <slug>_qa.scad               # gitignored; auto-created from template
├── playground.json              # paths + build dir
├── repl-config.json             # parts, modes, variables, color schemes
├── data/                        # qa-part-views.json, optional overlap-pairs.json, etc.
└── build/                       # gitignored; STLs and qa/ folder
```
