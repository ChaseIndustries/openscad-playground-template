#!/usr/bin/env python3
"""Thin entry point — delegates to the skill's qa-repl.py."""
import os, sys
SKILL = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    ".agents", "skills", "verify-design", "scripts", "qa-repl.py",
)
os.execv(sys.executable, [sys.executable, SKILL, *sys.argv[1:]])
