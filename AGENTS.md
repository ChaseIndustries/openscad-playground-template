# Agent rules — openscad-playground

## Issue tracking

This monorepo uses **bd (beads)** for issue tracking. Run `bd prime` after
`/clear` or session start, then `bd ready` to find unblocked work.

## General rules

1. Do not add comments that reference previous implementations.
2. Do not blindly follow requests. Assess whether the request fits the project's
   parts, parameters, modes, and printability before changing geometry. Push back
   if there is a misalignment.
3. Always verify your work. Only commit when you are 100% sure the change is
   correct.
4. If a recurring QA problem can be solved by updating a QA script, do so —
   don't paper over it with one-off workarounds.

## Project resolution

Every QA script needs to know which **project** under `projects/` you're working
on. Resolution order:

1. `PLAYGROUND_PROJECT` env var (sticky across a shell session)
2. The project directory if cwd is under `projects/<name>/`
3. `.playground-active` file at the workbench root (one line: project name)
4. If only one project exists in `projects/`, use it
5. Otherwise: error — set `PLAYGROUND_PROJECT` explicitly

Once resolved, scripts export `PLAYGROUND_PROJECT_DIR` (absolute path to the
project) and `PROJECT_SCAD` (entry SCAD file from `playground.json`).

## Making design changes — MANDATORY screenshot loop

1. **Before** any geometry change: capture a baseline screenshot of the part
   you're about to edit using `qa-zoom.sh` / `qa-views.sh`.
2. Make the change.
3. Render the same view again.
4. Open the PNG and *inspect it*. "OpenSCAD compiled" is **not** verification.
5. Iterate until the geometry matches intent.

For any non-trivial geometry change, use the `/verify-design` skill
(`.agents/skills/verify-design/SKILL.md`). For UI / REPL work, no skill needed.

## QA sandbox — MANDATORY for agents

Agents **must** run all QA scripts inside a sandbox (`qa-sandbox.sh`). The
sandbox gives you a private `qa.scad` so you can freely change `mode`, camera,
part visibility, etc. without disturbing the user's interactive GUI session or
another agent.

```bash
# Wrap a single command:
bash .agents/skills/verify-design/scripts/qa-sandbox.sh -- \
  bash .agents/skills/verify-design/scripts/qa-zoom.sh 5 build/qa/sess

# Or open a session:
eval "$(bash .agents/skills/verify-design/scripts/qa-sandbox.sh --env)"
# … many commands …
bash .agents/skills/verify-design/scripts/qa-sandbox.sh --cleanup "$QA_SANDBOX"
```

The sandbox-root copy of `<project>_qa.scad` belongs to the **user's GUI**.
**Never hand-edit it** from an agent.

## Assembly guides and parts lists

A project gets an `ASSEMBLY.md` when it has more than one printed part,
any bought hardware or electronics, or an assembly order that is not
obvious. A single part that prints and is done needs only its README.

`ASSEMBLY.md` holds, in this order:

1. **Parts list.** It doubles as a shopping list, so someone can order
   from it without opening the SCAD.
   - Printed parts: qty, part, mode, material.
   - Every electronic component: qty, part, a search term or spec precise
     enough to buy the right thing, rough cost, and where it goes. Include
     the unglamorous bits: power supplies, adapters, cables, extension
     leads, resistors, connectors. Mark anything the user already owns in
     a **Have** column, and end with a rough total.
   - Hardware: qty, part, where it goes. Say when one assortment kit
     covers it.
   - Supplies and tools.
2. **Print table.** Mode, orientation, and anything to measure first.
3. **Numbered build steps.** One action per step, in the order a person
   actually builds it.
4. **Wiring table** if there are electronics. Pin numbers and GPIO names.
5. **Troubleshooting** for the failures you can predict.

The parts list in `ASSEMBLY.md` is the only one. The README links to it
instead of keeping a second copy. Any change that adds, removes, or
resizes a part, fastener, or board updates the list in the same commit.

## Bought parts come from the component library

Before you model any part someone buys (a board, sensor, servo, display,
fan, screw, nut, insert), look it up in this order:

1. `lib/components/` (see its README). Measured parts in our house style.
2. `lib/NopSCADlib/vitamins/` (git submodule). Hundreds of boards, displays,
   fasteners, inserts, fans and PSUs. `grep -rn '<part name>'
   lib/NopSCADlib/vitamins` finds most things. Include only the file you
   need, never `lib.scad`.
3. Only then model it in the project. If it would be useful elsewhere, add
   it to `lib/components/` instead.

Use the library model for the ghost, and drive holes, standoffs and cutouts
off its hole list and dimensions, so the print cannot drift from the part.
This applies to new projects and to edits of old ones: when you touch a
hand modelled ghost that a library already covers, swap it.

## OpenSCAD editing rules

- Before editing any module, read the FULL module to understand all features.
- Never remove or overwrite features (screw holes, mounts, etc.) that aren't
  part of the current task.
- After any edit, grep for features that existed before to confirm they still
  exist.
- When the user references a part by name, confirm which `.scad` file owns it
  before editing.

## OpenSCAD CLI — `--camera` is one comma-separated token

`--camera=tx,ty,tz,rx,ry,rz,dist` is ONE argv. Spaces between numbers are
invalid. See `docs/OPENSCAD_CLI.md`.

## Where to write QA PNGs

Never `/tmp`. Always `build/qa/YYYY-MM-DD_HHMM_<slug>/` under the active
project's directory. The QA helpers do this for you.

## Reference files

- `docs/WORKFLOW.md` — full workflow, screenshot loop, sandbox usage
- `docs/REPL.md` — `repl-config.json` schema and REPL key bindings
- `docs/NEW_PROJECT.md` — how to add a new object to the monorepo
- `docs/OPENSCAD_CLI.md` — CLI flags, camera gotchas, viewport format
- `lib/components/README.md` — shared electronic component models (Pi, Pico, LoRa, displays, power modules, panel parts). Check here, then NopSCADlib, before modelling any bought part
- `.agents/skills/verify-design/SKILL.md` — the QA skill itself

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:7510c1e2 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
