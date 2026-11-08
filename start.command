#!/usr/bin/env bash
cd "$(dirname "$0")"

if command -v python3 >/dev/null 2>&1; then
    python3 "./core/unlock.py"
elif command -v python >/dev/null 2>&1; then
    python "./core/unlock.py"
elif command -v pwsh >/dev/null 2>&1; then
    pwsh -NoProfile -ExecutionPolicy Bypass -File "./core/unlock.ps1"
else
    echo "========================================================================="
    echo "  [!] Python 3 not found / Python 3 bulunamadi."
    echo "========================================================================="
    read -p "Press Enter to exit / Cikmak icin Enter'a basin..."
    exit 1
fi

echo ""
read -p "Press Enter to exit / Cikmak icin Enter'a basin..."
