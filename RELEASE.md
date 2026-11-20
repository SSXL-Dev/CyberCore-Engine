## Requirements

| Item | Status |
|---|---|
| Architecture | `arm64-v8a` only |
| Coming soon | `armeabi-v7a`, `x86` |

Devices with a 32-bit processor or an x86 processor cannot run this release yet.

## Supported games

Half-Life (`valve`), Opposing Force (`gearbox`), Counter-Strike (`cstrike`), Condition Zero (`czero`) and Blue Shift.

## What is new in 0.1.3

- The game mode picker moved to the top center of the main menu. The modes are Sandbox, Deathmatch and Co-op, and Sandbox is the default.
- Co-op mode: the Create game map list shows the campaign levels instead of the deathmatch maps, and the game starts with `coop 1` and at least 2 players.
- Level change voting, checkpoints, inventory carry-over and shared weapons for Co-op come in the next version.

## What is new in 0.1.2

- Game mode picker at the bottom left of the main menu: Default, Sandbox and Deathmatch. The choice is saved per game and applied when a new game starts. Co-op is not included yet.
- A Modes tab in the CyberCore menu to pick the same modes.
- The launcher accent color is now sky blue.
- Lua API `cc.mode` and `cc.cvar.Set`.

## What is new in 0.1.1

- NextBots tab in the Lua-Menu with a tile grid and a G-Man example. Tap the tile and he appears with yellow electricity, walks up, adjusts his tie, speaks and teleports away.
- The touch profile `ssxldev` is now the default touch layout of the engine.
- Server-side Lua API `cc.sv` and the NextBot framework `cc.nextbot`.
