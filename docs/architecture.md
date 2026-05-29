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
┌──────────▼──────────┐
│   Emulator Adapter   │
│   BizHawk::Adapter  │
│   (future: RetroArch)│
└──────────┬──────────┘
           │
┌──────────▼──────────┐
│   BizHawk Process   │
│   (Lua Bridge)      │
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

**Rule**: Core must never `require` anything from `emulator/`, `game/`, or `agent/`.

### Emulator Adapter

Speaks the emulator's protocol. Translates between the emulator's wire format and the Ruby bridge abstractions.

- `Emulator::Adapter` — abstract base
- `Emulator::BizHawk::Adapter` — TCP bridge wrapper
- `Emulator::BizHawk::BridgeServer` — newline-delimited JSON TCP server

**Rule**: No game-specific memory addresses or button names here.

### Game Adapter

Encodes all knowledge of a specific game.

- Memory map (addresses)
- Input map (logical button → BizHawk button string)
- Action space (action name → InputSequence)
- Observation space (GameState → Observation)
- Reward function
- State extractor (raw JSON → GameState)
- Menu navigator (autonomous menu driving)
- Match lifecycle contract

**Rule**: One adapter per game. Never touches Core or Emulator internals beyond the Adapter interface.

### Agent

Stateless or stateful decision maker.

- Input: `Observation`
- Output: `Action`

**Rule**: Agents have no knowledge of emulators, Lua, memory addresses, or menus.

### Training

- `Recorder` — JSONL session recording
- `DatasetExporter` — reads recordings, exports imitation learning pairs

### Runtime

- `MatchRunner` — drives one match frame-by-frame
- `HumanVsAI` — human controller passthrough + AI agent
- `AIVsAI` — autonomous series of matches

## Data Flow (one frame)

```
BizHawk (Lua)
  → TCP JSON frame snapshot
    → BridgeServer#receive_frame
      → BizHawk::Adapter#next_frame_snapshot
        → GameAdapter#extract_game_state → GameState
          → GameAdapter#build_observation → Observation
            → Agent#act → Action
              → GameAdapter#action_to_input_sequence → InputSequence
                → GameAdapter#input_sequence_to_buttons → buttons Hash
                  → BizHawk::Adapter#send_input
                    → BridgeServer → TCP JSON input response
                      → BizHawk (Lua) applies buttons
                        → emu.frameadvance()
```
