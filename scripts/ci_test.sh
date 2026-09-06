#!/usr/bin/env bash
# Source-only CI. Does not touch /srv/arcade, RetroArch, or lobbies.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

python3 scripts/assert-no-content.py
python3 -m unittest discover -s scripts -p 'test_*.py' -v
