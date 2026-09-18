#!/usr/bin/env bash
# The push half of this tenant's deploy edge (homelab ADR 0009, step 2):
# send the green environment to FloxHub as a generation of imkarrer/arcade,
# and hand homelab the generation number so it can stage it on the box.
#
# WHY A SCRIPT AND NOT `flox push -d .`. A FloxHub environment is a
# generation history, and a CI checkout is a path environment that knows
# nothing of it (.flox/env.json is {"name","version"}; the managed form
# with "owner" is what `flox push` writes back, and the checkout never
# keeps it). Proven on WSL, 18 Sep 2026, against a throwaway
# imkarrer/hub-arcade-spike (flox 1.14.0 and 1.14.1 agree):
#
#   - `flox push -d .` from a path env whose remote already exists:
#     "An environment named imkarrer/<name> already exists!", exit 1.
#   - `flox push -d . --force` from a path env: succeeds, and REPLACES the
#     remote history -- the result is a fresh "generation 1", the old
#     floxmeta rev is gone, and any copy that had pulled the old rev fails
#     with "can't find rev specified in lockfile". Every CI push would be
#     generation 1 of a different environment: no history, nothing for the
#     box to pull -g N, nothing for hub-status to compare.
#
# So the remote is treated as what it is. When imkarrer/<name> exists, this
# script PULLS it into a scratch directory (a managed env at its live
# generation), overwrites that copy's manifest.toml and manifest.lock with
# the tree's -- the exact files scripts/ci_test.sh just proved -- commits
# them as a generation (`flox edit --sync`, which does not re-resolve: the
# lock has the same content afterwards, checked below) and pushes. When the
# tree's manifest and lock already ARE the live generation (a docs-only
# commit) nothing is pushed and the live generation is re-staged -- a
# check this script makes itself, because flox compares locks byte for
# byte and its own rewrite reorders them. Only when the remote does not
# exist yet does it `flox push --owner` a path copy, which is the one push
# that may create the environment -- and that first push is CI's, not a
# laptop's, so the history starts at the sha CI proved.
#
# The generation number is not in `flox push`'s output on either version;
# `flox generations list -d <the pushed copy>` prints "Generation: N
# (live)" on both, and the copy's floxmeta is what was just pushed.
#
# OUTPUT. Sets Buildkite meta-data `arcade-generation` and uploads the
# trigger step that tells homelab to stage that generation (the trigger
# must be uploaded here: a static `trigger:` step's build.env is
# interpolated from the job's environment, not from meta-data). Outside
# Buildkite (no buildkite-agent on PATH) both are printed instead, so the
# script can be exercised from a laptop against a spike environment.
#
# SKIPS, with a message, while FLOX_FLOXHUB_TOKEN is unset -- the same
# posture as homelab's bump-lock without HOMELAB_PUSH_TOKEN: the token is
# the operator's enabling step (a sops secret homelab renders into the
# agent's ci-env), and until it exists a green build stays green and
# nothing is pushed. Never runs the tree's manifest through `flox activate`
# itself; the plugin already did, and this script only copies files.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

export FLOX_DISABLE_METRICS=true

# owner/name on FloxHub. The name is the environment's own (.flox/env.json,
# "arcade" -- the tenant, not the tree; the pull unit on the box reads the
# same field). ARCADE_FLOXHUB_REF exists so a laptop can run this whole
# script against a throwaway environment; CI never sets it.
name="$(sed -n 's/.*"name" *: *"\([^"]*\)".*/\1/p' .flox/env.json | head -1)"
[ -n "$name" ] || { echo "ci_push: no name in .flox/env.json" >&2; exit 1; }
ref="${ARCADE_FLOXHUB_REF:-imkarrer/$name}"
owner="${ref%%/*}"
name="${ref#*/}"

if [ -z "${FLOX_FLOXHUB_TOKEN:-}" ]; then
  echo "skip push: FLOX_FLOXHUB_TOKEN is not set; $ref stays at its live generation"
  echo "  (homelab renders the floxhub-token secret into the agent's ci-env;"
  echo "   until the agent carries it, a green build pushes nothing -- docs/ci.md)"
  exit 0
fi

# The tree's environment: exactly what the test step activated.
manifest=.flox/env/manifest.toml
lock=.flox/env/manifest.lock
[ -f "$manifest" ] && [ -f "$lock" ] || { echo "ci_push: $manifest and $lock must both exist" >&2; exit 1; }

# Two locks are the same generation when every package resolves to the
# same thing, whatever order they are written in: flox rewrites a lock it
# commits with its packages in a different order (seen on 1.14.0 and
# 1.14.1: the two game packages moved ahead of git and python, every field
# identical), so a byte compare would call every push a change. python3 is
# the environment's, which is one reason this script runs under the plugin.
same_lock() {
  python3 - "$1" "$2" <<'PY'
import json, sys
def canon(path):
    with open(path) as f:
        d = json.load(f)
    d["packages"] = sorted(d.get("packages", []), key=lambda p: (p.get("install_id", ""), p.get("system", "")))
    return json.dumps(d, sort_keys=True)
sys.exit(0 if canon(sys.argv[1]) == canon(sys.argv[2]) else 1)
PY
}

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
env_dir="$scratch/env"
mkdir -p "$env_dir"

# Pull the remote if it exists. Its absence is the one error that is not
# an error ("does not exist" -> first push); anything else (auth, network)
# fails here with flox's own message, loudly, because a red push step is
# how the operator learns the token stopped working.
pull_log="$scratch/pull.log"
if flox pull "$ref" -d "$env_dir" >"$pull_log" 2>&1; then
  echo "push: $ref exists; pulled its live generation"
  if cmp -s "$manifest" "$env_dir/.flox/env/manifest.toml" \
     && same_lock "$lock" "$env_dir/.flox/env/manifest.lock"; then
    # The live generation already is this manifest and lock (a commit that
    # touched docs, say). Nothing to push; the live generation is what gets
    # staged. This check is the script's, not flox's: flox compares the
    # lock byte for byte, and would mint a generation out of a reordering.
    echo "push: the live generation already carries this manifest and lock; nothing to push"
  else
    cp "$manifest" "$env_dir/.flox/env/manifest.toml"
    cp "$lock" "$env_dir/.flox/env/manifest.lock"
    # Commit the copy's changed files as a generation. Sync does not
    # re-resolve -- the lock keeps every package as CI tested it -- but that
    # is checked rather than trusted: a generation that is not the lock CI
    # tested is the one thing this edge must never push.
    flox edit --sync -d "$env_dir"
    if ! same_lock "$lock" "$env_dir/.flox/env/manifest.lock"; then
      echo "ci_push: flox edit --sync changed manifest.lock's content; the generation would not be the lock CI tested" >&2
      diff "$lock" "$env_dir/.flox/env/manifest.lock" >&2 || true
      exit 1
    fi
    flox push -d "$env_dir"
  fi
elif grep -q "does not exist" "$pull_log"; then
  echo "push: $ref does not exist yet; this is the first push"
  mkdir -p "$env_dir/.flox/env"
  printf '{"name": "%s", "version": 1}\n' "$name" > "$env_dir/.flox/env.json"
  cp "$manifest" "$env_dir/.flox/env/manifest.toml"
  cp "$lock" "$env_dir/.flox/env/manifest.lock"
  flox push -d "$env_dir" --owner "$owner"
else
  echo "ci_push: flox pull $ref failed:" >&2
  cat "$pull_log" >&2
  exit 1
fi

# The generation the remote is now live at. `--no-pager` because a job has
# no tty but flox checks $PAGER anyway.
generation="$(flox generations list -d "$env_dir" --no-pager 2>/dev/null \
  | sed -n 's/^Generation: *\([0-9][0-9]*\) (live).*/\1/p' | head -1)"
if ! [[ "$generation" =~ ^[0-9]+$ ]]; then
  echo "ci_push: could not read the live generation of $ref after the push:" >&2
  flox generations list -d "$env_dir" --no-pager >&2 || true
  exit 1
fi
echo "push: $ref is live at generation $generation"

# Hand the generation to the rest of the build. A static trigger step's
# build.env is interpolated from the job environment when the pipeline is
# uploaded, so the trigger that carries the generation is uploaded from
# here, after the push, with the number written in. The meta-data key is
# for anything else that wants it (a later step, the operator's `buildkite-
# agent meta-data get arcade-generation`), not for the trigger.
branch="${BUILDKITE_BRANCH:-}"
build_url="${BUILDKITE_BUILD_URL:-}"
commit="${BUILDKITE_COMMIT:-$(git rev-parse HEAD)}"

fragment="$scratch/stage.yml"
# Two homelab-facing facts ride the build.env and nothing else does:
# HOMELAB_STAGE_ENVIRONMENT names the tenant (the pending file's name on
# the box), HOMELAB_STAGE_ENV/GENERATION name what to pull. The branch and
# build URL are the tenant's own, because in a trigger build Buildkite's
# describe homelab's. No `$` anywhere below: the values are written out
# here, so `pipeline upload` has nothing to interpolate.
cat > "$fragment" <<EOF
steps:
  - trigger: homelab
    label: ":inbox_tray: stage generation $generation of $ref on the box"
    depends_on: push
    async: true
    # Same reasoning as the bump-lock trigger in .buildkite/pipeline.yml:
    # a trigger that cannot fire must not redden this build.
    soft_fail: true
    build:
      message: "home-arcade ${commit} went green: stage $ref generation $generation"
      env:
        HOMELAB_STAGE_ENVIRONMENT: arcade
        HOMELAB_STAGE_ENV: $ref
        HOMELAB_STAGE_GENERATION: "$generation"
        HOMELAB_STAGE_REV: "$commit"
        HOMELAB_STAGE_BRANCH: "$branch"
        HOMELAB_STAGE_BUILD: "$build_url"
EOF

if command -v buildkite-agent >/dev/null 2>&1 && [ -n "${BUILDKITE_JOB_ID:-}" ]; then
  buildkite-agent meta-data set arcade-generation "$generation"
  buildkite-agent pipeline upload "$fragment"
  echo "push: uploaded the stage trigger for generation $generation"
else
  echo "push: not under buildkite-agent; would set meta-data arcade-generation=$generation and upload:"
  sed 's/^/  | /' "$fragment"
fi
