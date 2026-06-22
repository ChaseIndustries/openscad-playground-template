#!/usr/bin/env python3
"""
Canonical parser for the Cyberdeck QA_VIEWPORT console line.

Spec: .agents/skills/verify-design/data/qa-viewport-format.json
Producer: Cyberdeck.scad (echo when qa_dump_viewport is true).

The line looks like:
  QA_VIEWPORT 0,0,0,126,324,35,330,17,perspective

Only the first seven comma-separated values are valid for OpenSCAD --camera=.
Fields 8–9 (optional) are mode and qa_capture_projection.
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from dataclasses import dataclass

QA_VIEWPORT_PREFIX = "QA_VIEWPORT"
QA_VIEWPORT_RE = re.compile(r"QA_VIEWPORT\s+(.+)", re.I)

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_SPEC_JSON = os.path.normpath(
    os.path.join(_SCRIPT_DIR, "..", "data", "qa-viewport-format.json")
)


@dataclass(frozen=True)
class ParsedQaViewport:
    vpt: tuple[float, float, float]
    vpr: tuple[float, float, float]
    vpd: float
    mode: int | None = None
    projection: str | None = None

    def camera_csv(self) -> str:
        """Seven-value string for --camera= / qa-part-views.json (normalized)."""
        return _normalize_seven_csv(
            [self.vpt[0], self.vpt[1], self.vpt[2], self.vpr[0], self.vpr[1], self.vpr[2], self.vpd]
        )


def _normalize_seven_csv(nums: list[float]) -> str:
    if len(nums) != 7:
        raise ValueError("internal: expected 7 floats for camera csv")
    out: list[str] = []
    for i, x in enumerate(nums):
        if i < 6:
            out.append(str(int(x)) if x == int(x) else str(x))
        else:
            out.append(str(int(round(x))))
    return ",".join(out)


def parse_viewport_csv_blob(blob: str) -> ParsedQaViewport:
    """
    Parse the comma-separated payload after 'QA_VIEWPORT ' (7–9 fields).
    Raises ValueError with a short message if invalid.
    """
    blob = blob.strip().strip('"').strip("'")
    parts = [p.strip() for p in blob.split(",") if p.strip()]
    if len(parts) < 7:
        raise ValueError(
            f"expected at least 7 comma-separated fields (camera), got {len(parts)}: {parts!r}"
        )
    if len(parts) > 9:
        raise ValueError(
            f"expected at most 9 fields (camera + optional mode + projection), got {len(parts)}"
        )
    try:
        nums = [float(x) for x in parts[:7]]
    except ValueError as e:
        raise ValueError(f"first seven QA_VIEWPORT fields must be numeric: {e}") from e
    vpt = (nums[0], nums[1], nums[2])
    vpr = (nums[3], nums[4], nums[5])
    vpd = nums[6]

    mode: int | None = None
    projection: str | None = None
    if len(parts) >= 8:
        try:
            mode = int(float(parts[7]))
        except ValueError:
            projection = parts[7]
    if len(parts) >= 9:
        projection = parts[8]

    return ParsedQaViewport(vpt=vpt, vpr=vpr, vpd=vpd, mode=mode, projection=projection)


def parse_qa_viewport_line(combined_text: str) -> ParsedQaViewport | None:
    """Find QA_VIEWPORT in multiline OpenSCAD output; return None if missing or unparseable."""
    m = QA_VIEWPORT_RE.search(combined_text)
    if not m:
        return None
    try:
        return parse_viewport_csv_blob(m.group(1))
    except ValueError:
        return None


def parse_paste_line_flexible(line: str) -> ParsedQaViewport:
    """
    Accept a full QA_VIEWPORT line or a raw CSV (7–9 fields).
    Used by interactive paste and orbit tooling.
    """
    line = line.strip()
    m = QA_VIEWPORT_RE.search(line)
    blob = m.group(1).strip() if m else line
    return parse_viewport_csv_blob(blob)


def parse_viewport_input_to_camera_csv(raw: str) -> str | None:
    """Like qa-repl _parse_viewport_csv: return normalized 7-field CSV or None."""
    raw = raw.strip()
    if not raw:
        return None
    try:
        return parse_paste_line_flexible(raw).camera_csv()
    except ValueError:
        return None


def _main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description="Parse Cyberdeck QA_VIEWPORT echo lines.")
    sub = p.add_subparsers(dest="cmd", required=True)

    p_cam = sub.add_parser(
        "camera-csv-from-text",
        help="Read stdin (OpenSCAD log); print normalized 7-value --camera= CSV on stdout",
    )
    p_cam.add_argument(
        "--quiet-errors",
        action="store_true",
        help="Do not print errors to stderr (still exits non-zero)",
    )

    sub.add_parser("spec-path", help="Print path to qa-viewport-format.json")

    args = p.parse_args(argv)
    if args.cmd == "spec-path":
        print(_SPEC_JSON)
        return 0
    if args.cmd == "camera-csv-from-text":
        text = sys.stdin.read()
        parsed = parse_qa_viewport_line(text)
        if parsed is None:
            first = text.strip().split("\n", 1)[0].strip()
            try:
                parsed = parse_paste_line_flexible(first)
            except ValueError:
                parsed = None
        if parsed is None:
            if not args.quiet_errors:
                if not QA_VIEWPORT_RE.search(text) and not text.strip():
                    print(
                        "ERROR: empty stdin (paste QA_VIEWPORT line or 7–9 field camera CSV)",
                        file=sys.stderr,
                    )
                elif not QA_VIEWPORT_RE.search(text):
                    print(
                        "ERROR: could not parse QA_VIEWPORT or raw 7–9 field CSV from first line",
                        file=sys.stderr,
                    )
                else:
                    print(
                        "ERROR: QA_VIEWPORT line present but could not parse 7–9 fields",
                        file=sys.stderr,
                    )
            return 1
        print(parsed.camera_csv())
        return 0
    return 2


if __name__ == "__main__":
    raise SystemExit(_main(sys.argv[1:]))
