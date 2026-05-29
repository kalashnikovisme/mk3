# Input System

## Overview

The Input layer abstracts controller input injection into the emulator. All devices receive a logical button hash `{ symbol => bool }` — game-specific knowledge stops at the Game Adapter boundary.

## Logical Button Hash

```ruby
{ up: bool, down: bool, left: bool, right: bool,
  low_punch: bool, high_punch: bool,
  low_kick: bool, high_kick: bool,
  block: bool, run: bool }
```

## Device Classes

### `Input::Device` (abstract)

```ruby
start                              # acquire resources (window ID, file descriptor, etc.)
stop                               # release all keys and resources
send_input(player_index, buttons)  # apply the logical button hash
release_all(player_index)          # unconditionally release every held key
```

### `Input::KeyboardInput`

Injects keyboard events into the RetroArch window using `xdotool`.

- On `start`, finds the RetroArch window with `xdotool search --name "RetroArch"`. If the window is not found, `send_input` is a no-op (graceful degradation for headless environments).
- Per-player key state is tracked in `@key_state`. `send_input` only calls `xdotool` for keys whose state has changed, avoiding redundant system calls.
- `release_all` sends `keyup` for every currently pressed key and clears the state.

#### P1 Key Map (RetroArch config → xdotool key name)

| Logical   | xdotool key |
|-----------|-------------|
| up        | Up          |
| down      | Down        |
| left      | Left        |
| right     | Right       |
| low_punch | s (Y btn)   |
| high_punch| a (X btn)   |
| low_kick  | x (B btn)   |
| high_kick | z (A btn)   |
| block     | q (L btn)   |
| run       | w (R btn)   |

#### P2 Key Map

| Logical   | xdotool key |
|-----------|-------------|
| up        | t           |
| down      | g           |
| left      | f           |
| right     | h           |
| low_punch | n (Y btn)   |
| high_punch| c (X btn)   |
| low_kick  | b (B btn)   |
| high_kick | v (A btn)   |
| block     | r (L btn)   |
| run       | y (R btn)   |

### `Input::VirtualInput`

No-op device. Used for the human player in Human vs AI mode — the human's physical keyboard drives RetroArch directly, so no injection is needed. All methods are empty.

### `Input::UinputDevice`

Stub for a future uinput-based virtual gamepad. uinput creates a kernel-level device that RetroArch sees as a real gamepad, removing the window-focus dependency of xdotool. All methods raise `NotImplementedError`.

## Usage

```ruby
keyboard = FightingAI::Input::KeyboardInput.new
keyboard.start

keyboard.send_input(1, { up: true, low_punch: true, down: false, ... })
keyboard.release_all(1)

keyboard.stop
```

The RetroArch adapter owns the keyboard device and calls `release_all` on `send_noop` and `stop`.
