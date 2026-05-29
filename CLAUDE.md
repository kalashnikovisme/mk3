# CLAUDE.md

## Project: FightingAI Framework

Ruby framework for training AI agents to play fighting games through real emulators.

## Key Constraints

- Ruby is the primary language. Python may only appear behind ML adapter boundaries and never in the public API.
- Do not use gym-retro as the primary runtime.
- Core (`lib/fighting_ai/core/`) must have zero knowledge of any specific game, emulator, memory address, or Lua script.
- Emulator adapters (`lib/fighting_ai/emulator/`) must have zero knowledge of any specific game.
- Game adapters (`lib/fighting_ai/game/`) contain all game-specific knowledge.
- Agents (`lib/fighting_ai/agent/`) operate only on `Core::Observation` and `Core::Action`.

## Architecture Layers

```
Core → Emulator Adapter → Game Adapter → Agent → Runtime → Training
```

See `docs/architecture.md` for the full diagram and data flow.

## Running Tests

```bash
bundle exec rspec
```

## Adding a New Game

See `docs/adding_new_fighting_game.md`.

## Communication Protocol

BizHawk ↔ Ruby uses newline-delimited JSON over TCP (port 7878 by default).

See `docs/emulator_bridge.md`.

## Domain Vocabulary

Use only: Match, Round, Frame, Fighter, FighterState, GameState, Health, Position, Distance, FacingDirection, Move, AnimationState, Combo, Projectile, Hitstun, Blockstun, Knockdown, Wakeup, ControllerInput, InputSequence, Observation, Action, Reward, Policy, Agent, Opponent.

Avoid: Processor, Manager, Handler, Service, Thing, DataObject.
