# Windows spoke — same UX on every PC

No WSL. The PC copies `\\192.168.1.50\arcade` with robocopy (built into Windows).

1. Copy this `windows` folder onto the PC (USB or `\\192.168.1.146\...`).
2. PowerShell:

```powershell
cd <this-folder>
Set-ExecutionPolicy -Scope CurrentUser Bypass
.\install.ps1
.\install.ps1 -StationId win-dev-02
```

Installs RetroArch 1.22.2, pulls the hub library, creates **Home Arcade** on Start and the desktop.

**Home Arcade:** Solo / Host (you are P1) / Join (other PC's LAN IP). Check **Big screen** to crop the shared split to your player only (Host = top/left, Join = bottom/right). Uncheck to see the authentic 2P split. Solo never crops.

Windows 10/11 Pro block guest SMB. `install.ps1` maps the share as user `arcade` using `hub.json`. By hand:

```powershell
net use \\192.168.1.50\arcade /user:arcade <password from hub.json>
explorer \\192.168.1.50\arcade
```

If that fails: `ping 192.168.1.50` and `Test-NetConnection 192.168.1.50 -Port 445`. The PC must be `192.168.1.x` (same LAN as arcade-box).

| After install | Path |
| --- | --- |
| Library | `%USERPROFILE%\arcade` |
| Launch | Start: **Home Arcade** |
| Re-sync | `%USERPROFILE%\arcade\sync.ps1` |

## Players

The top of Home Arcade shows **Playing as**: pick a persona, or **New guest** to add one. Personas live in station.json on that PC.
Every game saves into %USERPROFILE%\arcade\saves\<persona>: RetroArch and DOS saves at the top, save states in states\, Freeciv in freeciv\. Mindustry keeps its own saves in %APPDATA%\Mindustry and is not per persona.
Saves made before personas move into the first persona the first time a game starts.
sync.ps1 pulls every persona's saves from the box; sync.ps1 -PushSaves copies them back.

## Freeciv

**On this PC** starts a private Freeciv server on the station (127.0.0.1:5556, apps\windows\freeciv\freeciv-server.exe) and connects to it. Saves (Game > Save Game, or /save NAME in chat) land in %USERPROFILE%\arcade\saves.freeciv; reload one from the lobby with /load NAME. The server quits two minutes after the last player leaves. sync.ps1 never deletes saves (robocopy /E /XO); sync.ps1 -PushSaves copies them to the box.

**With family** connects to the one shared server on arcade-box (192.168.1.50:5556): one game for everyone, saved on the box.
