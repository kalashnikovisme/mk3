# Scenario DSL

Scenario files let you script precise frame-level input sequences against a live RetroArch match state.
Run with `dip scenario` (uses `scenario.rb` in the project root) or `dip scenario path/to/file.rb`.

## Top-level methods

### `save_memory(name = nil)`

Captures a raw binary WRAM snapshot (exactly 131072 bytes) and writes it to `/app/data/memory/<name>.bin`. Intermediate directories are created automatically, so `"p1_x/frame_0"` produces `/app/data/memory/p1_x/frame_0.bin`. If `name` is omitted, the file is named by timestamp.

The first call in each scenario session also prints the memory source, SNES bus base address, and size to stdout.

```ruby
save_memory "idle"            # → /app/data/memory/idle.bin
save_memory "p1_x/r1"        # → /app/data/memory/p1_x/r1.bin
save_memory                   # → /app/data/memory/20260101_120000.bin
```

### `save_state(name = nil)`

Saves the current RetroArch state and copies it to `/app/data/states/<name>.state`. If `name` is omitted, named by timestamp.

```ruby
save_state "after_ice_ball"   # → /app/data/states/after_ice_ball.state
save_state                    # → /app/data/states/20260101_120000.state
```

### `screenshot(name = nil)`

Captures the current X server framebuffer for the isolated RetroArch display and
writes a PNG to `/app/data/screenshots/<name>.png`. Intermediate directories are
created automatically, so `"vision/idle"` produces
`/app/data/screenshots/vision/idle.png`. If `name` is omitted, the file is named
by timestamp.

```ruby
screenshot "vision/idle"      # → /app/data/screenshots/vision/idle.png
screenshot                    # → /app/data/screenshots/20260101_120000.png
```

The capture uses `xwd` against the internal display (`:99` by default), then
ImageMagick crops the top-left `297x216` pixels and writes that region as PNG.
This is the same X-server screenshot path used by runtime vision capture and
does not use RetroArch's `SCREENSHOT` UDP command.

If `screenshot` reports that `xwd` or `convert` is missing, rebuild the container
with `dip provision`; those tools are installed by the development image.

### `reload_state`

Reloads the initial match state that was installed when the scenario started. Resets fighter positions, health, timer, and all game variables to the saved state. Use between independent test sections so each section starts from a known baseline.

```ruby
save_memory "p1_x/idle"
P1.right 1
save_memory "p1_x/r1"

reload_state   # ← back to the initial state

save_memory "p2_x/idle"
P2.left 1
save_memory "p2_x/l1"
```

### `speed(preset_or_multiplier)`

Sets the timing between input frames for all subsequent calls. Call it once at the top of the file.

```ruby
speed :normal   # 1× — one input per SNES frame (1/60 s)
speed :fast     # 2× — inputs sent twice as fast
speed :turbo    # 10× — near-instant execution
speed :slow     # 0.5× — half speed (1/30 s per frame)
speed :slow_mo  # 0.25× — quarter speed (1/15 s per frame)
speed 3.0       # numeric multiplier — 3× normal speed
```

### `wait(frames)`

Releases all inputs on both players and pauses for N frames at the current speed.

```ruby
wait 60   # pause for 1 second at normal speed
wait 10
```

---

## Player objects — `P1` and `P2`

Both objects expose identical methods. Every method holds the relevant buttons for the given number of frames, then releases them.

### Movement

| Method | Buttons held | Default frames |
|---|---|---|
| `P1.right(n)` | Right | 1 |
| `P1.left(n)` | Left | 1 |
| `P1.up(n)` | Up | 1 |
| `P1.down(n)` | Down | 1 |

### Attacks

| Method | Buttons held | Default frames |
|---|---|---|
| `P1.low_punch(n)` | Y | 1 |
| `P1.high_punch(n)` | X | 1 |
| `P1.low_kick(n)` | B | 1 |
| `P1.high_kick(n)` | A | 1 |

### Defence

| Method | Buttons held | Default frames |
|---|---|---|
| `P1.block(n)` | L | 1 |
| `P1.run(n)` | R | 1 |

### Combined inputs

| Method | Buttons held simultaneously | Default frames |
|---|---|---|
| `P1.crouch_punch(n)` | Down + Y | 1 |
| `P1.crouch_kick(n)` | Down + B | 1 |
| `P1.jump_punch(n)` | Up + X | 1 |
| `P1.jump_kick(n)` | Up + A | 1 |
| `P1.throw(n)` | Y + X | 1 |

### Timing

| Method | Description |
|---|---|
| `P1.wait(n)` | Release all P1 inputs, pause n frames |

---

## Example scenario

```ruby
speed :normal

# P1 walks in and lands a combo
P1.right 15
P1.low_punch
P1.wait 2
P1.high_punch
P1.wait 2
P1.high_kick

# P2 tries to block and counter
P2.block 10
P2.wait 5
P2.low_punch

wait 30   # let the dust settle
```

---

## How it works

- Each method call sends `xdotool keydown` / `keyup` events directly to the RetroArch window.
- `speed` adjusts the sleep duration between individual frame inputs — it does not change RetroArch's emulation clock.
- `P1.right(3)` holds the right key for 3 SNES frames (at `:normal` speed: 3 × 1/60 s ≈ 50 ms), then releases it.
- The scenario file is `load`-ed after the match state is installed, so RetroArch is already in-fight when the first line executes.
