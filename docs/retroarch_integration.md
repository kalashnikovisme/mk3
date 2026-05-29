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
2. `RetroArch::Process#start` spawns `retroarch -L [core] [rom] --config [cfg] --no-stdin` in a new process group with stdout/stderr redirected to `/dev/null`.
3. After a 3-second startup pause, `RetroArch::WramReader#attach(pid)` opens `/proc/[pid]/mem`.
4. `RetroArch::Adapter#wait_for_wram` calls `WramReader#scan_for_wram` in a polling loop until the MK3 WRAM region is found.
5. On stop, the adapter releases all keys, sends `QUIT` via UDP, and kills the process group.

## UDP Network Commands

Port 55355 (configured in `retroarch.cfg` via `network_cmd_port`).

| Command       | UDP payload         |
|---------------|---------------------|
| Pause toggle  | `PAUSE_TOGGLE`      |
| Reset         | `RESET`             |
| Save state    | `STATE_SLOT N` then `SAVE_STATE` |
| Load state    | `STATE_SLOT N` then `LOAD_STATE` |
| Screenshot    | `SCREENSHOT`        |
| Quit          | `QUIT`              |

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

## Keyboard Input Injection

`Input::KeyboardInput` uses `xdotool` to inject keydown/keyup events into the RetroArch window.

On `start`, the window ID is found with:
```
xdotool search --name "RetroArch"
```

`send_input(player_index, buttons)` receives a `{ logical_symbol => bool }` hash. It compares against the current per-player key state and only calls `xdotool keydown/keyup` for keys whose state has changed, minimizing overhead.

`release_all(player_index)` sends `keyup` for every currently held key and clears the state.

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
