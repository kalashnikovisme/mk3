# CLAUDE.md

## Project: FightingAI Framework

Ruby framework for training AI agents to play fighting games through real emulators.

## Key Constraints

- Ruby is the primary language. Python may only appear behind ML adapter boundaries and never in the public API.
- Do not use gym-retro as the primary runtime.
- Core (`lib/fighting_ai/core/`) must have zero knowledge of any specific game, emulator, memory address, or Lua script.
- Emulator adapters (`lib/fighting_ai/emulator/`) must have zero knowledge of any specific game.
- Input devices (`lib/fighting_ai/input/`) must have zero knowledge of any specific game or emulator internals.
- Observation types (`lib/fighting_ai/observation/`) live outside Core and outside the emulator layer.
- Game adapters (`lib/fighting_ai/game/`) contain all game-specific knowledge.
- Agents (`lib/fighting_ai/agent/`) operate only on `Core::Observation` and `Core::Action`.

## Architecture Layers

```
Core → Input Device → Emulator Adapter → Game Adapter → Agent → Runtime → Training
                    ↘ Observation Layer ↗
```

See `docs/architecture.md` for the full diagram and data flow.

## Running Tests

```bash
bundle exec rspec
```

## Adding a New Game

See `docs/adding_new_fighting_game.md`.

## Communication Protocol

RetroArch ↔ Ruby uses two channels:

1. **Input**: xdotool keydown/keyup injected to the RetroArch window (via `Input::KeyboardInput`).
2. **State**: `/proc/[pid]/mem` WRAM reads via `Emulator::RetroArch::WramReader`.
3. **Control**: UDP network commands on port 55355 via `Emulator::RetroArch::NetworkCommands`.

See `docs/retroarch_integration.md`.

## Domain Vocabulary

Use only: Match, Round, Frame, Fighter, FighterState, GameState, Health, Position, Distance, FacingDirection, Move, AnimationState, Combo, Projectile, Hitstun, Blockstun, Knockdown, Wakeup, ControllerInput, InputSequence, Observation, Action, Reward, Policy, Agent, Opponent.

Avoid: Processor, Manager, Handler, Service, Thing, DataObject.
