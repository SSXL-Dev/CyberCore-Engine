## Supported games

Half-Life (`valve`), Opposing Force (`gearbox`), Counter-Strike (`cstrike`), Condition Zero (`czero`) and Blue Shift.

## What is new in 0.1.1

### Requirements

| Item | Status |
|---|---|
| Architecture | `arm64-v8a` only |
| Coming soon | `armeabi-v7a`, `x86` |

Devices with a 32-bit processor or an x86 processor cannot run this release yet.

### NextBots

- NextBots tab in the Lua-Menu with a tile grid and a G-Man example. Tap the tile and he appears with yellow electricity, walks up, adjusts his tie, speaks and teleports away.
- Server-side Lua API `cc.sv` and the NextBot framework `cc.nextbot`.

### Game modes

- The game mode picker is a row of three cards at the top center of the main menu: Sandbox, Deathmatch and Co-op, with Sandbox as the default. Each mode has its own accent color.
- The main menu background is tinted in the color of the selected mode and flashes when the mode changes.
- The Modes tab shows match settings while a map is running: keep weapons, friendly fire, share weapons, and per-player Give, Kill and Kick for the host.
- Lua API `cc.mode`, `cc.maps`, `cc.cvar.Set`, `cc.world.Find`, the `ChangeLevel` hook and `cc.sv.Give/Kill/Kick/Teleport/Push/Print/SetPlayer`.

### Co-op

- The Create game map list shows only the story levels (c0a0, c1a0 and so on), and the game starts with `coop 1` and at least 2 players.
- A level change needs the majority of living players at the exit. The center of the screen shows how many players are there and how many are needed.
- Going back to a visited level is blocked. An electric barrier appears around the old exit and pushes players away.
- Weapons, health and armor are carried over to the next level. Exact ammo is not saved.
- Weapons picked up by one player are shared with the others (can be turned off).
- A player who respawns returns to a teammate or to the last safe checkpoint and gets the weapons back.

### Other

- The touch profile `ssxldev` is the default touch layout of the engine.
- The launcher accent color is sky blue.
- G-Man plays the idlebrush animation where he adjusts his tie before he speaks.
