# RetroArch Integration

## Overview

FightingAI drives RetroArch (with the snes9x core) as the SNES emulator. Communication uses three independent channels:

| Channel  | Direction        | Mechanism                                              |
|----------|------------------|--------------------------------------------------------|
| Input    | Ruby → RetroArch | xdotool keydown/keyup injected to the RetroArch window |
| State    | RetroArch → Ruby | Save-state file reads via `SaveStateReader`            |
| Control  | Ruby → RetroArch | UDP network commands (port 55355)                      |

## Process Lifecycle

1. `RetroArch::ConfigBuilder.build` writes a temp `retroarch.cfg` with network commands enabled and P1/P2 keyboard bindings.
2. `RetroArch::Adapter#start` starts the `display_server` first — either `XvfbServer` (`Xvfb :99`, headless) or `XephyrServer` (`Xephyr :99`, visible window on host desktop).
3. `RetroArch::Process#start` spawns `retroarch` with `DISPLAY=:99` in a new process group with stdout/stderr redirected to `/dev/null`.
4. After a startup pause, `RetroArch::Adapter#wait_for_wram` polls slot 9 save-states: it issues `SAVE_STATE` via UDP, then calls `SaveStateReader#try_locate_any` until the MK3 WRAM region is found.
5. Once WRAM is located, the adapter loads slot 0 (the match state) and the run loop begins.
6. On stop, the adapter releases all keys, sends `QUIT` via UDP, kills the process group, then stops the display server.

## UDP Network Commands

Port 55355 (configured in `retroarch.cfg` via `network_cmd_port`).

| Command              | UDP payload         | Notes |
|----------------------|---------------------|-------|
| Pause toggle         | `PAUSE_TOGGLE`      | |
| Reset                | `RESET`             | |
| Save state           | `SAVE_STATE`        | Always saves to current slot |
| Load state (slot N)  | `LOAD_STATE_SLOT N` | Sets slot and loads atomically |
| Load state (current) | `LOAD_STATE`        | |
| Screenshot           | `SCREENSHOT`        | |
| Quit                 | `QUIT`              | |

Implemented in `Emulator::RetroArch::NetworkCommands`.

## WRAM Reading

The snes9x core stores SNES WRAM (bus address `0x7E0000`, 128 KB) inside RetroArch save-state files. `SaveStateReader` extracts it using three strategies in priority order:

1. **RASTATE binary** (RetroArch 1.17+) — scans for the `RAM:131072:` marker and reads the 131072-byte block that follows. This is the normal path.
2. **snes9x text format** (older) — scans for `:RAM\n` or `:WRAM\n` markers and parses the size/data fields.
3. **MK3 signature scan** — walks every byte offset looking for the P1/P2 health and screen-ID pattern as a last resort.

Once found, the byte offset within the decompressed state blob is cached as `@wram_offset`. On every subsequent read, the offset is re-validated against the actual decompressed size of the current file; if it falls out of bounds (e.g. a partially-written file during an emulator save), WRAM is re-located before the `Snapshot` is built.

`read_u8(wram_addr)` and `read_u16_le(wram_addr)` index into `@bytes` at `@wram_offset + wram_addr`.

`raw_wram` returns exactly 131072 bytes (`WRAM_SIZE`) as a binary `String`. Used by `Adapter#wram_binary_dump` when writing `.bin` snapshot files.

### Partial-write protection

RetroArch writes RZIP state files incrementally (header first, then compressed chunks). `SaveStateReader#wait_for_update` rejects any file whose decompressed content is shorter than `WRAM_SIZE` (128 KB), spinning until a fully-written file is available.

## Confirmed MK3 WRAM Addresses

Addresses are relative to WRAM base (SNES bus `0x7E0000`).

| Constant | Offset | Width | Description | Status |
|---|---|---|---|---|
| `P1_HEALTH_ADDR` | `0x3634` | u8 | Player 1 current health (0–0xA6) | confirmed |
| `P2_HEALTH_ADDR` | `0x37F6` | u8 | Player 2 current health (0–0xA6) | confirmed |
| `P1_ROUNDS_WON` | `0x36E0` | u8 | Player 1 rounds won | confirmed |
| `P2_ROUNDS_WON` | `0x38A4` | u8 | Player 2 rounds won | confirmed |
| `SCREEN_ADDR` | `0x3A7E` | u8 | Current screen / stage ID | confirmed |
| `LEVEL_TIMER_ADDR` | `0x3610` | u8 | Elapsed round seconds (adapter inverts to remaining = 99 − raw) | confirmed — observed incrementing across sequential snapshots |
| `FATALITY_TIMER_ADDR` | `0x3BE0` | u8 | Fatality timer | unverified |
| `DISTANCE_ADDR` | `0x040E` | u8 | Distance between fighters | confirmed |
| `P1_X_ADDR` | `0x1A0A` | u16le | Player 1 horizontal position | confirmed — Pearson r = 1.0 across 120-frame walk sequence |

**Verified but not yet promoted to a named constant:**

| Offset | Width | Description | Evidence |
|---|---|---|---|
| `0x0062C` | u8 | P1 facing / binary state flag | Verified by `CandidateVerifier`: toggles exactly once when P1 crosses P2, 2 unique values, direction_changes = 0 |

**Not yet located:**

- Player 2 X position (use `dip memory:find-p2` to discover)
- Y positions for both players
- Animation state / frame index for both players

## Keyboard Input Injection

`Input::KeyboardInput` uses `xdotool` to inject keydown/keyup events into the RetroArch window.

On `start`, the window ID is found with:
```
xdotool search --name "RetroArch"
```

`send_input(player_index, buttons)` receives a `{ logical_symbol => bool }` hash. It compares against the current per-player key state and only calls `xdotool keydown/keyup` for keys whose state has changed, minimizing overhead.

`release_all(player_index)` sends `keyup` for every currently held key and clears the state.

## Display Isolation

RetroArch always runs on an isolated internal display `DISPLAY=:99`. Two backends are available:

| Mode | Class | Display | Host socket needed |
|------|-------|---------|-------------------|
| Headless (default) | `XvfbServer` | `Xvfb :99` inside container | No |
| Watch | `XephyrServer` | `Xephyr :99` inside container, renders into a window on the host desktop | Yes (`/tmp/.X11-unix`) |

`CLI.start_retro_arch` selects the backend: if `DISPLAY_HOST` is set in the environment it creates an `XephyrServer`; otherwise it creates an `XvfbServer`. The selected server is passed to `Adapter` as `display_server:` — its lifecycle is tied to `adapter.start` / `adapter.stop`.

`xdotool` always targets `:99`, so key injection is isolated from all windows on the host desktop regardless of mode.

### Watching live training

```bash
dip learn-watch [match-name]
```

`dip learn-watch` merges `.dockerdev/compose.watch.yml` on top of the base compose config, which mounts `/tmp/.X11-unix` and sets `DISPLAY_HOST`. Xephyr opens a `1024×768` window on the host desktop showing the live game.

## RetroArch Configuration

`RetroArch::ConfigBuilder.build` generates a temp config file:

```
network_cmd_enable = "true"
network_cmd_port = "55355"
video_fullscreen = "false"
video_gpu_screenshot = "false"
savestate_auto_load = "false"
savestate_auto_save = "false"
screenshot_directory = "/tmp/fighting_ai/screenshots"
# P1 keyboard: arrow keys + z/x/a/s/q/w
# P2 keyboard: t/g/f/h + v/b/c/n/r/y
```

Screenshots land in `/tmp/fighting_ai/screenshots/`. `video_gpu_screenshot = "false"` forces screenshots to come from the core framebuffer, so dimensions match the game's native output rather than the scaled RetroArch window. `FrameGrabber` monitors that directory for new or modified PNGs after sending the `SCREENSHOT` UDP command.
