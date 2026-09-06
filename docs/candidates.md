# Arcade title candidates

Research shortlist (2026-09-06) for stations that are **8th-gen i5 + Intel UHD 630 only**, 1080p. Nothing here needs a discrete GPU if the GPU notes are followed.

Not a deploy list. v1 tiles stay in [`plan-arcade.md`](plan-arcade.md#game-catalog-v1-target). ROMs, zips, and commercial data stay on `/srv/arcade` — never git.

## Host column

| Value | Meaning |
| --- | --- |
| **dedicated** | Headless server on `ac-box`, 24/7. Stations only join. World survives if every kid quits. |
| **listen / LAN** | One station *is* the server (kid UI **Host** = Player 1). Session dies when that station quits. |
| **solo** | No multiplayer. Files can still live on the hub and sync to stations. |

“You can host Treasure Mountain” means you own a copy so the hub may serve the zip. It is **solo**, not a lobby.

## License column

| Value | Meaning |
| --- | --- |
| **FOSS** | Free clients on every station. Fine to ship. |
| **own copy** | Put on `/srv/arcade` only if the discs/dumps are already in the house. Do not fetch from IA or torrents. |

## Ship first

1. Hub worlds: Mindustry, OpenTTD, Luanti (short view, no fancy shaders). LAN-only on `enp8s0`, `enable = false` until ready.
2. Kid solo you already own: rest of Super Solvers, then ScummVM Humongous if the CDs are in the house. Same boot-file Settings flow.
3. Already in the picker: Super Mario Kart, Mario Kart 64, Treasure Mountain. GoldenEye when you want split FPS.

## Do not deploy

- Factorio — headless server is free; every playing client needs a paid copy.
- Veloren, Space Station 14, Beyond All Reason, FlightGear — GPU.
- OpenRA / OpenRCT2 / CorsixTH / Julius / DevilutionX / OpenXcom **assets you do not own**.
- SuperTuxKart only at the low / fallback preset at 1080p.

`gpu: tune low` needs graphics turned down. `kids: no` is a poor little-kid fit (violence / complexity).

## Full list

| Title | Kind | License | Host | GPU | Kids | Note |
| --- | --- | --- | --- | --- | --- | --- |
| Mindustry | Factory + defense | FOSS | dedicated | trivial | yes | Best Factorio stand-in. `server-release.jar` on ac-box. |
| OpenTTD | Trains / logistics | FOSS | dedicated | trivial | yes | Full free art (OpenGFX). Always-on map. |
| Luanti (Minetest) | Voxel sandbox | FOSS | dedicated | tune low | yes | Already planned. Short view distance, no shaders. |
| shapez (not Shapez 2) | Belt puzzle | FOSS | listen / LAN | trivial | yes | GPL shapez.io. Weak as a 24/7 world. |
| Endless Sky | Space sandbox | FOSS | solo | trivial | yes | Already on the plan. Almost no MP. |
| Naev | Space sandbox | FOSS | solo | trivial | older | Similar to Endless Sky, 2D. |
| Widelands | Settlers-like | FOSS | listen / LAN | light | yes | Slow real-time building. Fine on UHD 630. |
| Warzone 2100 | RTS | FOSS | listen / LAN | light | older | Oil + units. Host from a client or autohost. |
| Battle for Wesnoth | Turn strategy | FOSS | listen / LAN | trivial | older | Pixel fantasy. Multiplayer lobbies. |
| Freeciv | Civ clone | FOSS | dedicated | trivial | older | True dedicated server. Long sessions. |
| Unciv | Civ clone | FOSS | listen / LAN | trivial | older | 2D, also runs on cheap Android if needed. |
| Hedgewars | Worms-like | FOSS | listen / LAN | light | yes | Turn combat, local or net. Cartoon violence. |
| Teeworlds | 2D shooter | FOSS | dedicated | trivial | older | Tiny dedicated server. CTF / DM. |
| DDraceNetwork | 2D coop race | FOSS | dedicated | trivial | yes | Teeworlds fork. Cooperative maps, very light. |
| OpenSoldat | 2D shooter | FOSS | dedicated | trivial | older | Soldat-style. Dedicated server. |
| Armagetron Advanced | Light cycles | FOSS | dedicated | trivial | yes | Tron bikes. Dedicated server, tiny GPU. |
| BZFlag | Tank battles | FOSS | dedicated | light | yes | Simple 3D tanks. Ancient OpenGL. Dedicated. |
| AssaultCube | Arena FPS | FOSS | dedicated | tune low | older | Low-poly FPS. Violence. Keep settings down. |
| OpenArena | Quake arena | FOSS | dedicated | tune low | no | FOSS Quake 3. Violence. Last resort. |
| SuperTuxKart | Karts | FOSS | dedicated | tune low | yes | Use fallback / low preset at 1080p. GPU-bound. |
| Extreme Tux Racer | Ski slalom | FOSS | solo | light | yes | Lighter 3D than STK. Solo. |
| SuperTux | Platformer | FOSS | solo | trivial | yes | 2D Mario-like. No server. |
| Pingus | Lemmings-like | FOSS | solo | trivial | yes | Puzzle. Good rainy-day tile. |
| Mari0 | Platform puzzle | FOSS | listen / LAN | trivial | yes | LÖVE. Mario + portals. Local coop. |
| Super Mario War | Arena platform | FOSS | listen / LAN | trivial | yes | 2D battle. Fan art; keep offline LAN. |
| Neverball / Neverputt | Marble / mini golf | FOSS | solo | light | yes | Local. Fine on iGPU. |
| Frozen Bubble | Puzzle | FOSS | listen / LAN | trivial | yes | Puzzle Bobble clone. Optional net. |
| The Powder Toy | Sandbox physics | FOSS | solo | light | yes | CPU sandbox. Not a hosted world. |
| GCompris | Education suite | FOSS | solo | trivial | yes | Many small activities. Ages 2–10. |
| Tux Math / Tux Typing | Education | FOSS | solo | trivial | yes | Arcade-style drills. |
| Colobot | Code + robots | FOSS | solo | light | older | Program robots. 3D but old-school. |
| Shattered Pixel Dungeon | Roguelike | FOSS | solo | trivial | older | 2D. No MP. |
| Frogatto | Platformer | FOSS | solo | trivial | yes | 2D. Code is open; assets CC-ish. |
| 0 A.D. | 3D RTS | FOSS | listen / LAN | tune low | older | Borderline. Try last; drop if it chugs. |
| MegaGlest | 3D RTS | FOSS | listen / LAN | tune low | older | Same caution as 0 A.D. |
| Unknown Horizons | Anno-like | FOSS | listen / LAN | light | older | Isometric. Slow pace. |
| Super Solvers series | DOS education | own copy | solo | trivial | yes | Treasure Mountain already on hub. Rest of series same path. |
| ScummVM: Putt-Putt / Freddi Fish / Pajama Sam / Spy Fox | Kid adventure | own copy | solo | trivial | yes | Humongous CDs you own. Best kid solo pile after Super Solvers. |
| ScummVM: Reader Rabbit / Math Blaster / Carmen / Oregon Trail | DOS / Win education | own copy | solo | trivial | yes | If the discs are in the house. DOSBox or ScummVM per title. |
| The Incredible Machine | Puzzle | own copy | solo | trivial | yes | DOS/Win. Great couch puzzle if you own it. |
| Super Mario Kart (SNES) | Karts | own copy | listen / LAN | trivial | yes | Already in catalog. RetroArch netplay + crop. |
| Mario Kart 64 | Karts | own copy | listen / LAN | light | yes | Already in catalog. Keep N64 res modest. |
| GoldenEye 007 (N64) | Split FPS | own copy | listen / LAN | light | older | Planned. Crop manifest exists. Violence. |
| Bomberman / Super Bomberman | Arena | own copy | listen / LAN | trivial | yes | SNES/Genesis dumps you own. Excellent 4P. |
| Sonic 2 / 3 | Platformer | own copy | listen / LAN | trivial | yes | Genesis. Sonic 2/3 have coop. Netplay OK. |
| Street Fighter II | Versus | own copy | listen / LAN | trivial | older | SNES/CPS. Versus netplay. Not little-kid. |
| Any owned DOS via DOSBox Pure | DOS library | own copy | solo | trivial | varies | Same zip + boot file flow as Treasure Mountain. |
| OpenRCT2 + RCT2 | Park builder | own copy | listen / LAN | light | yes | Engine FOSS; needs your RCT2 data. Do not ship assets. |
| Julius / Augustus + Caesar III | City builder | own copy | solo | trivial | older | FOSS engine. Needs Caesar III files you own. |
| CorsixTH + Theme Hospital | Hospital sim | own copy | solo | trivial | older | FOSS engine. Needs Bullfrog data. |
| OpenXcom + UFO Defense | Tactics | own copy | solo | trivial | no | Needs original X-COM. Combat, not little-kid. |
| DevilutionX + Diablo | Action RPG | own copy | listen / LAN | trivial | no | FOSS engine. Needs Diablo. Violence. |

## Dedicated-hub subset

Mindustry, OpenTTD, Luanti, Freeciv, Teeworlds, DDraceNetwork, OpenSoldat, Armagetron Advanced, BZFlag, AssaultCube, OpenArena, SuperTuxKart (low preset only).
