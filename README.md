# Home arcade

Kid arcade source for `ac-box`. Separate from public `ac-host`.

**Git is source only.** ROMs, zips, ISOs, and emulator cores stay on the box at `/srv/arcade` and are never committed. The Samba password lives in `/var/lib/arcade/secrets/smb-password`, not in this repo.

| In git | On the box only |
| --- | --- |
| Nix hub module, catalog, crop YAML, shaders, Windows agent, `www/` | `roms/`, `cores/`, game zips, `hub.json` |

Copy `windows/hub.json.example` to `hub.json` on a station and fill the password from the box.

`ac-host` still imports a deploy copy of `modules/arcade-hub.nix` so `nixos-rebuild` does not need this private repo as a flake input yet.
