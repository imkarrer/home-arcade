#!/usr/bin/env bash
# Source-only CI. Does not touch /srv/arcade, RetroArch, or lobbies.
#
# Two halves. The source checks are what this tree has always gated. The
# tenant gate (homelab ADR 0009, step 2) proves the flox environment this
# script runs in IS the tenant: the two game servers ac-box runs resolve from
# the environment's own bin, not from whatever the agent happens to have on
# PATH, and each starts far enough to print its version. A green build here
# is what becomes the pushed FloxHub generation the box pulls, so this is the
# last place a manifest that lost a package, or locked a build that does not
# start, can be caught before it is the box's problem.
set -euo pipefail

# FLOX_ENV is set by `flox activate`; without it this script is not running
# where CI and the box run it, and the gate says so rather than testing the
# agent's PATH. First, before the source checks: python comes from the
# environment too, and "python3: command not found" is the wrong message.
: "${FLOX_ENV:?scripts/ci_test.sh must run inside the flox environment (flox activate -- bash scripts/ci_test.sh)}"

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

python3 scripts/assert-no-content.py
python3 -m unittest discover -s scripts -p 'test_*.py' -v

# --- tenant gate -----------------------------------------------------------
for bin in freeciv-server mindustry-server; do
  path="$(command -v "$bin" || true)"
  case "$path" in
    "$FLOX_ENV"/bin/*) echo "tenant: $bin resolves inside the environment ($path)" ;;
    *)
      echo "tenant: $bin does not resolve inside \$FLOX_ENV=$FLOX_ENV (got '${path:-nothing}')" >&2
      exit 1
      ;;
  esac
done

# freeciv-server answers --version without a network or a state directory --
# on STDERR, which is why the redirect is there (without it grep sees nothing
# and set -e ends the script with no message).
freeciv-server --version 2>&1 | grep -E '^Freeciv version [0-9]'

# Mindustry has no --version flag: argv is joined into one console command,
# and the server takes its commands on stdin, one per line (the module and
# the stub feed it that way too). `version` then `exit` starts the real
# server (~2 s), prints "build <n>" and shuts down, exit 0 -- the same code
# path the unit runs, minus `host`, so no port is ever bound: the agent
# shares ac-box with the live servers on :5556 and :6567. From a scratch
# directory, because the server writes config/ into its working directory;
# a small heap, because the agent is shared.
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
(
  cd "$scratch"
  # Capture first, grep after: a `grep -q` inside the live pipe would exit
  # on the match while java is still writing, and pipefail would report
  # java's SIGPIPE as a failed gate.
  printf '%s\n' version exit \
    | JAVA_TOOL_OPTIONS="-Xms64M -Xmx256M" mindustry-server 2>&1 \
    | sed 's/\x1b\[[0-9;]*m//g' > mindustry.log
  grep -E 'Version: Mindustry .* build [0-9]+' mindustry.log | sed 's/^/tenant: mindustry-server /' \
    || { echo "tenant: mindustry-server did not report a version:" >&2; cat mindustry.log >&2; exit 1; }
)
echo "tenant gate: OK"
