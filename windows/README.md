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

If that fails: `ping 192.168.1.50` and `Test-NetConnection 192.168.1.50 -Port 445`. The PC must be `192.168.1.x` (same LAN as ac-box).

| After install | Path |
| --- | --- |
| Library | `%USERPROFILE%\arcade` |
| Launch | Start: **Home Arcade** |
| Re-sync | `%USERPROFILE%\arcade\sync.ps1` |
