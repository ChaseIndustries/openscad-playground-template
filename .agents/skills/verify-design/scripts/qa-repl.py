#!/usr/bin/env python3
"""
Generic openscad-playground REPL — a config-driven TTY control panel that
edits the active project's <project>_qa.scad live so OpenSCAD auto-reloads.

Each project declares what to surface in the REPL via projects/<slug>/repl-config.json:

    {
      "parts": [
        {"idx": 1, "name": "Body",  "slug": "body",  "group": "Main"},
        {"idx": 2, "name": "Cover", "slug": "cover", "group": "Main"}
      ],
      "modes": [
        {"id": 0, "name": "Closed",         "type": "pose"},
        {"id": 1, "name": "Open",           "type": "pose"},
        {"id": 5, "name": "Print: body",    "type": "print", "stl_name": "PRINT_BODY"},
        {"id": 6, "name": "Print: cover",   "type": "print", "stl_name": "PRINT_COVER"}
      ],
      "variables": [
        {"name": "lid_angle",  "type": "float", "label": "Lid angle",
         "min": 0, "max": 130, "step": 5, "default": 0},
        {"name": "show_color_coded", "type": "bool", "label": "Color-code parts",
         "default": true}
      ],
      "color_schemes": ["qa", "mono"]
    }

The REPL writes to projects/<slug>/<project>_qa.scad. The first `mode = N;`
line below the `// QA_REPL_MODE` marker is what gets rewritten when you
switch modes; every variable from `variables` gets its own `name = value;`
line that the REPL rewrites in place.

Install: pip install -r .agents/skills/verify-design/scripts/requirements-qa-repl.txt

Env: PLAYGROUND_PROJECT, PLAYGROUND_PROJECT_DIR, OPENSCAD.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

QA_REPL_MARKER = "// QA_REPL_MODE"

# ── Panel colors (inline prompt_toolkit styles; ANSI names for broad support) ──
C_TITLE = "bold fg:ansibrightcyan"
C_XRAY = "bold fg:ansibrightmagenta"
C_DIM = "fg:ansibrightblack"
C_MSG = "bold fg:ansibrightgreen"
C_HEAD = "bold fg:ansicyan"
C_ACTIVE = "bold fg:ansibrightgreen"   # the selected mode / color scheme
C_FOCUS = "reverse bold"               # the arrow-key cursor
C_GROUP = "italic fg:ansiblue"
C_HOTKEY = "fg:ansiyellow"
C_ON = "fg:ansibrightgreen"            # visible part [x]
C_OFF = "fg:ansibrightblack"           # hidden part [ ]

# ── Project resolution ──────────────────────────────────────────────


def _workbench_root() -> Path:
    here = Path(__file__).resolve()
    for p in [here, *here.parents]:
        if (p / "projects").is_dir() and (p / ".agents/skills/verify-design").is_dir():
            return p
    raise SystemExit("ERROR: cannot find openscad-playground workbench root")


def _resolve_project(root: Path) -> str:
    env = os.environ.get("PLAYGROUND_PROJECT")
    if env:
        return env
    cwd = Path.cwd().resolve()
    try:
        rel = cwd.relative_to(root / "projects")
        return rel.parts[0]
    except ValueError:
        pass
    pointer = root / ".playground-active"
    if pointer.is_file():
        line = pointer.read_text(encoding="utf-8").strip().splitlines()[0].strip()
        if line:
            return line
    only = [
        p.name
        for p in (root / "projects").iterdir()
        if p.is_dir() and not p.name.startswith(".")
    ]
    if len(only) == 1:
        return only[0]
    print("ERROR: no active project; set PLAYGROUND_PROJECT or run from projects/<slug>/", file=sys.stderr)
    print("Available:", file=sys.stderr)
    for name in only:
        print(f"  {name}", file=sys.stderr)
    sys.exit(2)


def _load_playground_config(project_dir: Path, slug: str) -> dict:
    cfg = project_dir / "playground.json"
    data = {}
    if cfg.is_file():
        with open(cfg, encoding="utf-8") as f:
            data = json.load(f)
    data.setdefault("scad_entry", f"{slug}.scad")
    data.setdefault("qa_scad", f"{slug}_qa.scad")
    data.setdefault("qa_scad_template", data["qa_scad"] + ".template")
    return data


def _load_repl_config(project_dir: Path) -> dict:
    cfg = project_dir / "repl-config.json"
    if not cfg.is_file():
        return {"parts": [], "modes": [], "variables": [], "color_schemes": []}
    with open(cfg, encoding="utf-8") as f:
        return json.load(f)


def _ensure_qa_scad(project_dir: Path, qa_scad: str, template: str) -> Path:
    dest = project_dir / qa_scad
    if dest.is_file():
        return dest
    tmpl = project_dir / template
    if not tmpl.is_file():
        print(f"ERROR: missing QA template {tmpl}", file=sys.stderr)
        sys.exit(2)
    shutil.copyfile(tmpl, dest)
    print(f"Created {dest} from {tmpl.name}", file=sys.stderr)
    return dest


# ── SCAD variable read/write ────────────────────────────────────────


def _read_text(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def _write_text(p: Path, s: str) -> None:
    p.write_text(s, encoding="utf-8")


def _read_numeric_mode(qa_path: Path) -> int | None:
    text = _read_text(qa_path)
    last = None
    for line in text.splitlines():
        s = re.sub(r"//.*", "", line).strip()
        if re.match(r"mode\s*=", s):
            last = s
    if not last:
        return None
    m = re.search(r"mode\s*=\s*(\d+)\s*;?\s*$", last)
    return int(m.group(1)) if m else None


def _write_numeric_mode(qa_path: Path, mode: int) -> None:
    text = _read_text(qa_path)
    lines = text.splitlines(keepends=True)
    marker_idx = None
    for i, line in enumerate(lines):
        if line.strip().startswith(QA_REPL_MARKER):
            marker_idx = i
            break
    if marker_idx is None:
        raise SystemExit(f"ERROR: {qa_path} has no {QA_REPL_MARKER!r} line")
    for j in range(marker_idx + 1, len(lines)):
        raw = lines[j]
        s = re.sub(r"//.*", "", raw).strip()
        if not s:
            continue
        if re.match(r"mode\s*=\s*\d+\s*;", s):
            indent = re.match(r"^(\s*)", raw).group(1)
            nl = "\n" if raw.endswith("\n") else ""
            lines[j] = f"{indent}mode = {mode};{nl}"
            _write_text(qa_path, "".join(lines))
            return
    raise SystemExit(f"ERROR: no `mode = N;` after {QA_REPL_MARKER!r} in {qa_path}")


def _read_var_bool(qa_path: Path, var: str, default: bool) -> bool:
    # Anchored to line start (like the writer) so a commented `//var = …` line
    # or a substring of a longer name is never matched.
    m = re.search(rf"^\s*{re.escape(var)}\s*=\s*(true|false)\s*;",
                  _read_text(qa_path), flags=re.MULTILINE)
    return (m.group(1) == "true") if m else default


def _write_var_bool(qa_path: Path, var: str, val: bool) -> None:
    text = _read_text(qa_path)
    val_s = "true" if val else "false"
    new_text, n = re.subn(
        rf"^(\s*){re.escape(var)}\s*=\s*(?:true|false)\s*;",
        rf"\g<1>{var} = {val_s};",
        text,
        flags=re.MULTILINE,
    )
    if n == 0:
        new_text = text.rstrip("\n") + f"\n{var} = {val_s};\n"
    _write_text(qa_path, new_text)


def _read_var_float(qa_path: Path, var: str, default: float) -> float:
    m = re.search(rf"^\s*{re.escape(var)}\s*=\s*(-?\d+(?:\.\d+)?)\s*;",
                  _read_text(qa_path), flags=re.MULTILINE)
    return float(m.group(1)) if m else default


def _write_var_float(qa_path: Path, var: str, val: float) -> None:
    text = _read_text(qa_path)
    fmt = f"{val:g}" if val == int(val) else f"{val:.3f}".rstrip("0").rstrip(".")
    new_text, n = re.subn(
        rf"^(\s*){re.escape(var)}\s*=\s*-?\d+(?:\.\d+)?\s*;",
        rf"\g<1>{var} = {fmt};",
        text,
        flags=re.MULTILINE,
    )
    if n == 0:
        new_text = text.rstrip("\n") + f"\n{var} = {fmt};\n"
    _write_text(qa_path, new_text)


def _read_var_int(qa_path: Path, var: str, default: int) -> int:
    m = re.search(rf"^\s*{re.escape(var)}\s*=\s*(-?\d+)\s*;",
                  _read_text(qa_path), flags=re.MULTILINE)
    return int(m.group(1)) if m else default


def _write_var_int(qa_path: Path, var: str, val: int) -> None:
    text = _read_text(qa_path)
    new_text, n = re.subn(
        rf"^(\s*){re.escape(var)}\s*=\s*-?\d+\s*;",
        rf"\g<1>{var} = {val};",
        text,
        flags=re.MULTILINE,
    )
    if n == 0:
        new_text = text.rstrip("\n") + f"\n{var} = {val};\n"
    _write_text(qa_path, new_text)


def _part_var(idx: int) -> str:
    return f"viz_show_part_{idx}"


# ── Panel state ─────────────────────────────────────────────────────


class Panel:
    def __init__(self, slug: str, project_dir: Path, qa_path: Path, repl_cfg: dict):
        self.slug = slug
        self.project_dir = project_dir
        self.qa_path = qa_path
        self.parts: list[dict] = repl_cfg.get("parts") or []
        self.modes: list[dict] = repl_cfg.get("modes") or []
        self.variables: list[dict] = repl_cfg.get("variables") or []
        self.color_schemes: list[str] = repl_cfg.get("color_schemes") or []

        self.visibility: dict[int, bool] = {
            int(p["idx"]): _read_var_bool(qa_path, _part_var(int(p["idx"])), True)
            for p in self.parts
        }
        cm = _read_numeric_mode(qa_path)
        self.mode: int = cm if cm is not None else (self.modes[0]["id"] if self.modes else 0)
        self.color_idx: int = max(0, _read_var_int(qa_path, "color_scheme", 0))
        if self.color_schemes:
            self.color_idx = self.color_idx % len(self.color_schemes)

        self.var_values: dict[str, object] = {}
        for v in self.variables:
            name = v["name"]
            kind = v.get("type", "float")
            default = v.get("default", 0)
            if kind == "bool":
                self.var_values[name] = _read_var_bool(qa_path, name, bool(default))
            elif kind == "int":
                self.var_values[name] = _read_var_int(qa_path, name, int(default))
            else:
                self.var_values[name] = _read_var_float(qa_path, name, float(default))

        # Xray = see-through preview via viz_opacity (honored by geometry that
        # wraps parts in color(..., viz_opacity)).
        self.xray_opacity = 0.25
        self.xray = _read_var_float(qa_path, "viz_opacity", 1.0) < 0.99

        self.message = ""
        self.cursor = 0

    # ── Mode / pose ──
    def mode_index(self) -> int:
        for i, m in enumerate(self.modes):
            if m["id"] == self.mode:
                return i
        return 0

    def set_mode(self, idx: int) -> None:
        if not self.modes:
            return
        idx %= len(self.modes)
        new_mode = self.modes[idx]["id"]
        self.mode = new_mode
        _write_numeric_mode(self.qa_path, new_mode)
        self.message = f"mode = {new_mode} ({self.modes[idx]['name']})"

    def cycle_mode(self, step: int = 1) -> None:
        self.set_mode(self.mode_index() + step)

    # ── Parts ──
    def toggle_part(self, idx: int) -> None:
        new = not self.visibility.get(idx, True)
        self.visibility[idx] = new
        _write_var_bool(self.qa_path, _part_var(idx), new)
        self.message = f"part {idx}: {'show' if new else 'hide'}"

    def set_part(self, idx: int, on: bool) -> None:
        self.visibility[idx] = on
        _write_var_bool(self.qa_path, _part_var(idx), on)
        self.message = f"part {idx}: {'show' if on else 'hide'}"

    def solo_part(self, idx: int) -> None:
        for p in self.parts:
            on = int(p["idx"]) == idx
            self.visibility[int(p["idx"])] = on
            _write_var_bool(self.qa_path, _part_var(int(p["idx"])), on)
        self.message = f"solo part {idx}"

    def show_all_parts(self) -> None:
        for p in self.parts:
            self.visibility[int(p["idx"])] = True
            _write_var_bool(self.qa_path, _part_var(int(p["idx"])), True)
        self.message = "all parts visible"

    # ── Variables ──
    def adjust_var(self, name: str, delta: float | int) -> None:
        spec = next((v for v in self.variables if v["name"] == name), None)
        if not spec:
            return
        kind = spec.get("type", "float")
        if kind == "bool":
            new = not bool(self.var_values.get(name, False))
            self.var_values[name] = new
            _write_var_bool(self.qa_path, name, new)
            self.message = f"{spec.get('label', name)}: {new}"
            return
        cur = self.var_values.get(name, spec.get("default", 0))
        mn = spec.get("min", float("-inf"))
        mx = spec.get("max", float("inf"))
        if kind == "int":
            new_v = int(max(mn, min(mx, int(cur) + int(delta))))
        else:
            new_v = max(mn, min(mx, float(cur) + float(delta)))
        self.var_values[name] = new_v
        if kind == "int":
            _write_var_int(self.qa_path, name, new_v)
        else:
            _write_var_float(self.qa_path, name, new_v)
        self.message = f"{spec.get('label', name)} = {new_v}"

    # ── Color schemes ──
    def cycle_color(self, step: int = 1) -> None:
        if not self.color_schemes:
            return
        self.color_idx = (self.color_idx + step) % len(self.color_schemes)
        _write_var_int(self.qa_path, "color_scheme", self.color_idx)
        self.message = f"color_scheme = {self.color_idx} ({self.color_schemes[self.color_idx]})"

    def set_color(self, idx: int) -> None:
        if not self.color_schemes:
            return
        self.color_idx = idx % len(self.color_schemes)
        _write_var_int(self.qa_path, "color_scheme", self.color_idx)
        self.message = f"color_scheme = {self.color_idx} ({self.color_schemes[self.color_idx]})"

    # ── Xray ──
    def toggle_xray(self) -> None:
        self.xray = not self.xray
        val = self.xray_opacity if self.xray else 1.0
        _write_var_float(self.qa_path, "viz_opacity", val)
        self.message = f"xray {'on' if self.xray else 'off'} (viz_opacity = {val:g})"


# ── Curses / prompt_toolkit UI ──────────────────────────────────────


def _write_global_pointer(root: Path, slug: str, scad_entry: str) -> None:
    """Point the global viewer (playground.scad) at the active project. Open
    playground.scad once in OpenSCAD and it follows whatever this writes."""
    (root / "playground-active.scad").write_text(
        "// AUTO-GENERATED by qa-repl.py / qa-open.sh — do not edit.\n"
        "// Points the global playground.scad viewer at the active project.\n"
        f"include <projects/{slug}/{scad_entry}>;\n",
        encoding="utf-8",
    )


def _open_in_openscad(scad: Path) -> None:
    if sys.platform == "darwin":
        subprocess.call(["open", "-a", "OpenSCAD", str(scad)])
    elif sys.platform.startswith("linux"):
        subprocess.call(["xdg-open", str(scad)])


def run_repl(panel: Panel, scad_entry: str, root: Path) -> str | None:
    """Run the panel for one project. Returns "switch" if the user asked to
    change projects (g), or None to quit (q / Ctrl-C)."""
    try:
        from prompt_toolkit.application import Application, run_in_terminal, get_app
        from prompt_toolkit.key_binding import KeyBindings
        from prompt_toolkit.layout import Layout, HSplit, Window
        from prompt_toolkit.layout.controls import FormattedTextControl
        from prompt_toolkit.formatted_text import FormattedText
    except ImportError:
        print(
            "ERROR: prompt_toolkit not installed. Run:\n"
            "  pip install -r .agents/skills/verify-design/scripts/requirements-qa-repl.txt",
            file=sys.stderr,
        )
        sys.exit(2)

    # Set by the g / q handlers; read after app.run() returns.
    action: dict[str, str | None] = {"value": None}

    def _export(slugs: list[str]) -> None:
        from prompt_toolkit.application import get_app
        export_script = root / "scripts" / "export_parts.sh"

        def do() -> list[tuple[str, int, int]] | None:
            if not export_script.is_file():
                return None
            summary = []
            for s in slugs:
                print(f"\n=== Exporting '{s}' (print parts) ===", flush=True)
                env = dict(os.environ, PLAYGROUND_PROJECT=s)
                ok = fail = 0
                proc = subprocess.Popen(
                    ["bash", str(export_script), "print"], env=env,
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
                for line in proc.stdout:           # stream output live
                    sys.stdout.write(line)
                    m = re.search(r"(\d+) exported, (\d+) failed", line)
                    if m:
                        ok, fail = int(m.group(1)), int(m.group(2))
                proc.wait()
                summary.append((s, ok, fail))
            return summary

        def done(fut) -> None:
            # Runs on the event loop after the terminal is restored, so setting
            # the message + invalidating reliably repaints the panel.
            try:
                summary = fut.result()
            except Exception as exc:  # pragma: no cover
                panel.message = f"export error: {exc}"
                get_app().invalidate()
                return
            if summary is None:
                panel.message = f"export failed: {export_script} not found"
            elif len(summary) == 1:
                s, ok, fail = summary[0]
                panel.message = (f"exported {s}: {ok} STL{'' if ok == 1 else 's'}"
                                 + (f" ({fail} failed)" if fail else ""))
            else:
                total_ok = sum(x[1] for x in summary)
                total_fail = sum(x[2] for x in summary)
                panel.message = (f"exported {len(summary)} projects: {total_ok} STLs"
                                 + (f" ({total_fail} failed)" if total_fail else ""))
            get_app().invalidate()

        # No Enter pause — the done-callback repaints the panel with the summary.
        run_in_terminal(do).add_done_callback(done)

    # Sections present in this project, in display order. The arrow-key cursor
    # moves an item within a section; Tab switches between sections.
    sections: list[str] = []
    if panel.modes:
        sections.append("modes")
    if panel.parts:
        sections.append("parts")
    if panel.variables:
        sections.append("variables")
    if panel.color_schemes:
        sections.append("color")
    if not sections:
        sections = ["modes"]

    # state["sec"] = index into `sections`; state["item"][section] = item index.
    state = {"sec": 0, "item": {s: 0 for s in sections}}

    # var name -> live hotkey letter (populated when bindings are registered; a
    # variable whose requested hotkey collided is absent and shows no letter).
    var_hotkeys: dict[str, str] = {}

    def sec_len(s: str) -> int:
        return {
            "modes": len(panel.modes),
            "parts": len(panel.parts),
            "variables": len(panel.variables),
            "color": len(panel.color_schemes),
        }.get(s, 0)

    def cur_sec() -> str:
        return sections[state["sec"]]

    def focused(s: str, i: int) -> bool:
        return cur_sec() == s and state["item"].get(s, 0) == i

    def _focus(s: str, i: int) -> None:
        # Move the visible cursor to a section/item (used so hotkeys keep the
        # highlight in sync with the thing they just changed).
        if s in state["item"]:
            state["sec"] = sections.index(s)
            state["item"][s] = i

    def render() -> FormattedText:
        out: list[tuple[str, str]] = []
        out.append((C_TITLE, f"openscad-playground — {panel.slug}"))
        out.append((C_XRAY if panel.xray else "", "   [XRAY]\n" if panel.xray else "\n"))
        out.append((C_DIM, f"  {panel.project_dir}\n"))
        out.append((C_DIM, f"  qa: {panel.qa_path.name}\n"))
        # Transient message lives at the top so it is always visible (a tall
        # panel on a short terminal would otherwise clip a bottom message).
        if panel.message:
            out.append((C_MSG, f"  » {panel.message}\n"))
        has_config = bool(panel.modes or panel.parts or panel.variables
                          or panel.color_schemes)
        if has_config:
            out.append((C_DIM,
                        f"  section: {cur_sec()}   (Tab / Shift-Tab to switch)\n"))
        out.append(("", "\n"))

        # Modes — flow across lines, wrapping at the terminal width so a long
        # list stays fully visible and every entry is reachable with the arrows.
        if panel.modes:
            try:
                width = get_app().output.get_size().columns
            except Exception:
                width = 80
            indent = "  "
            out.append((C_HEAD, "Modes:\n"))
            out.append(("", indent))
            col = len(indent)
            for i, m in enumerate(panel.modes):
                tok = f"{'*' if m['id'] == panel.mode else ' '}{m['id']}:{m['name']}  "
                if col + len(tok) > width and col > len(indent):
                    out.append(("", "\n" + indent))
                    col = len(indent)
                if focused("modes", i):
                    style = C_FOCUS
                elif m["id"] == panel.mode:
                    style = C_ACTIVE
                else:
                    style = ""
                out.append((style, tok))
                col += len(tok)
            out.append(("", "\n\n"))

        # Parts
        if panel.parts:
            out.append((C_HEAD, "Parts:\n"))
            seen_groups = set()
            for i, p in enumerate(panel.parts):
                grp = p.get("group", "")
                if grp and grp not in seen_groups:
                    seen_groups.add(grp)
                    out.append((C_GROUP, f"  [{grp}]\n"))
                idx = int(p["idx"])
                vis = panel.visibility.get(idx, True)
                check = "[x]" if vis else "[ ]"
                name = p.get("name", p.get("slug", ""))
                orient = p.get("orient", "")
                if focused("parts", i):
                    line = f"    {check} {idx:>3} {name}"
                    if orient:
                        line += f"    {orient}"
                    out.append((C_FOCUS, line + "\n"))
                else:
                    out.append((C_ON if vis else C_OFF, f"    {check}"))
                    out.append(("", f" {idx:>3} {name}"))
                    if orient:
                        out.append((C_DIM, f"    {orient}"))
                    out.append(("", "\n"))
            out.append(("", "\n"))

        # Variables
        if panel.variables:
            out.append((C_HEAD, "Variables:\n"))
            for i, v in enumerate(panel.variables):
                name = v["name"]
                val = panel.var_values.get(name)
                label = v.get("label", name)
                if v.get("type") == "bool":
                    val_s = "on" if val else "off"
                else:
                    val_s = f"{val}"
                hk = var_hotkeys.get(name)
                key_col = f"[{hk}]" if hk else "   "
                if focused("variables", i):
                    out.append((C_FOCUS, f"  {key_col} {label:30} = {val_s}\n"))
                else:
                    out.append((C_HOTKEY, f"  {key_col}"))
                    out.append(("", f" {label:30} = "))
                    out.append((C_ACTIVE, f"{val_s}\n"))
            out.append(("", "\n"))

        # Color schemes — same width-aware wrapping as Modes.
        if panel.color_schemes:
            try:
                width = get_app().output.get_size().columns
            except Exception:
                width = 80
            indent = "  "
            out.append((C_HEAD, "Color scheme:\n"))
            out.append(("", indent))
            col = len(indent)
            for i, name in enumerate(panel.color_schemes):
                tok = f"{'*' if i == panel.color_idx else ' '}{i}:{name}  "
                if col + len(tok) > width and col > len(indent):
                    out.append(("", "\n" + indent))
                    col = len(indent)
                if focused("color", i):
                    style = C_FOCUS
                elif i == panel.color_idx:
                    style = C_ACTIVE
                else:
                    style = ""
                out.append((style, tok))
                col += len(tok)
            out.append(("", "\n\n"))

        # Single-part / unconfigured project: nothing to tune.
        if not has_config:
            out.append((C_DIM,
                        "  No repl-config.json for this project — nothing to tune.\n"
                        "  Add modes/parts/variables to expose them here.\n\n"))

        # Footer — keys not relevant to this project simply do nothing.
        out.append((C_DIM,
                    "↑/↓ select · ←/→ adjust · Tab section · Enter/Space activate\n"
                    "g switch project · e/E export · x xray · o open in OpenSCAD · q quit\n"
                    "n/p mode · a all parts · c color · 1-9 toggle part · <letter> var\n"))
        return FormattedText(out)

    kb = KeyBindings()

    @kb.add("q")
    @kb.add("c-c")
    def _(event):
        action["value"] = None
        event.app.exit()

    # ── Switch project / export / xray (the global QA console) ──
    @kb.add("g")
    def _(event):
        action["value"] = "switch"
        event.app.exit()

    @kb.add("e")
    def _(event):
        _export([panel.slug])

    @kb.add("E")
    def _(event):
        slugs = sorted(
            p.name
            for p in (root / "projects").iterdir()
            if p.is_dir() and not p.name.startswith(".")
        )
        _export(slugs)

    @kb.add("x")
    def _(event):
        panel.toggle_xray()

    # ── Arrow-key navigation ──
    @kb.add("tab")
    def _(event):
        state["sec"] = (state["sec"] + 1) % len(sections)
        panel.message = f"section: {cur_sec()}"

    @kb.add("s-tab")
    def _(event):
        state["sec"] = (state["sec"] - 1) % len(sections)
        panel.message = f"section: {cur_sec()}"

    @kb.add("down")
    def _(event):
        s = cur_sec()
        n = sec_len(s)
        if n:
            state["item"][s] = (state["item"].get(s, 0) + 1) % n

    @kb.add("up")
    def _(event):
        s = cur_sec()
        n = sec_len(s)
        if n:
            state["item"][s] = (state["item"].get(s, 0) - 1) % n

    @kb.add("enter")
    @kb.add(" ")
    def _(event):
        s = cur_sec()
        i = state["item"].get(s, 0)
        if s == "modes" and panel.modes:
            panel.set_mode(i)
        elif s == "parts" and panel.parts:
            panel.toggle_part(int(panel.parts[i]["idx"]))
        elif s == "variables" and panel.variables:
            v = panel.variables[i]
            if v.get("type") == "bool":
                panel.adjust_var(v["name"], 0)
            else:
                panel.message = f"{v.get('label', v['name'])}: use ←/→ to adjust"
        elif s == "color" and panel.color_schemes:
            panel.set_color(i)

    def _adjust(direction: int) -> None:
        s = cur_sec()
        i = state["item"].get(s, 0)
        if s == "modes" and panel.modes:
            panel.cycle_mode(direction)
            state["item"]["modes"] = panel.mode_index()
        elif s == "parts" and panel.parts:
            panel.set_part(int(panel.parts[i]["idx"]), direction > 0)
        elif s == "variables" and panel.variables:
            v = panel.variables[i]
            if v.get("type") == "bool":
                panel.adjust_var(v["name"], 0)
            else:
                panel.adjust_var(v["name"], v.get("step", 1) * direction)
        elif s == "color" and panel.color_schemes:
            panel.cycle_color(direction)
            state["item"]["color"] = panel.color_idx

    @kb.add("right")
    def _(event):
        _adjust(1)

    @kb.add("left")
    def _(event):
        _adjust(-1)

    # ── Letter / number hotkeys (kept; they also move the cursor) ──
    @kb.add("n")
    def _(event):
        panel.cycle_mode(1)
        _focus("modes", panel.mode_index())

    @kb.add("p")
    def _(event):
        panel.cycle_mode(-1)
        _focus("modes", panel.mode_index())

    @kb.add("c")
    def _(event):
        panel.cycle_color(1)
        _focus("color", panel.color_idx)

    @kb.add("a")
    def _(event):
        panel.show_all_parts()

    @kb.add("o")
    def _(event):
        # Open the global viewer; it follows the active project, so a single
        # OpenSCAD window tracks whatever you switch to with g.
        _open_in_openscad(root / "playground.scad")
        panel.message = "Opened playground.scad in OpenSCAD"

    # Number keys 1..9 toggle the Nth visible part.
    for n in range(1, 10):
        def _make(n: int):
            def _handler(event):
                if 0 <= n - 1 < len(panel.parts):
                    panel.toggle_part(int(panel.parts[n - 1]["idx"]))
                    _focus("parts", n - 1)
            return _handler
        kb.add(str(n))(_make(n))

    # Variable adjustments: lowercase = -step, uppercase = +step, on first letter.
    # Reserved letters are exactly the command keys bound above. A variable whose
    # requested hotkey collides (or is already taken) gets no hotkey — it is still
    # reachable via arrow navigation, and the panel shows which letter is live.
    reserved = {"q", "n", "p", "c", "a", "o", "g", "e", "x"}
    used_letters: set[str] = set()
    for vi, v in enumerate(panel.variables):
        letter = (v.get("hotkey") or v["name"][:1]).lower()
        if not letter or letter in used_letters or letter in reserved:
            continue
        used_letters.add(letter)
        var_hotkeys[v["name"]] = letter
        step = v.get("step", 1)

        def _down(event, name=v["name"], step=step, vi=vi):
            panel.adjust_var(name, -step)
            _focus("variables", vi)

        def _up(event, name=v["name"], step=step, vi=vi):
            panel.adjust_var(name, step)
            _focus("variables", vi)
        kb.add(letter)(_down)
        kb.add(letter.upper())(_up)

    # Modes/Color rows are pre-wrapped at entry boundaries (explicit newlines),
    # so wrap_lines stays False to keep full-screen rendering crisp.
    body = Window(FormattedTextControl(render), wrap_lines=False)
    app = Application(layout=Layout(HSplit([body])), key_bindings=kb, full_screen=True)
    app.run()
    return action["value"]


def _pick_project(root: Path, current: str) -> str | None:
    """Full-screen arrow-key picker for switching projects. Returns the chosen
    slug, or None if cancelled."""
    from prompt_toolkit.application import Application
    from prompt_toolkit.key_binding import KeyBindings
    from prompt_toolkit.layout import Layout, HSplit, Window
    from prompt_toolkit.layout.controls import FormattedTextControl
    from prompt_toolkit.formatted_text import FormattedText

    projects = sorted(
        p.name
        for p in (root / "projects").iterdir()
        if p.is_dir() and not p.name.startswith(".")
    )
    if not projects:
        return None
    state = {"i": projects.index(current) if current in projects else 0,
             "result": None}

    def render() -> FormattedText:
        out: list[tuple[str, str]] = [(C_TITLE, "Switch project\n\n")]
        for j, name in enumerate(projects):
            marker = "*" if name == current else " "
            if j == state["i"]:
                style = C_FOCUS
            elif name == current:
                style = C_ACTIVE
            else:
                style = ""
            out.append((style, f"  {marker} {name}\n"))
        out.append(("", "\n"))
        out.append((C_DIM, "↑/↓ select · Enter switch · Esc/q cancel\n"))
        return FormattedText(out)

    kb = KeyBindings()

    @kb.add("up")
    def _(event):
        state["i"] = (state["i"] - 1) % len(projects)

    @kb.add("down")
    def _(event):
        state["i"] = (state["i"] + 1) % len(projects)

    @kb.add("enter")
    @kb.add(" ")
    def _(event):
        state["result"] = projects[state["i"]]
        event.app.exit()

    @kb.add("q")
    @kb.add("escape")
    @kb.add("c-c")
    def _(event):
        event.app.exit()

    body = Window(FormattedTextControl(render), wrap_lines=False)
    app = Application(layout=Layout(HSplit([body])), key_bindings=kb, full_screen=True)
    app.run()
    return state["result"]


# ── Main ────────────────────────────────────────────────────────────


def main() -> None:
    root = _workbench_root()
    slug = _resolve_project(root)

    # Outer loop: re-enter the panel for a new project when the user presses g.
    while slug:
        project_dir = root / "projects" / slug
        if not project_dir.is_dir():
            raise SystemExit(f"ERROR: project '{slug}' does not exist under {root}/projects/")

        pg_cfg = _load_playground_config(project_dir, slug)
        scad_entry = pg_cfg["scad_entry"]
        qa_scad = pg_cfg["qa_scad"]
        qa_tmpl = pg_cfg["qa_scad_template"]
        if not (project_dir / scad_entry).is_file():
            raise SystemExit(f"ERROR: missing entry SCAD: {project_dir / scad_entry}")

        qa_path = _ensure_qa_scad(project_dir, qa_scad, qa_tmpl)
        repl_cfg = _load_repl_config(project_dir)
        # Keep the global viewer (playground.scad) pointed at this project.
        _write_global_pointer(root, slug, scad_entry)
        panel = Panel(slug, project_dir, qa_path, repl_cfg)
        action = run_repl(panel, scad_entry, root)

        if action == "switch":
            chosen = _pick_project(root, slug)
            if chosen and chosen != slug:
                slug = chosen
                (root / ".playground-active").write_text(slug + "\n", encoding="utf-8")
            # cancelled or same project: just re-enter the same one
            continue
        break  # quit


if __name__ == "__main__":
    main()
