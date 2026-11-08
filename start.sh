#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if command -v python3 >/dev/null 2>&1; then
    python3 "$SCRIPT_DIR/core/unlock.py" "$@"
elif command -v python >/dev/null 2>&1; then
    python "$SCRIPT_DIR/core/unlock.py" "$@"
elif command -v pwsh >/dev/null 2>&1; then
    pwsh -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/core/unlock.ps1" "$@"
else
    echo "========================================================================="
    echo "  [!] Python 3 not found / Python 3 bulunamadi."
    echo "========================================================================="
    echo "  Please ensure Python 3 is installed on your system."
    echo "  Lutfen sistem terminalinizde Python 3 kurulu oldugundan emin olun."
    echo "========================================================================="
    exit 1
fi
