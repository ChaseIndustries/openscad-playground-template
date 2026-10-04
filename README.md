# openscad-playground

<img width="3438" height="1412" alt="image" src="https://github.com/user-attachments/assets/163cf051-2c6e-4080-a1e5-d379998a7c57" />


A monorepo template for OpenSCAD parametric design. Ships with a config-driven REPL for live-tweaking models, a screenshot-driven QA workflow, and a sandboxed QA environment so Claude can iterate on geometry without touching your interactive session.

> **This template is built for AI-assisted design.** Point Claude at it, hand it `AGENTS.md`, and let it drive the QA loop. The sandbox protocol, screenshot verification, and REPL are all designed for an agent to own the iteration cycle — without the user having to supervise each render.

## What lives here

```
.agents/skills/verify-design/   QA scripts + the skill agents invoke
docs/                           OpenSCAD CLI notes, workflow guide, REPL schema
lib/components/                 Measured models of real boards and panel parts
lib/NopSCADlib/                 NopSCADlib (submodule): hundreds more bought parts
projects/                       One folder per object (see example-bracket/ and component-gallery/)
scripts/                        The REPL and CLI wrappers (qa-*, export_parts, new-project)
build/<project>/                Exported STLs (gitignored)
playground.scad                 Global viewer — open in OpenSCAD; follows the active project
```

## Prerequisites

- [OpenSCAD](https://openscad.org/downloads.html#snapshots) nightly build
- Python 3. `make start` installs `prompt_toolkit` from `requirements.txt` the first time
- After cloning: `git submodule update --init` for NopSCADlib
- [`bd` (beads)](https://github.com/gastownhall/beads) for issue tracking (agents use this; humans can skip it)

## Recommended workflow

Open the global viewer in OpenSCAD, then launch the REPL:

```bash
open -a OpenSCAD playground.scad   # macOS — open once, leave it open
make start                         # from the root, or from any projects/<slug>/
```

The REPL auto-detects the active project (from the folder you are in, or the last one you picked), loads its `repl-config.json`, and renders the panel.

### How the REPL works

The REPL reads `repl-config.json` from the active project and renders a live panel in your terminal. When you change anything (mode, variable, part visibility), it rewrites the relevant lines in `<project>_qa.scad`. OpenSCAD watches that file and auto-reloads, so the viewport updates immediately. No manual file edits, no CLI flags.

**What the panel gives you:**

| Section | What it does |
|---------|-------------|
| Modes | Switch between assembly views and print-layout orientations |
| Parts | Toggle individual parts on/off to isolate geometry |
| Variables | Nudge float/int params up or down; bool vars toggle with one key |
| Color schemes | Cycle through visual presets (`c`) |

**Global hotkeys:**

| Key | Action |
|-----|--------|
| `up` `down` / `Tab` | Navigate the panel |
| `left` `right` / `Enter` | Adjust or activate the selected item |
| `n` / `p` | Next / previous mode |
| `c` | Cycle color scheme |
| `a` | Show all parts |
| `0`-`9` | Pick item N in the focused section (mode id, part, variable, color scheme) |
| `g` | Switch project (viewer follows without a restart) |
| `e` / `E` | Export this project's / all projects' STLs headlessly |
| `x` | Toggle xray (parts go translucent so you can see inside) |
| `o` | Open `playground.scad` in the OpenSCAD GUI |
| `q` | Quit |

Variable hotkeys are declared per-project in `repl-config.json` (lowercase = decrement, uppercase = increment). The panel only shows sections the project actually declares, so minimal projects get a minimal panel.

## Manual commands

For scripting, CI, or when you want finer control:

```bash
# Set the active project explicitly (sticky for this shell):
export PLAYGROUND_PROJECT=example-bracket

# Render the catalog of QA views for mode 5 (the printable bracket):
bash scripts/qa-views.sh 5 example_bracket

# Export STLs for all "print" modes declared in repl-config.json,
# to build/example-bracket/<STL_NAME>.stl:
bash scripts/export_parts.sh
```

## Add a new project

```bash
bash scripts/new-project.sh widget
$EDITOR projects/widget/widget.scad
$EDITOR projects/widget/repl-config.json
```

Before modelling anything you would buy (a board, sensor, servo, screw),
check `lib/components/` and `lib/NopSCADlib/vitamins/`. See
`docs/NEW_PROJECT.md` for the full walkthrough.

## Reading order

1. `AGENTS.md` -- rules every agent must follow
2. `docs/WORKFLOW.md` -- the screenshot-driven loop and sandbox protocol
3. `docs/REPL.md` -- `repl-config.json` schema and all key bindings
4. `docs/OPENSCAD_CLI.md` -- `--camera` gotchas, viewport CSV format
5. `.agents/skills/verify-design/SKILL.md` -- the QA skill agents invoke
