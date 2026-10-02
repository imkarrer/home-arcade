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

## Players

The top of Home Arcade shows **Playing as**: Dad, Mom, Calvin, Ivy, Faye (from `catalog/players.json`), plus anyone added with **New profile**. Every PC shows the same list, and a profile's saves follow them to any PC.

Each profile is a folder, `%USERPROFILE%\arcade\saves\<profile>` (holding `profile.json`): RetroArch and DOS saves at the top (by core), save states in `states\`, Freeciv in `freeciv\`, Mindustry in `mindustry\`.

- **Before a game starts** the PC pulls that profile's folder from `\\192.168.1.50\arcade\saves`.
- **When the game exits** it pushes the folder to `\\192.168.1.50\arcade-saves`, the one share a PC can write.
- **Opening Home Arcade** pulls everything, then pushes every profile, so saves made while the box was off go up later.

Copies are newest-file-wins both ways, and nothing is ever deleted. If the same profile plays the same game on two PCs at once, the save that finishes last wins. Folders under `saves\` without `profile.json` (saves from before profiles) stay on that PC.

| After install | Path |
| --- | --- |
| Library | `%USERPROFILE%\arcade` |
| Launch | Start: **Home Arcade** |
| Re-sync | `%USERPROFILE%\arcade\sync.ps1` |

## Freeciv

**Play**: a private game on this PC (only this PC can connect); you have full control: /save NAME, /load NAME, /endgame.
**Host**: a game on this PC that friends on the home network can join; the host has full control, friends are players. Needs the firewall rule install.ps1 adds when run as administrator.
**Join a friend**: type the host PC's IP in the join box.
**Freeciv: family game**: the one shared server on arcade-box (192.168.1.50:5556); everyone joins the same game.
Saves go to the current persona's folder, saves\<persona>\freeciv; the server quits two minutes after the last player leaves.
