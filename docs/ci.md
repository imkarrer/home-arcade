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

One step, `scripts/ci_test.sh`, two halves:

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

Two edges, one live and one not yet:

1. **Today**: the `trigger: homelab` step bumps homelab's `home-arcade` flake
   input, and the closure switches at 03:30. This moves `modules/arcade-hub.nix`
   and nothing else the box runs.
2. **Not yet**: a `flox push` of the green environment to FloxHub
   (`imkarrer/arcade`) after the `wait`, on `main` only, so the box can pull a
   generation instead of a sha. It needs a FloxHub token on the agent -- a
   sops secret the operator creates after `flox auth login` -- and is added as
   its own step once that exists. The pipeline file marks where.

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
