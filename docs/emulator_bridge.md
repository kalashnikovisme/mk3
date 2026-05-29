# Emulator Bridge

## Overview

The BizHawk bridge uses a TCP connection with newline-delimited JSON messages.

```
BizHawk (Lua script)  ←TCP→  Ruby BridgeServer
```

## Setup

1. Launch BizHawk and load the MK3 ROM.
2. Start the Ruby bridge server: `ruby bin/run_human_vs_ai.rb` (or equivalent).
3. In BizHawk: Tools → Lua Console → Open Script → select `lua/bizhawk_bridge.lua`.
4. The Lua script connects to `127.0.0.1:7878` by default.

## Protocol

### Lua → Ruby: Frame Snapshot

Sent once per frame before `emu.frameadvance()`.

```json
{
  "type": "frame",
  "frame": 12345,
  "game": "mortal_kombat_3",
  "game_state": 2,
  "round": 1,
  "timer": 90,
  "match_over": false,
  "players": {
    "1": {
      "health": 120,
      "max_health": 144,
      "x": 100,
      "y": 40,
      "facing": 0,
      "anim": 5,
      "anim_frame": 2,
      "state": 0
    },
    "2": {
      "health": 80,
      "max_health": 144,
      "x": 200,
      "y": 40,
      "facing": 1,
      "anim": 3,
      "anim_frame": 0,
      "state": 1
    }
  }
}
```

Field notes:
- `game_state`: 0=menu, 1=char select, 2=fighting, 3=round over
- `facing`: 0=right, 1=left
- `state`: bitfield — bit 0=hitstun, bit 1=blockstun, bit 2=knockdown, bit 3=airborne

### Ruby → Lua: Input Response

Sent immediately after receiving each frame.

```json
{
  "type": "input",
  "player": 2,
  "buttons": {
    "Right": true,
    "A": true
  }
}
```

Or a noop (no input change):

```json
{ "type": "noop" }
```

Or state management commands:

```json
{ "type": "load_state", "slot": 1 }
{ "type": "save_state", "slot": 1 }
```

## BizHawk Button Names (SNES)

| Logical Name | BizHawk Suffix | Notes               |
|-------------|----------------|---------------------|
| up          | Up             |                     |
| down        | Down           |                     |
| left        | Left           |                     |
| right       | Right          |                     |
| low_punch   | Y              | SNES Y button       |
| high_punch  | X              | SNES X button       |
| low_kick    | B              | SNES B button       |
| high_kick   | A              | SNES A button       |
| block       | L              | SNES L trigger      |
| run         | R              | SNES R trigger      |

Full BizHawk key: `"P1 Right"`, `"P2 A"`, etc.

## Configuration

Edit the top of `lua/bizhawk_bridge.lua`:

```lua
local BRIDGE_HOST = "127.0.0.1"
local BRIDGE_PORT = 7878
local GAME_ID     = "mortal_kombat_3"
```
