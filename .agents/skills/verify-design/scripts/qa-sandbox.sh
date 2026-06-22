#!/usr/bin/env bash
# qa-sandbox.sh — run QA commands in an isolated per-project sandbox.
#
# Creates a temp dir mirroring the active project directory (symlinks +
# private qa.scad) so agents can freely change camera/mode/visibility
# without disturbing the user's GUI session or another agent.
#
# Forms:
#   bash qa-sandbox.sh -- bash qa-zoom.sh 5 build/qa/sess
#   eval "$(bash qa-sandbox.sh --env)"     # exports PLAYGROUND_PROJECT_DIR + QA_SANDBOX
#   SANDBOX=$(bash qa-sandbox.sh --create)
#   bash qa-sandbox.sh --cleanup "$SANDBOX"
set -euo pipefail

_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=./qa-project.sh
source "${_SCRIPT_DIR}/qa-project.sh"
# shellcheck source=./qa-common.sh
source "${_SCRIPT_DIR}/qa-common.sh"

show_help() {
  cat <<'EOF'
qa-sandbox.sh — isolated QA environment for agents.

Modes:
  --create              Print sandbox path; caller must clean up
  --cleanup <path>      Remove a sandbox created by --create
  --env                 Print eval-able shell exports (PLAYGROUND_PROJECT_DIR + QA_SANDBOX)
  -- <command> [args]   Run command with PLAYGROUND_PROJECT_DIR=sandbox; auto-cleanup

The sandbox symlinks everything from the active project dir except
<project>.scad (copied) and <project>_qa.scad (fresh from template).
Set PLAYGROUND_PROJECT=<slug> first if you're outside a projects/<slug>/ dir.
EOF
}

case "${1:-}" in
  -h|--help) show_help; exit 0 ;;
  --create)
    qa_project_resolve || exit $?
    qa_create_sandbox
    ;;
  --cleanup)
    qa_cleanup_sandbox "${2:?Usage: qa-sandbox.sh --cleanup <sandbox_path>}"
    ;;
  --env)
    qa_project_resolve || exit $?
    sandbox=$(qa_create_sandbox)
    printf 'export PLAYGROUND_PROJECT=%q\n' "$PLAYGROUND_PROJECT"
    printf 'export PLAYGROUND_PROJECT_DIR=%q\n' "$sandbox"
    printf 'export QA_SANDBOX=%q\n' "$sandbox"
    ;;
  --)
    shift
    if [[ $# -eq 0 ]]; then echo "ERROR: no command after --" >&2; exit 1; fi
    qa_project_resolve || exit $?
    sandbox=$(qa_create_sandbox)
    trap 'qa_cleanup_sandbox "$sandbox"' EXIT
    export PLAYGROUND_PROJECT
    export PLAYGROUND_PROJECT_DIR="$sandbox"
    "$@"
    ;;
  *)
    echo "ERROR: unknown option '${1:-}'. Use --help." >&2
    exit 1 ;;
esac
