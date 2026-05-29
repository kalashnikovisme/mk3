# Scenario DSL

Scenario files let you script precise frame-level input sequences against a live RetroArch match state.
Run with `dip scenario` (uses `scenario.rb` in the project root) or `dip scenario path/to/file.rb`.

## Top-level methods

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
