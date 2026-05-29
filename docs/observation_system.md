# Observation System

## Overview

The Observation layer wraps raw emulator output into typed objects. It sits between the Emulator Adapter and the Game Adapter — emulator adapters produce observation objects, game adapters may consume them for vision-based features.

Observation types live in `FightingAI::Observation`, not in `FightingAI::Core`. Core's `Core::Observation` is the normalized agent-facing vector; `Observation::FrameObservation` is raw emulator output.

## Classes

### `Observation::Provider` (abstract)

```ruby
capture  # → an Observation object
```

### `Observation::FrameObservation`

Wraps a path to a PNG screenshot captured by `RetroArch::FrameGrabber`.

```ruby
frame = Observation::FrameObservation.new("/tmp/fighting_ai/screenshots/frame_001.png")

frame.path    # → String, absolute PNG path
frame.width   # → Integer (lazy, parsed from PNG IHDR)
frame.height  # → Integer (lazy, parsed from PNG IHDR)
frame.pixels  # → Array of [r, g, b] triples (lazy, decoded from PNG IDAT)
frame.to_tensor  # → flat Float Array, values in [0.0, 1.0], row-major, channels last
```

Pixel decoding is pure Ruby using `Zlib::Inflate` on the PNG IDAT chunks. No external image library is required.

`pixels` and `to_tensor` are memoized after the first call.

### `Observation::MemoryObservation`

Stub for a future structured observation built directly from WRAM values rather than pixel data. Wraps a raw snapshot hash from `WramReader`.

```ruby
obs = Observation::MemoryObservation.new(snapshot_hash)
obs.snapshot  # → Hash
```

## Relationship to `Core::Observation`

`Core::Observation` is the normalized float vector that agents receive. It is produced by `Game::Adapter#build_observation` from a `Core::GameState`. `FrameObservation` is a separate concept — raw pixels for potential future vision-based agents — and is never passed to agents directly in the current architecture.
