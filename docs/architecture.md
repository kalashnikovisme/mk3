# Architecture

FightingAI is a layered Ruby framework for training AI agents to play fighting games through real emulators.

## Layer Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                          User (Ruby DSL)                        │
└────────────────────────────┬────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────┐
│                         Runtime                                 │
│         HumanVsAI  │  AIVsAI  │  MatchRunner                   │
└────────────────────────────┬────────────────────────────────────┘
                             │
           ┌─────────────────┴──────────────────┐
           │                                    │
┌──────────▼──────────┐             ┌───────────▼───────────┐
│    Game Adapter      │             │    Agent               │
│  MortalKombat3       │             │  RuleBased             │
│  StreetFighter2      │             │  (future: Neural)      │
│  KillerInstinct      │             └───────────────────────┘
└──────────┬──────────┘
           │
┌──────────▼──────────────────────────────┐
│         Emulator Adapter                │
│   RetroArch::Adapter                    │
│     ├── RetroArch::Process              │
│     ├── RetroArch::NetworkCommands      │
│     ├── RetroArch::WramReader           │
│     └── RetroArch::FrameGrabber        │
└──────────┬──────────────────────────────┘
           │
     ┌─────┴────────────┐
     │                  │
┌────▼────┐     ┌───────▼────────┐
│  Input  │     │  Observation   │
│  Layer  │     │  Layer         │
│ Keyboard│     │ FrameObservat. │
│ Virtual │     │ MemoryObservat.│
│ Uinput  │     └────────────────┘
└─────────┘
     │
┌────▼────────────────┐
│   RetroArch Process │
│   (snes9x core)     │
└─────────────────────┘
```

## Layers

### Core

Pure domain model. No emulator, no game specifics.

- `Match`, `Round`, `Frame` — match lifecycle
- `GameState`, `FighterState` — snapshot of game at one frame
- `Observation` — normalized agent-facing view
- `Action` — discrete agent decision
- `Reward` — scalar + components
- `InputSequence` — timed button press chain

**Rule**: Core must never `require` anything from `emulator/`, `game/`, `agent/`, `input/`, or `observation/`.

### Input Layer

Abstracts physical input injection into the emulator window.

- `Input::Device` — abstract base
- `Input::KeyboardInput` — xdotool keydown/keyup to the RetroArch window; tracks per-player key state and only fires xdotool for changed keys
- `Input::VirtualInput` — no-op device; used for the human player so their physical keyboard flows through RetroArch unmodified
- `Input::UinputDevice` — future uinput virtual gamepad (stub)

**Rule**: No game-specific knowledge here. Receives logical button hashes `{ up: bool, low_punch: bool, ... }`.

### Observation Layer

Wraps emulator output into observation objects for downstream use.

- `Observation::FrameObservation` — wraps a PNG path; lazy-loads pixels, dimensions, and normalized tensor
- `Observation::MemoryObservation` — future WRAM-based structured observation (stub)

**Rule**: Lives outside Core and outside the emulator layer.

### Emulator Adapter

Manages the emulator process, reads game state from WRAM, and delegates input injection.

- `Emulator::Adapter` — abstract base
- `Emulator::RetroArch::Adapter` — main adapter
- `Emulator::RetroArch::Process` — spawns/monitors the RetroArch process
- `Emulator::RetroArch::NetworkCommands` — UDP commands (pause/reset/save_state/screenshot/quit)
- `Emulator::RetroArch::WramReader` — reads `/proc/[pid]/mem`; scans for MK3 WRAM region; provides `read_u8` / `read_u16_le`
- `Emulator::RetroArch::FrameGrabber` — triggers screenshot, polls for new PNG, returns `FrameObservation`
- `Emulator::RetroArch::ConfigBuilder` — generates `retroarch.cfg` with network commands and keyboard bindings

**Rule**: No game-specific memory addresses or button names here. The WRAM snapshot is built by the adapter reading addresses supplied by the game layer's `MemoryMap`.

### Game Adapter

Encodes all knowledge of a specific game.

- Memory map (WRAM addresses)
- Input map (logical button → SNES button name, for documentation; `to_logical` converts button arrays to `{ symbol => bool }` hashes)
- Action space (action name → InputSequence)
- Observation space (GameState → Observation)
- Reward function
- State extractor (raw snapshot Hash → GameState)
- Menu navigator (autonomous menu driving via timed button sequences)
- Match lifecycle contract

**Rule**: One adapter per game. Never touches Core or Emulator internals beyond the Adapter interface.

### Agent

Stateless or stateful decision maker.

- Input: `Core::Observation`
- Output: `Core::Action`

**Rule**: Agents have no knowledge of emulators, memory addresses, or menus.

### Training

- `Recorder` — JSONL session recording
- `DatasetExporter` — reads recordings, exports imitation learning pairs

### Runtime

- `MatchRunner` — drives one match frame-by-frame
- `HumanVsAI` — human keyboard passthrough (VirtualInput for P1) + AI agent injection (P2)
- `AIVsAI` — autonomous series of matches

## Data Flow (one frame)

```
RetroArch (snes9x core)
  → WramReader reads /proc/[pid]/mem
    → RetroArch::Adapter#next_frame_snapshot → snapshot Hash
      → GameAdapter#extract_game_state → GameState
        → GameAdapter#build_observation → Observation
          → Agent#act → Action
            → GameAdapter#action_to_input_sequence → InputSequence
              → GameAdapter#input_sequence_to_buttons → { logical => bool }
                → RetroArch::Adapter#send_input
                  → Input::KeyboardInput#send_input
                    → xdotool keydown/keyup → RetroArch window
                      → snes9x advances one frame
```
