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
| Nix hub module, catalog, crop YAML, shaders, Windows agent, `www/` | `roms/`, `cores/`, game zips, `hub.json` |

Copy `windows/hub.json.example` to `hub.json` on a station and fill the password from the box.

Stations are 8th-gen i5 mini PCs with **Intel iGPU only** (no discrete GPU), 1080p. Ship 2D or light 3D only: RetroArch, DOS, Mindustry, OpenTTD, Luanti with short view distance. No Veloren / SS14 / GPU-recommended titles.

`ac-host` still imports a deploy copy of `modules/arcade-hub.nix` so `nixos-rebuild` does not need this repo as a flake input yet.
