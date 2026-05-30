# RetroArch Integration

## Overview

FightingAI drives RetroArch (with the snes9x core) as the SNES emulator. Communication uses three independent channels:

| Channel  | Direction       | Mechanism                        |
|----------|-----------------|----------------------------------|
| Input    | Ruby → RetroArch | xdotool keydown/keyup            |
| State    | RetroArch → Ruby | `/proc/[pid]/mem` WRAM reads     |
| Control  | Ruby → RetroArch | UDP network commands (port 55355)|

## Process Lifecycle

1. `RetroArch::ConfigBuilder.build` writes a temp `retroarch.cfg` with network commands enabled and P1/P2 keyboard bindings.
2. `RetroArch::Adapter#start` starts the `display_server` first — either `XvfbServer` (`Xvfb :99`, headless) or `XephyrServer` (`Xephyr :99`, visible window on host desktop).
3. `RetroArch::Process#start` spawns `retroarch` with `DISPLAY=:99` in a new process group with stdout/stderr redirected to `/dev/null`.
4. After a startup pause, `RetroArch::WramReader#attach(pid)` opens `/proc/[pid]/mem`.
5. `RetroArch::Adapter#wait_for_wram` calls `WramReader#scan_for_wram` in a polling loop until the MK3 WRAM region is found.
6. On stop, the adapter releases all keys, sends `QUIT` via UDP, kills the process group, then stops Xvfb.

## UDP Network Commands

Port 55355 (configured in `retroarch.cfg` via `network_cmd_port`).

| Command            | UDP payload           | Notes |
|--------------------|-----------------------|-------|
| Pause toggle       | `PAUSE_TOGGLE`        | |
| Reset              | `RESET`               | |
| Save state         | `SAVE_STATE`          | Always saves to current slot; no `SAVE_STATE_SLOT N` command exists |
| Load state (slot N)| `LOAD_STATE_SLOT N`   | Single command — sets slot and loads atomically |
| Load state (current)| `LOAD_STATE`         | |
| Screenshot         | `SCREENSHOT`          | |
| Quit               | `QUIT`                | |

Implemented in `Emulator::RetroArch::NetworkCommands`.

## WRAM Reading

The snes9x core maps SNES WRAM (bus address `0x7E0000`, 128 KB) into an anonymous `rw-p` region in the RetroArch process address space. The exact host address varies per run.

`WramReader` scans `/proc/[pid]/maps` for all `rw-p` regions ≥ 512 bytes. For each region it reads up to 64 KB and tests the MK3 signature:

- `data[0x011C] == 160` — P1 max health is always 160 in MK3
- `data[0x014C] == 160` — P2 max health
- `data[0x0101]` in `0..3` — valid game state enum
- `data[0x018A]` in `1..5` — valid round number
- `data[0x011A]` in `0..160` — valid P1 health
- `data[0x014A]` in `0..160` — valid P2 health

Once found, the base address is cached. `read_u8(wram_addr)` and `read_u16_le(wram_addr)` add `wram_addr` to the base and seek `/proc/[pid]/mem` directly.

`Errno::EIO` and `Errno::ESRCH` from unreadable regions are silently skipped during scanning and return `0` during normal reads.

## Confirmed MK3 WRAM Addresses

Addresses are relative to WRAM base (SNES bus `0x7E0000`).

| Constant | Offset | Description | Confirmed |
|---|---|---|---|
| `P1_HEALTH_ADDR` | `0x3634` | Player 1 current health (0–0xA6) | yes |
| `P2_HEALTH_ADDR` | `0x37F6` | Player 2 current health (0–0xA6) | yes |
| `P1_ROUNDS_WON`  | `0x36E0` | Player 1 rounds won | yes |
| `P2_ROUNDS_WON`  | `0x38A4` | Player 2 rounds won | yes |
| `SCREEN_ADDR`    | `0x3A7E` | Current screen / stage ID | yes |
| `LEVEL_TIMER_ADDR` | `0x3610` | Round countdown timer (0–99, decrements once per second) | yes — observed 0x09→0x08→0x07→0x06 across sequential snapshots |
| `FATALITY_TIMER_ADDR` | `0x3BE0` | Fatality timer | unverified |

Positions (x, y), facing direction, and animation state addresses are **not yet located**. They are placeholder zeros in the current snapshot until a RAM search confirms them.

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
savestate_auto_load = "false"
savestate_auto_save = "false"
screenshot_directory = "/tmp/fighting_ai/screenshots"
# P1 keyboard: arrow keys + z/x/a/s/q/w
# P2 keyboard: t/g/f/h + v/b/c/n/r/y
```

Screenshots land in `/tmp/fighting_ai/screenshots/`. `FrameGrabber` monitors that directory for new or modified PNGs after sending the `SCREENSHOT` UDP command.
