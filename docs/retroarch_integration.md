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
4. After a startup pause, the adapter loads slot 0 (the match state) and the run loop begins.
6. On stop, the adapter releases all keys, sends `QUIT` via UDP, kills the process group, then stops the display server.

## UDP Network Commands

Port 55355 (configured in `retroarch.cfg` via `network_cmd_port`).

| Command              | UDP payload         | Notes |
|----------------------|---------------------|-------|
| Pause toggle         | `PAUSE_TOGGLE`      | |
| Advance one frame    | `FRAMEADVANCE`      | Used by `dip learn_empty` while paused |
| Load and pause       | `LOAD_STATE_SLOT 0`, then `PAUSE_TOGGLE` | Sent in order on one socket by `dip learn_empty` |
| Reset                | `RESET`             | |
| Save state           | `SAVE_STATE`        | Always saves to current slot |
| Load state (slot N)  | `LOAD_STATE_SLOT N` | Sets slot and loads atomically |
| Load state (current) | `LOAD_STATE`        | |
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
| Watch | `XephyrServer` | `Xephyr :99` inside container, renders a wide enough host-side desktop for RetroArch plus the reconstructed scene | Yes (`/tmp/.X11-unix`) |

`CLI.start_retro_arch` selects the backend: if `DISPLAY_HOST` is set in the environment it creates an `XephyrServer`; otherwise it creates an `XvfbServer`. The selected server is passed to `Adapter` as `display_server:` — its lifecycle is tied to `adapter.start` / `adapter.stop`.

`xdotool` always targets `:99`, so key injection is isolated from all windows on the host desktop regardless of mode.

### Watching live training

```bash
dip learn-watch [match-name]
```

`dip learn-watch` merges `.dockerdev/compose.watch.yml` on top of the base compose config, which mounts `/tmp/.X11-unix` and sets `DISPLAY_HOST`. Xephyr opens a host-side desktop sized to fit the RetroArch window and the reconstructed-scene window side by side.
In watch mode the CLI also opens a second host-side `ffplay` window titled
`Reconstructed Scene`. It uses the same `297x216` capture size as the vision
frame grabber output,
but only paints the detected sprite rectangles back onto a blank canvas at
their detected coordinates. This viewer is diagnostic only; it does not change
the emulator input or the game-state extraction path.
The reconstruction uses a dark diagnostic background and keeps rendering even
when no players are detected on a frame, so the second window stays visible
instead of disappearing into a pure black rectangle.
For a quick live check, the viewer also paints a white `TEST` label in the
upper-left corner of the reconstructed frame.

## Game Speed Throttling

RetroArch is configured with `speed: 1.0` in `config/adapter.yml`. Throttling is harder than it looks in a headless container:

- **`audio_sync = "true"`** relies on PulseAudio backpressure. With a null sink (`pactl load-module module-null-sink`), audio is consumed immediately with no backpressure — RetroArch runs as fast as the CPU allows (~10–25× real speed).
- **`PULSE_LATENCY_MSEC=10`** and **`audio_latency = "10"`** were tried and do not fix the null-sink backpressure problem.
- **`video_swap_interval = "1"`** requires display vsync. With software OpenGL (`LIBGL_ALWAYS_SOFTWARE=1`), there is no vsync — the setting is ignored.
- **`video_frame_delay = "15"`** (used now) — a pure software sleep that RetroArch inserts at the start of each frame render. No audio or vsync dependency. With ~1–2ms render time, 15ms delay ≈ 17ms per frame ≈ 59fps ≈ 1.0× speed. `video_frame_delay_auto` is intentionally NOT set — the auto mode overrides the manual value from 0 and under software GL it fails to converge.

The setting is applied when `cfg.speed <= 1.0` (the `throttled` flag in `ConfigBuilder`).

## RetroArch Configuration

`RetroArch::ConfigBuilder.build` generates a temp config file:

```
network_cmd_enable = "true"
network_cmd_port = "55355"
video_fullscreen = "false"
video_windowed_fullscreen = "false"
video_scale = "1.0"
video_scale_integer = "true"
video_window_show_decorations = "false"
video_smooth = "false"
video_font_enable = "false"
savestate_auto_load = "false"
savestate_auto_save = "false"
# P1 keyboard: arrow keys + z/x/a/s/q/w
# P2 keyboard: t/g/f/h + v/b/c/n/r/y
```

RetroArch runs windowed, with windowed fullscreen disabled and `video_scale =
"1.0"`, so the rendered game window opens at native core scale instead of
expanding to the full Xvfb/Xephyr screen. Integer scaling is enabled, window
decorations are disabled, smoothing is disabled, and OSD messages are disabled
by turning off `video_font_enable` to keep captured pixels stable for vision debugging.

The app does not use RetroArch's screenshot command. `FrameGrabber` captures the
isolated X display directly with `xwd`, pipes the result directly into ImageMagick
`convert` (no temp file), and crops the top-left `297x216` pixels as an 8-bit
TrueColor PNG with no scanline filters (`-type TrueColor -depth 8
-define png:compression-filter=0`). Runtime vision and the Scenario DSL
`screenshot` method both use this X-server screenshot path.

The headless `XvfbServer` runs at `320x240` (was `1024x768`), reducing each
`xwd` capture from ~3 MB to ~300 KB. The watch-mode `XephyrServer` uses a
shared desktop width large enough to keep RetroArch and the reconstructed scene
visible side by side, so the watch display no longer clips the second window.
