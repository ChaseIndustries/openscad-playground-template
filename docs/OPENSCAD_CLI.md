=== Command line usage ===
OpenSCAD can not only be used as a GUI, but also handles command line arguments.

OpenSCAD (DEV/nightly) 2025.08.17 has these options

<pre>
Usage: openscad.exe [options] file.scad
Allowed options:
  --export-format arg               overrides format of exported scad file when
                                    using option '-o', arg can be any of its
                                    supported file extensions.  For ascii stl
                                    export, specify 'asciistl', and for binary
                                    stl export, specify 'binstl'.  Ascii export
                                    is the current stl default, but binary stl
                                    is planned as the future default so
                                    asciistl should be explicitly specified in
                                    scripts when needed.

  -o [ --o ] arg                    output specified file instead of running
                                    the GUI. The file extension specifies the
                                    type: stl, off, wrl, amf, 3mf, csg, dxf,
                                    svg, pdf, png, echo, ast, term, nef3,
                                    nefdbg, param, pov. May be used multiple
                                    times for different exports. Use '-' for
                                    stdout.

  -O [ --O ] arg                    pass settings value to the file export
                                    using the format section/key=value, e.g
                                    export-pdf/paper-size=a3. Use --help-export
                                    to list all available settings.
  -D [ --D ] arg                    var=val -pre-define variables
  -p [ --p ] arg                    customizer parameter file
  -P [ --P ] arg                    customizer parameter set
  --enable arg                      enable experimental features (specify 'all'
                                    for enabling all available features): roof
                                    | input-driver-dbus | lazy-union |
                                    vertex-object-renderers-indexing |
                                    textmetrics | import-function |
                                    predictible-output

  -h [ --help ]                     print this help message and exit
  --help-export                     print list of export parameters and values
                                    that can be set via -O
  -v [ --version ]                  print the version
  --info                            print information about the build process

  --camera arg                      camera parameters when exporting png:
                                    =translate_x,y,z,rot_x,y,z,dist or
                                    =eye_x,y,z,center_x,y,z
  --autocenter                      adjust camera to look at object's center
  --viewall                         adjust camera to fit object
  --backend arg                     3D rendering backend to use: 'CGAL'
                                    (old/slow) [default] or 'Manifold'
                                    (new/fast)
  --imgsize arg                     =width,height of exported png
  --render arg                      for full geometry evaluation when exporting
                                    png
  --preview arg                     [=throwntogether] -for ThrownTogether
                                    preview png
  --animate arg                     export N animated frames
  --animate_sharding arg            Parameter <shard>/<num_shards> - Divide
                                    work into <num_shards> and only output
                                    frames for <shard>. E.g. 2/5 only outputs
                                    the second 1/5 of frames. Use to
                                    parallelize work on multiple cores or
                                    machines.
  --view arg                        =view options: axes | crosshairs | edges |
                                    scales
  --projection arg                  =(o)rtho or (p)erspective when exporting
                                    png
  --csglimit arg                    =n -stop rendering at n CSG elements when
                                    exporting png
  --summary arg                     enable additional render summary and
                                    statistics: all | cache | time | camera |
                                    geometry | bounding-box | area
  --summary-file arg                output summary information in JSON format
                                    to the given file, using '-' outputs to
                                    stdout
  --colorscheme arg                 =colorscheme: *Cornfield | Metallic |
                                    Sunset | Starnight | BeforeDawn | Nature |
                                    Daylight Gem | Nocturnal Gem | DeepOcean |
                                    Solarized | Tomorrow | Tomorrow Night |
                                    ClearSky | Monotone

  -d [ --d ] arg                    deps_file -generate a dependency file for
                                    make
  -m [ --m ] arg                    make_cmd -runs make_cmd file if file is
                                    missing
  -q [ --quiet ]                    quiet mode (don't print anything *except*
                                    errors)
  --hardwarnings                    Stop on the first warning
  --trace-depth arg                 =n, maximum number of trace messages
  --trace-usermodule-parameters arg =true/false, configure the output of user
                                    module parameters in a trace
  --check-parameters arg            =true/false, configure the parameter check
                                    for user modules and functions
  --check-parameter-ranges arg      =true/false, configure the parameter range
                                    check for builtin modules
  --debug arg                       special debug info - specify 'all' or a set
                                    of source file names
  -s [ --s ] arg                    stl_file deprecated, use -o
  -x [ --x ] arg                    dxf_file deprecated, use -o
</pre>

### PNG export: `--camera` must be comma-separated (one argv)

OpenSCAD parses **`--camera`** as a **single** string of **comma-separated** numbers (`translate_x,y,z,rot_x,y,z,dist` or `eye_x,y,z,center_x,y,z`). **Spaces are not separators** — if you pass multiple shell tokens, the CLI mis-parses flags or ignores the camera.

- **Correct:** `--camera=0,0,0,90,0,0,500` or `--camera "0,0,0,0,0,0,300"`
- **Wrong:** `--camera 0 0 0 90 0 0 500` (seven arguments; not valid)

**Prefer** the repo QA helpers (`.agents/skills/verify-design/scripts/qa-zoom.sh` with `VIEW=top DIST=…`, etc.) so you do not hand-assemble `--camera` strings.

### `QA_VIEWPORT` console line (openscad-playground convention)

**Machine-readable spec:** `.agents/skills/verify-design/data/qa-viewport-format.json`  
**Shared parser / CLI:** `.agents/skills/verify-design/scripts/qa_viewport_format.py` (e.g. `camera-csv-from-text` reads a log on stdin and prints the seven-value `--camera=` CSV)

With **`qa_dump_viewport = true`** in the project's `<project>_qa.scad`, F5 echoes a line such as:

`QA_VIEWPORT 0,0,0,126,324,35,330,17,perspective`

Parse it as **`$vpt` (3) + `$vpr` (3) + `$vpd` (1) + `mode` (1) + `qa_capture_projection` (string)** — see the `echo(str("QA_VIEWPORT ", …))` in the project's `qa.scad.template`. The **eighth numeric field is the active `mode`**, not an extra camera parameter.

- **Headless `--camera=`:** use **only the first seven comma-separated numbers** (same token as `qa-zoom.sh` `CAMERA=tx,ty,tz,rx,ry,rz,dist`).
- **Projection:** match the GUI with **`--projection=ortho`** or **`--projection=perspective`**. **`qa-zoom.sh`** always exports ortho; for a perspective PNG, call **`openscad`** directly with **`--projection=perspective`** and the same seven-number camera.
- **Which part:** the echoed **`mode`** is the same as **`-D mode=N`** and matches an entry in the project's `repl-config.json` `modes` array.

**`--autocenter` is not implicit on the CLI.** OpenSCAD does **not** turn it on by default for PNG export. The workbench's **`qa-views.sh` / `qa-zoom.sh` / `qa-orbit.sh`** ortho renders all pass **`--projection=ortho --autocenter`** so the camera target stays on the model; hand-written commands should do the same unless you intentionally want world-fixed framing.

**`--render` (2025.x):** Some builds expect `--render` with a value (e.g. `--render=true`) for full CGAL PNG export; if `-o file.png` produces no file and no clear error, try `--render=true` or check `OpenSCAD --help` for your build.

### Where to write PNGs (agents)

**Do not use `/tmp`** for design QA screenshots. Paths there are opaque, session-local, and annoying to reference or prune next to real QA work.

- **Preferred:** run **`.agents/skills/verify-design/scripts/qa-views.sh`** / **`qa-zoom.sh`** / etc.; they write under **`build/qa/…`** and print **`QA dir:`**.
- **Ad-hoc `openscad -o …`:** set the output to something like **`build/qa/YYYY-MM-DD_HHMM_<short-slug>/shot.png`** (create the directory first). For parity with the QA scripts use **`--render`** (or **`--render=true`** on newer builds), **`--projection=ortho --autocenter --view=axes,scales`**, then **`--camera=…`** and **`-D mode=N`**. Reuse the same folder for follow-up renders in that investigation.
- **`build/`** is gitignored; delete old **`build/qa/*`** folders whenever you want to reclaim disk (nothing under `/tmp`).

**Blank viewport vs broken export:** A **large** PNG can still show **no useful geometry** (camera misses the model, wrong **`-D mode=`**, empty branch). That is **not** the same as a **missing** or **tiny** file. For the former, use **`qa-compile.sh`**, increase **`DIST=`**, or **`QA_DIAG_VIEWALL=1`** with **`qa-views.sh`** / **`qa-zoom.sh`** (writes **`*_viewall.png`** using **`--viewall`** to auto-fit). Overlap **mode 14** CGAL PNGs are **monochrome**; color-coded overlap is **F6** in the GUI.

Export help
<pre>
OpenSCAD version 2025.08.17

List of settings that can be given using the -O option using the
format '<section>/<key>=value', e.g.:
openscad -O export-pdf/paper-size=a6 -O export-pdf/show-grid=false

Section 'export-pdf':
  - paper-size (enum): [a6,a5,<a4>,a3,letter,legal,tabloid]
  - orientation (enum): [<portrait>,landscape,auto]
  - show-filename (bool): <true>/false
  - show-scale (bool): <true>/false
  - show-scale-message (bool): <true>/false
  - show-grid (bool): <true>/false
  - grid-size (double): 1.000000 : <10.000000> : 100.000000
  - add-meta-data (bool): <true>/false
  - meta-data-title (string): ""
  - meta-data-author (string): ""
  - meta-data-subject (string): ""
  - meta-data-keywords (string): ""
Section 'export-3mf':
  - color-mode (enum): [<model>,none,selected-only]
  - unit (enum): [micron,<millimeter>,centimeter,meter,inch,foot]
  - color (string): "#f9d72c"
  - material-type (enum): [color,<basematerial>]
  - decimal-precision (int): 1 : <6> : 16
  - add-meta-data (bool): <true>/false
  - meta-data-title (string): ""
  - meta-data-designer (string): ""
  - meta-data-description (string): ""
  - meta-data-copyright (string): ""
  - meta-data-license-terms (string): ""
  - meta-data-rating (string): ""
</pre>



OpenSCAD 2021.01 has these options:
 Usage: openscad [options] file.scad
 Allowed options:
  --export-format arg          overrides format of exported scad file when
                               using option '-o', arg can be any of its
                               supported file extensions.  For ascii stl
                               export, specify 'asciistl', and for binary stl
                               export, specify 'binstl'.  Ascii export is the
                               current stl default, but binary stl is planned
                               as the future default so asciistl should be
                               explicitly specified in scripts when needed.
  
  -o [ --o ] arg               output specified file instead of running the
                               GUI, the file extension specifies the type: stl,
                               off, wrl, amf, 3mf, csg, dxf, svg, pdf, png,
                               echo, ast, term, nef3, nefdbg (May be used
                               multiple time for different exports). Use '-'
                               for stdout
  
  -D [ --D ] arg               var=val -pre-define variables
  -p [ --p ] arg               customizer parameter file
  -P [ --P ] arg               customizer parameter set
  --enable arg                 enable experimental features (specify 'all' for
                               enabling all available features): roof |
                               input-driver-dbus | lazy-union |
                               vertex-object-renderers |
                               vertex-object-renderers-indexing |
                               vertex-object-renderers-direct |
                               vertex-object-renderers-prealloc | textmetrics
  
  -h [ --help ]                print this help message and exit
  -v [ --version ]             print the version
  --info                       print information about the build process
  
  --camera arg                 camera parameters when exporting png:
                               =translate_x,y,z,rot_x,y,z,dist or
                               =eye_x,y,z,center_x,y,z
  --autocenter                 adjust camera to look at object's center
  --viewall                    adjust camera to fit object
  --imgsize arg                =width,height of exported png
  --render                     for full geometry evaluation when exporting png
  --preview arg                [=throwntogether] -for ThrownTogether preview
                               png
  --animate arg                export N animated frames
  --view arg                   =view options: axes | crosshairs | edges |
                               scales | wireframe
  --projection arg             =(o)rtho or (p)erspective when exporting png
  --csglimit arg               =n -stop rendering at n CSG elements when
                               exporting png
  --summary arg                enable additional render summary and statistics:
                               all | cache | time | camera | geometry |
                               bounding-box | area
  --summary-file arg           output summary information in JSON format to the
                               given file, using '-' outputs to stdout
  --colorscheme arg            =colorscheme: *Cornfield | Metallic | Sunset |
                               Starnight | BeforeDawn | Nature | DeepOcean |
                               Solarized | Tomorrow | Tomorrow Night | Monotone
  
  -d [ --d ] arg               deps_file -generate a dependency file for make
  -m [ --m ] arg               make_cmd -runs make_cmd file if file is missing
  -q [ --quiet ]               quiet mode (don't print anything *except*
                               errors)
  --hardwarnings               Stop on the first warning
  --check-parameters arg       =true/false, configure the parameter check for
                               user modules and functions
  --check-parameter-ranges arg =true/false, configure the parameter range check
                               for builtin modules
  --debug arg                  special debug info - specify 'all' or a set of
                               source file names


## openscad-playground — STL export and print modes

Batch-export printable STLs for the active project (same `-D "mode=N"` as the
project's entry SCAD in the GUI):

- **`scripts/export_parts.sh`** — Exports every `repl-config.json` mode with
  `type: "print"` (`tests`, `all`, or explicit mode numbers also accepted).
  Output: `projects/<slug>/build/<STL_NAME>.stl`. Set **`OPENSCAD`** if the
  binary path differs.

PNG / ortho QA scripts (`.agents/skills/verify-design/scripts/`) use the same
`mode` values. They write PNGs under **`projects/<slug>/build/qa/…`** — do
not send QA screenshots to **`/tmp`** (see **"Where to write PNGs"** above).
