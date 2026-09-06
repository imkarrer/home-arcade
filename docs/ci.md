# CI (Buildkite)

Pushes and PRs to `imkarrer/home-arcade` should run **source checks only** on the same `ac-box` agent (`queue: self`) as `ac-host`. Jobs must not read `/srv/arcade`, start RetroArch, or recycle AC lobbies.

## What a push can prove

| Check | Why it is useful |
| --- | --- |
| `scripts/assert-no-content.py` | Blocks ROMs, zips, cores, `hub.json`, `roms/`, `cores/`, `saves/`, `secrets/` |
| Catalog JSON | Unique ids, allowed cores, DOS games have `boot`, paths stay under `roms/` |
| Crop YAML | `game_id` matches filename; `use_layout` exists in `_layouts.yaml` |
| Kid UI | `www/` files cross-link; `/api/games` and `/api/play` still referenced |
| `hub.json.example` | Placeholder only (must mention `smb-password`) |
| Flake + Windows scripts | Hub module path exists; launchers are non-empty text |
| Python compile | `scripts/*.py` parse |

Local:

```bash
python3 scripts/assert-no-content.py
python3 -m unittest discover -s scripts -p 'test_*.py' -v
```

## What a push cannot prove

- A station can sync or launch
- Treasure Mountain / SMK actually boot
- Samba, MITM, or a dedicated Mindustry/OpenTTD/Luanti process
- `nixos-rebuild` of `arcade-hub.nix` (still a deploy copy inside `ac-host`)

Do **not** copy `ac-host` queue-prod / pages / downtime jobs into this pipeline.

## First-time pipeline (Buildkite UI)

Org **`isaac-karrer`**, cluster Default, queue **`self`**.

1. New pipeline → GitHub `imkarrer/home-arcade`
2. Slug: `home-arcade`
3. First step: `buildkite-agent pipeline upload`
4. GitHub builds: on (push + PR)
5. Same agent token already on `ac-host-ci` — no new compose service

After that, a push to this repo should show [buildkite.com/isaac-karrer/home-arcade](https://buildkite.com/isaac-karrer/home-arcade).

The Flox env here is `python312Full` + `git` only. First activate may write `.flox/env/manifest.lock`; commit that lock once CI has produced it.
