# CI (Buildkite)

Pushes and PRs to `imkarrer/home-arcade` run on the same `ac-box` agent
(`queue: self`) as `ac-host`, inside this tree's flox environment
(`.flox/env/manifest.toml`, activated by the flox Buildkite plugin). Jobs must
not read `/srv/arcade`, start RetroArch, recycle AC lobbies, or open a game
port: the agent shares the box with the live `arcade-freeciv` and
`arcade-mindustry` units, so a CI server that bound :5556 or :6567 would be
colliding with the kids' servers, not testing anything.

## The environment is the tenant

Since homelab ADR 0009 step 2 the manifest is not a CI shell that happens to
carry python. It installs the two game servers ac-box runs (`freeciv` 3.2.2,
`mindustry-server` 159.3, each in its own package group so the catalog can
resolve the exact versions) beside `python312Full` and `git` for the source
checks. The same manifest and lock are the developer's shell, what CI tests,
and what the box is meant to run: a FloxHub generation of this environment is
the whole deploy unit, because neither game reads a file from this tree at run
time (verified on the box 18 Sep 2026 -- both units reference only their
package's store path and `/var/lib/arcade`; `shaders/`, `www/`, `catalog/` and
`metadata/` reach the stations through the SMB/rsync export of `/srv/arcade`,
which stays a NixOS unit). The manifest's own header says what is deliberately
not in it (LAN address, ports, state dir, slice, `Restart=`) and why.

## What a push proves

One gate step, `scripts/ci_test.sh`, two halves (then, on `main` only, the
push step below):

| Check | Why it is useful |
| --- | --- |
| `scripts/assert-no-content.py` | Blocks ROMs, zips, cores, `hub.json`, `roms/`, `cores/`, `saves/`, `secrets/` |
| Catalog JSON | Unique ids, allowed cores, DOS games have `boot`, paths stay under `roms/` |
| Crop YAML | `game_id` matches filename; `use_layout` exists in `_layouts.yaml` |
| Kid UI | `www/` files cross-link; `/api/games` and `/api/play` still referenced |
| `hub.json.example` | Placeholder only (must mention `smb-password`) |
| Flake + Windows scripts | Hub module path exists; launchers are non-empty text |
| Python compile | `scripts/*.py` parse |
| **Tenant gate** | `freeciv-server` and `mindustry-server` resolve from `$FLOX_ENV/bin`, not the agent's PATH; `freeciv-server --version` prints 3.2.x; Mindustry starts, answers `version` on stdin with its build number and exits 0 -- the unit's own code path minus `host`, so no port is opened |

The tenant gate is what stands between a manifest edit and the box: a package
the lock lost, or a locked build that does not start, goes red here before it
can become a generation. The plugin pushes every output the lock names to
MinIO (`s3-cache-push: true`), so the box's pull substitutes rather than
builds (homelab `docs/flox-findings.md` section 1); for these two catalog
packages `cache.nixos.org` carries the same paths, so the box needs nothing
from MinIO for them.

Local, the same gate the hub runs (fetches the pinned flox 1.14.0 from the
hub's lock, checks the lock covers the manifest, runs `ci_test.sh` inside the
environment):

```bash
bash /home/nixos/src/homelab/scripts/hub-gates.sh home-arcade [path-to-worktree]
```

Or by hand, inside the environment -- the tenant gate refuses to run outside
it, because outside it the test would be of whatever the machine has on PATH:

```bash
flox activate -- bash scripts/ci_test.sh
```

## What a push cannot prove

- A station can sync or launch
- Treasure Mountain / SMK actually boot
- Samba or MITM
- A Freeciv or Mindustry server **hosting** on the LAN address at the real
  ports -- CI starts each binary far enough to print its version, never far
  enough to bind (see the first paragraph). The hosting shape is proven on a
  developer's machine with the manifest's `[services]` blocks (loopback,
  scratch state) and on the box by the stub units.
- `nixos-rebuild` of `arcade-hub.nix`: homelab's gate composes this tree into
  `ac-box` by `--override-input`, and that runs from homelab, not here

Do **not** copy `ac-host` queue-prod / pages / downtime jobs into this pipeline.

## How a green build reaches the box

Two edges, both behind the `wait`, both `main` only:

1. **The environment, as a FloxHub generation** (ADR 0009 step 2 -- this
   tenant's own deploy edge). `scripts/ci_push.sh` makes the green manifest
   and lock the live generation of `imkarrer/arcade` on FloxHub, reads the
   generation number back, and uploads a `trigger: homelab` step that asks
   homelab to stage that generation on the box. The **generation is the
   staged unit**: manifest + lock, nothing from this tree, because neither
   server reads a file from it. On the box, homelab's pull unit
   (`modules/tenant/environment-pull.nix`, gaining a FloxHub source kind
   for this tenant) is to pull that generation (`flox pull -g N --copy`,
   homelab `docs/flox-findings.md` section 3), warm it once online, record
   it, and restart the stubs. Until homelab has pulled a first generation,
   **the box's stubs are off** and the two games keep running from
   `modules/arcade-hub.nix`; homelab's order is: the pull unit lands and
   warms a generation first, the stubs are switched on after, so the module
   and the environment never both host a port. Nothing in this tree
   decides that order; this pipeline only pushes and asks.
2. **The module, as a flake input** (still live). The `trigger: homelab`
   bump-lock step bumps homelab's `home-arcade` input, and the closure
   switches at 03:30. This moves `modules/arcade-hub.nix` and nothing else
   the box runs. It stays until the box runs both servers from the
   environment and the module is gone.

### The push step

What it does, and what it proved on WSL (18 Sep 2026, flox 1.14.0 -- the
agent's version -- and 1.14.1, against throwaway environments
`imkarrer/hub-arcade-spike` and `imkarrer/hub-arcade-spike-first`):

- A CI checkout is a **path** environment; FloxHub holds a **managed** one
  with a generation history. `flox push -d .` from the checkout works exactly
  once (it creates `imkarrer/arcade`); the next time it fails with "already
  exists", and `--force` "succeeds" by replacing the remote history with a
  fresh generation 1 -- no history, and any copy that had pulled the old
  revision breaks. So the script pulls the live generation into a scratch
  directory, overwrites its `manifest.toml` and `manifest.lock` with the
  tree's, commits them as a generation (`flox edit --sync`) and pushes.
  Only when `imkarrer/arcade` does not exist does it push a path copy with
  `--owner imkarrer`: the first push is CI's, so the history starts at a
  sha CI proved.
- **The generation carries the lock CI tested.** `flox edit --sync` does not
  re-resolve; it rewrites the lock with the packages in a different order.
  The script compares the two by content, and fails the step if they ever
  differ, since a generation that is not the lock the tenant gate ran would
  be the one thing this edge must never push. The same comparison is why a
  commit that changes neither manifest nor lock pushes nothing: the live
  generation is re-staged, and `flox` itself is not asked, because it
  compares locks byte for byte and would mint a generation out of the
  reordering.
- **The generation number** is not in `flox push`'s output on either
  version. `flox generations list -d <the pushed copy>` prints `Generation:
  N (live)` on both, and the copy's own metadata is what was just pushed.
  (`flox generations list -r owner/name` is NOT used: it reads a cached
  copy under `~/.cache/flox/remote/` that does not refresh, and after a
  force push it errors with "can't find rev specified in lockfile".)
- The number goes to Buildkite meta-data `arcade-generation`, and the
  trigger step is uploaded from the script (`buildkite-agent pipeline
  upload` of a generated fragment) rather than written statically: a
  static trigger's `build.env` is interpolated from the job's environment
  when the pipeline is uploaded, not from meta-data, and the number exists
  only after the push. What the trigger carries, all in `build.env`, which
  is what homelab's queue-environment step must accept:

  | Variable | Value |
  | --- | --- |
  | `HOMELAB_STAGE_ENVIRONMENT` | `arcade` -- the tenant, and the pending file's name on the box |
  | `HOMELAB_STAGE_ENV` | `imkarrer/arcade` -- what to pull |
  | `HOMELAB_STAGE_GENERATION` | the generation number, as a string |
  | `HOMELAB_STAGE_REV` | this tree's sha, so the record ties the generation to the commit that produced it |
  | `HOMELAB_STAGE_BRANCH` | this tree's branch (in a trigger build Buildkite's own describes homelab's) |
  | `HOMELAB_STAGE_BUILD` | this build's URL |

- **Skips until the token exists.** The step needs `FLOX_FLOXHUB_TOKEN` in
  the job environment (flox reads it on both versions, no `flox auth login`
  needed: "Credential read from the FLOX_FLOXHUB_TOKEN environment
  variable"). The agent inherits it from ac-host's `ci-env` once homelab
  renders the `floxhub-token` sops secret there -- a homelab change. Until
  then the script prints `skip push: FLOX_FLOXHUB_TOKEN is not set` and
  exits 0, the build stays green, and no trigger is uploaded; the same
  posture as bump-lock without `HOMELAB_PUSH_TOKEN`. Once the token is
  there, a failed push is a red step, because a token that stopped working
  is news.
- The environment is pushed **public** (`flox push`'s default, and what the
  first push said: "successfully pushed to FloxHub as public"). The
  manifest carries no host fact and no secret, by design (its own header
  says what is left out), so there is nothing in it to hide.
- FloxHub environments cannot be deleted from the CLI (`flox delete` on a
  linked copy removes the link only and says so), so the two spike
  environments above are the operator's to remove in the FloxHub UI.

Locally, the script runs from a laptop against a throwaway environment
(`ARCADE_FLOXHUB_REF=imkarrer/<spike>`) and prints the trigger it would
upload instead of uploading it; it never pushes `imkarrer/arcade` from a
laptop unless told to, and it should not be told to -- the first push is
CI's.

## First-time pipeline (Buildkite UI)

Org **`isaac-karrer`**, cluster Default, queue **`self`**.

1. New pipeline → GitHub `imkarrer/home-arcade`
2. Slug: `home-arcade`
3. First step: `buildkite-agent pipeline upload`
4. GitHub builds: on (push + PR)
5. Same agent token already on `ac-host-ci` — no new compose service

After that, a push to this repo should show [buildkite.com/isaac-karrer/home-arcade](https://buildkite.com/isaac-karrer/home-arcade).

`.flox/env.json` and `.flox/env/manifest.lock` are committed: the plugin
activates what is in the tree and never re-resolves. Edit the manifest with
the pinned flox 1.14.0 (the version the hub's `flake.lock` names and
`hub-gates.sh` fetches), then commit the lock it writes -- a lock written by a
newer flox was unreadable in the agent container once already.
