// openscad-playground — GLOBAL VIEWER
//
// Open THIS file in OpenSCAD and leave it open. It always renders the *active*
// project — whichever one the REPL or qa-open.sh last selected. Switch projects
// in the REPL (press `g`) and OpenSCAD auto-reloads to the new model; tweak its
// variables in the REPL and they update live here too.
//
// How it works: this file includes `playground-active.scad`, a generated
// one-line pointer at the active project's entry SCAD. The REPL (on startup and
// on every `g` switch) and qa-open.sh rewrite that pointer.
//
// `playground-active.scad` is generated and gitignored. If OpenSCAD reports it
// is missing, create it by running the REPL once:
//     python3 scripts/qa-repl.py
// or by selecting a project:
//     bash scripts/qa-open.sh
include <playground-active.scad>;
