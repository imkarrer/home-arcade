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
and what the box runs -- since 18 Sep 2026 12:34 CDT, from generation 1 of
`imkarrer/arcade`: a FloxHub generation of this environment is the whole
deploy unit, because neither game reads a file from this tree at run time
(verified on the box the same day -- both units reference only their
package's store path and `/var/lib/arcade`; `shaders/`, `www/`, `catalog/` and
`metadata/` reach the stations through the SMB/rsync export of `/srv/arcade`,
which stays a NixOS unit). The manifest's own header says what is deliberately
not in it (LAN address, ports, state dir, slice, `Restart=`) and why.

**The skeleton is homelab's.** Until 19 Sep 2026 `modules/arcade-hub.nix`
here declared what the servers run *as* (deleted with `flake.nix`; the
tree is manifest-only, and homelab's `hosts/ac-box/tenants/arcade.nix`
now declares it): the two unit names
(pinned, never renamed), `User=arcade`, `WorkingDirectory`, `After=/Wants=`,
`Restart=`, the state directories, the firewall holes on the LAN interface,
and the SMB/rsync export -- plus the options homelab's stubs read for the
argv and stdin they pass (`lanAddress`, `stateDir`, `freeciv.port`,
`mindustry.{port,map,mode}`), which are host facts the box sets. Its
`ExecStart` is a placeholder that exits 1 naming the stub, so a host that
composes the module without one gets a failed unit rather than a silent
one or a second server. Two trees, one unit each: what to run is here in
the manifest, what to run it as is here in the module, and which
generation to run is homelab's (its pull unit pins it).

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
   (`modules/tenant/environment-pull.nix`, FloxHub source kind) pulls that
   generation (`flox pull -g N --copy`, homelab `docs/flox-findings.md`
   section 3), warms it once online, records it, pins it, and restarts the
   stubs into it. This is the edge a game-server change takes: a manifest
   or lock edit here becomes a generation, and the generation becomes the
   running server, with no closure switch. The stubs have been on since 18
   Sep 2026 12:34 CDT (generation 1); the first-switch order that got them
   there -- pull unit first, stubs after, so the module and the
   environment never both hosted a port -- is history in homelab's
   `hosts/ac-box/configuration.nix`. Nothing in this tree decides what the
   box runs next; this pipeline only pushes and asks.
2. **The skeleton -- retired edge.** Until 19 Sep 2026 this tree was a
   flake input of homelab and a bump-lock step moved its module; the
   module now lives in homelab and there is no second edge. (History:
   when the module stopped building an `ExecStart`, a bump that changed
   nothing the stubs consumed was a no-op -- the toplevel `drvPath` was
   byte-identical with the stubs on). It stays until homelab folds the
   skeleton into its stubs and retires the input (homelab `homelab-158.11`).

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

## On the box after the flip: the hand-fetched jar, and the version

`/var/lib/arcade/mindustry/server-release.jar` (19 MB, Mindustry v159.7,
put there by hand with `scripts/fetch_mindustry.py` on 6 Sep 2026) has been
unused since 18 Sep 2026 12:34 CDT, when the stubs flipped on and
`arcade-mindustry.service`'s java began running the environment's
`/nix/store/…-mindustry-159.3/share/mindustry-server.jar` (checked on the
box: the unit's main PID holds that jar open and nothing holds the old one).
The module no longer references it and the script no longer fetches it. It
may be deleted on the box, **by a human** -- it is state under
`/var/lib/arcade`, so not a closure step, and not something an agent does
(homelab `AGENTS.md`: ac-box is read-only):

```bash
ssh ac-box 'sudo rm /var/lib/arcade/mindustry/server-release.jar'
```

Leave `config/` beside it alone: that is the server's live settings and
maps, written under the unit's `WorkingDirectory` by either jar, and the
environment's server reads it now.

**The version, honestly.** The jar was 159.7; the environment's
`mindustry-server` is the catalog's 159.3 (the newest it indexes, per the
manifest's own comment). Same protocol build, 159 -- Mindustry's join check
compares `Version.build` only, and the revision is documented as hotfix-only
-- so the stations' 159.7 clients connect exactly as before, and have since
the flip. What changed is who owns the version, which is ADR 0009 question
6's version coupling seen from the tenant's side. Before, a bump was a
download by hand into `/var/lib` and a restart, at whatever GitHub had that
day and with no record but the file's mtime. Now it is a manifest edit
(`mindustry-server.version`), the lock the pinned flox 1.14.0 writes, a
push, and a new generation the box pulls -- and the version is bounded by
what the catalog carries, so moving past 159.3 is a catalog question, not
a `curl`. That is the trade, taken on purpose: a version in git, tested by
CI and pinned by a generation, over the newest version on the box.

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
