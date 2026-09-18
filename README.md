# Home arcade

Kid arcade source for `ac-box`. Separate from public `ac-host`.

This checkout lives at `C:\Users\isaac\home-arcade` (not under the Assetto Corsa tree).

| Tree | Path |
| --- | --- |
| Source (this repo) | `C:\Users\isaac\home-arcade` |
| Station cache (Dad PC) | `C:\Users\isaac\arcade` |
| Hub library | `ac-box:/srv/arcade` (`\\192.168.1.50\arcade`) |

**Git is source only.** ROMs, zips, ISOs, and emulator cores stay on the box at `/srv/arcade` and are never committed. The Samba password lives in `/var/lib/arcade/secrets/smb-password`, not in this repo.

| In git | On the box only |
| --- | --- |
| Flox environment (the game servers), Nix skeleton module, catalog, crop YAML, shaders, Windows agent, `www/` | `roms/`, `cores/`, game zips, `hub.json` |

Copy `windows/hub.json.example` to `hub.json` on a station and fill the password from the box.

Stations are 8th-gen i5 mini PCs with **Intel iGPU only** (no discrete GPU), 1080p. Ship 2D or light 3D only: RetroArch, DOS, Mindustry, OpenTTD, Luanti with short view distance. No Veloren / SS14 / GPU-recommended titles.

**The environment is the tenant; the module is the skeleton.** What the two game servers on `ac-box` run is `.flox/env/manifest.toml` (`freeciv` 3.2.2, `mindustry-server` 159.3), pushed by CI as a generation of `imkarrer/arcade` on FloxHub and pulled by the box (homelab ADR 0009 step 2, live since 18 Sep 2026). What they run *as* -- the unit names, `User=arcade`, directories, LAN firewall holes, the SMB/rsync export of `/srv/arcade` -- is `modules/arcade-hub.nix`, which homelab composes into `ac-box` as a flake input and whose `ExecStart` homelab's stubs replace with `flox activate`. A server change is a manifest edit; a unit-shape change is a module edit; neither needs the other.

Push checks: [`docs/ci.md`](docs/ci.md). Source only — no ROMs, no box, no AC recycle.
