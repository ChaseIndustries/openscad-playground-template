"""Resolve declarative `fit:` specs on qa-part-views.json shots to concrete distances.

A shot entry can specify one of:
    {"view": "iso_fr_lo", "dist": 120}             # legacy, baked
    {"camera": "tx,ty,tz,rx,ry,rz,dist"}           # legacy, baked
    {"view": "iso_fr_lo", "fit": "viewall"}        # auto-fit at render time
    {"view": "iso_fr_lo", "fit": {"scale": 1.25}}  # viewall * scale

`fit` forms call OpenSCAD once per unique (mode, view) to read
`camera.distance` from `--summary all --viewall`, then cache in-process.

Public API:
    viewall_distance(mode, view, openscad_bin=None, project_dir=None,
                     entry_scad=None) -> float | None
    resolve_fit(mode, view, fit, openscad_bin=None, project_dir=None,
                entry_scad=None) -> float | None
    VIEW_PRESETS
"""
from __future__ import annotations

import json
import os
import subprocess
import tempfile

VIEW_PRESETS: dict[str, tuple[float, float, float, float, float, float]] = {
    "top": (0, 0, 0, 0, 0, 0),
    "bottom": (0, 0, 0, 180, 0, 0),
    "front": (0, 0, 0, 90, 0, 0),
    "back": (0, 0, 0, 90, 0, 180),
    "left": (0, 0, 0, 90, 0, -90),
    "right": (0, 0, 0, 90, 0, 90),
    "iso_fr": (0, 0, 0, 55, 0, 25),
    "iso_fl": (0, 0, 0, 55, 0, -25),
    "iso_br": (0, 0, 0, 55, 0, 155),
    "iso_bl": (0, 0, 0, 55, 0, -155),
    "iso_fr_hi": (0, 0, 0, 70, 0, 25),
    "iso_fl_hi": (0, 0, 0, 70, 0, -25),
    "iso_br_hi": (0, 0, 0, 70, 0, 155),
    "iso_bl_hi": (0, 0, 0, 70, 0, -155),
    "iso_fr_lo": (0, 0, 0, 30, 0, 25),
    "iso_fl_lo": (0, 0, 0, 30, 0, -25),
    "iso_br_lo": (0, 0, 0, 30, 0, 155),
    "iso_bl_lo": (0, 0, 0, 30, 0, -155),
}

_viewall_cache: dict[tuple[int, str, str], float] = {}


def _resolve_project_dir(project_dir: str | None) -> str:
    if project_dir:
        return project_dir
    env = os.environ.get("PLAYGROUND_PROJECT_DIR")
    if env and os.path.isdir(env):
        return env
    return os.getcwd()


def _resolve_entry_scad(entry_scad: str | None) -> str:
    if entry_scad:
        return entry_scad
    return os.environ.get("PROJECT_SCAD") or "project.scad"


def _resolve_openscad(openscad_bin: str | None) -> str:
    if openscad_bin:
        return openscad_bin
    return os.environ.get("OPENSCAD") or "openscad"


def viewall_distance(
    mode: int,
    view: str,
    openscad_bin: str | None = None,
    project_dir: str | None = None,
    entry_scad: str | None = None,
) -> float | None:
    pd = _resolve_project_dir(project_dir)
    scad = _resolve_entry_scad(entry_scad)
    key = (int(mode), str(view), scad)
    if (cached := _viewall_cache.get(key)) is not None:
        return cached
    if view not in VIEW_PRESETS:
        return None
    binpath = _resolve_openscad(openscad_bin)
    tx, ty, tz, rx, ry, rz = VIEW_PRESETS[view]
    cam = f"{tx},{ty},{tz},{rx},{ry},{rz},999"
    with tempfile.TemporaryDirectory(prefix="qa_fit.") as tmp:
        jsn = os.path.join(tmp, "cam.json")
        png = os.path.join(tmp, "cam.png")
        try:
            subprocess.run(
                [
                    binpath, "--summary", "all", "--summary-file", jsn,
                    "-o", png, "--render", "--imgsize=64,64",
                    "--projection=ortho", "--autocenter", "--viewall",
                    f"--camera={cam}", "-D", f"mode={int(mode)}", scad,
                ],
                cwd=pd, capture_output=True, text=True, check=True,
            )
        except (subprocess.CalledProcessError, FileNotFoundError):
            return None
        if not os.path.isfile(jsn):
            return None
        try:
            with open(jsn, encoding="utf-8") as f:
                data = json.load(f)
        except (OSError, json.JSONDecodeError):
            return None
    cam_info = data.get("camera") or {}
    dist = cam_info.get("distance")
    if dist is None:
        return None
    val = float(dist)
    _viewall_cache[key] = val
    return val


def resolve_fit(
    mode: int,
    view: str,
    fit: object,
    openscad_bin: str | None = None,
    project_dir: str | None = None,
    entry_scad: str | None = None,
) -> float | None:
    va = viewall_distance(mode, view, openscad_bin, project_dir, entry_scad)
    if va is None:
        return None
    if fit == "viewall" or fit is True:
        return va
    if isinstance(fit, dict):
        scale = 1.0
        if "scale" in fit:
            try:
                scale = float(fit["scale"])
            except (TypeError, ValueError):
                return None
        if "viewall" in fit or "scale" in fit:
            return va * scale
    return None


def clear_cache() -> None:
    _viewall_cache.clear()
