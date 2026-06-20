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
- `Vision::CharacterPositionDetector` — optional Ruby wrapper around the Python CUDA detector (`bin/vision_detect.py --server`) that reads `FrameObservation` screenshots and returns detected character positions before `Core::Observation` is built

**Rule**: Lives outside Core and outside the emulator layer.

### Emulator Adapter

Manages the emulator process, captures frames, and delegates input injection.

- `Emulator::Adapter` — abstract base
- `Emulator::RetroArch::Adapter` — main adapter; builds snapshots containing only the frame counter (all game state comes from vision)
- `Emulator::RetroArch::Process` — spawns/monitors the RetroArch process
- `Emulator::RetroArch::NetworkCommands` — UDP commands (pause/reset/save_state/quit)
- `Emulator::RetroArch::SaveStateReader` — reads RZIP-compressed save-state files; locates the 128 KB WRAM region; used only to read the frame counter
- `Emulator::RetroArch::FrameGrabber` — captures the isolated X display with `xwd`, crops the top-left game region, converts it to PNG, and returns `FrameObservation`
- `Emulator::RetroArch::ConfigBuilder` — generates `retroarch.cfg` with network commands and keyboard bindings

**Rule**: No game-specific memory addresses or button names here.

### Game Adapter

Encodes all knowledge of a specific game.

- Memory map (minimal constants: `MAX_HEALTH`, `TIMER_MAX`, `X_MAX`, `Y_MAX`)
- Input map (logical button → SNES button name, for documentation; `to_logical` converts button arrays to `{ symbol => bool }` hashes)
- Action space (action name → InputSequence)
- Observation space (GameState → Observation)
- Vision state extraction (health bar pixel scan + template matching → fighter health, x/y, timer)
- Reward function
- State extractor (raw snapshot Hash + vision kwargs → GameState)
- Menu navigator (autonomous menu driving via timed button sequences)
- Match lifecycle contract

**Rule**: One adapter per game. Never touches Core or Emulator internals beyond the Adapter interface.

### Agent

Stateless or stateful decision maker.

- Input: `Core::Observation`
- Output: `Core::Action`

Current implementations:
- `Agent::PPOAgent` — self-play PPO agent backed by a shared `Training::Policy`. Uses frame-skip and ε-greedy exploration. Both P1 and P2 share one policy instance so the policy trains against itself.

**Rule**: Agents have no knowledge of emulators, memory addresses, or menus.

### Training

- `Training::Policy` — thin Ruby wrapper around the Python PPO server (`bin/ppo_server.py`). Communicates via newline-delimited JSON over stdin/stdout. Exposes `forward`, `update`, `save`, `load`.
- `Training::TrajectoryBuffer` — collects transitions from both agents; triggers a PPO update when `min_size` is reached.
- `Training::PPOTrainer` — outer training loop: run episode → collect experience → PPO update → checkpoint. Stops automatically if policy entropy collapses.
- `Training::CheckpointManager` — saves/loads `policy.pt` to `models/`.
- `Training::Recorder` — JSONL session recording for imitation learning.

See `docs/ppo_training.md` for full hyperparameter reference.

### Runtime

- `MatchRunner` — drives one match frame-by-frame; detects stale rounds and ends them early.
- `HumanVsAI` — human keyboard passthrough (VirtualInput for P1) + AI agent injection (P2).
- `AIVsAI` — autonomous series of matches.

## Memory Analysis Tools

`lib/memory_analysis/` is a standalone, game-agnostic toolkit for discovering WRAM addresses via brute-force dump comparison. It sits outside the training loop and is invoked only by the `dip memory:*` commands.

| Class | Role |
|-------|------|
| `AddressFinder` | Runs 5 algorithms (monotonic, bracketed, binary-transition, decreasing, stepped) over a set of named WRAM dumps; returns ranked `Candidate` lists |
| `CandidateVerifier` | Loads 120-frame motion sequences; computes per-address stats (monotonicity, avg_delta, Pearson correlation, mirror groups); writes CSVs |
| `P2Finder` | Full-WRAM u16le scan correlated against a reference series; also probes struct-offset candidates |

See `docs/training_dsl.md` for the full workflow and Ruby API.

## Data Flow (one frame)

```
RetroArch (snes9x core)
  → SaveStateReader reads WRAM from save-state file (slot 9)
  → optionally FrameGrabber captures PNG when vision is enabled
    → RetroArch::Adapter#next_frame_snapshot → snapshot Hash
      → GameAdapter#extract_game_state(snapshot, frame_observation:) → GameState
        → GameAdapter#build_observation → Observation
          → Agent#act → Action
            → GameAdapter#action_to_input_sequence → InputSequence
              → GameAdapter#input_sequence_to_buttons → { logical => bool }
                → RetroArch::Adapter#send_input
                  → Input::KeyboardInput#send_input
                    → xdotool keydown/keyup → RetroArch window
                      → snes9x advances one frame
```

All observable game state (health, fighter positions, round timer) is extracted
from the captured frame via vision — WRAM is only read for the frame counter.
Health comes from a pure-Ruby blue-pixel health bar scan (`Vision::HealthBarDetector`).
Positions come from the persistent Python CUDA template detector. Round over is
detected when either fighter's health reaches zero or the timer reaches zero.
