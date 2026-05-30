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

## Development Environment

**All commands must run inside the dip configuration.** Never invoke Ruby, Python, or system tools directly on the host.

```bash
dip provision          # build image, install Ruby gems and Python packages
dip learn              # PPO self-play training (auto-resumes from checkpoint)
dip rspec              # run the test suite
dip rubocop            # lint
dip scenario           # run a scenario script
dip shell              # open a shell inside the container
```

The container has RetroArch, Python 3, and PyTorch available.
Ruby gems are persisted in the `bundle` Docker volume; Python packages in the `pip` volume.
Re-run `dip provision` after changing `Gemfile` or `requirements.txt`.

## Running Tests

```bash
dip rspec
```

## Adding a New Game

See `docs/adding_new_fighting_game.md`.

## Understanding the Codebase

**Always read `docs/` before reading source files.** The docs are the authoritative description of how the system works.

- `docs/architecture.md` — layer diagram, data flow, module boundaries
- `docs/retroarch_integration.md` — display setup, xdotool, WRAM reading, UDP commands, keyboard config
- `docs/input_system.md` — how keyboard input maps to game actions
- `docs/observation_system.md` — observation/state extraction pipeline
- `docs/game_adapter_contract.md` — contract that game adapters must satisfy
- `docs/adding_new_fighting_game.md` — step-by-step guide for new games
- `docs/training_dsl.md` — training loop and recorder

## Keeping Docs Current

**Every architectural or principled change must be reflected in `docs/` before the task is considered done.**

This includes: new layers or components, changed protocols or data flows, renamed abstractions, new training modes, changed reward structure, new agent types, or any decision that future developers would need to understand.

If docs don't cover something, add or update the relevant file. Do not leave docs stale after significant changes.

**Do not read `mk3.md` or `mk3.sfc`** — both are binary ROM files. `mk3.sfc` is the SNES ROM used at runtime; `mk3.md` is a leftover Genesis ROM (wrong format, not used).

## Communication Protocol

RetroArch ↔ Ruby uses two channels:

1. **Input**: xdotool keydown/keyup injected to the RetroArch window (via `Input::KeyboardInput`).
2. **State**: Save-state file reads via `Emulator::RetroArch::SaveStateReader` (WRAM extracted from snes9x `.state` files).
3. **Control**: UDP network commands on port 55355 via `Emulator::RetroArch::NetworkCommands`.

See `docs/retroarch_integration.md`.

## Domain Vocabulary

Use only: Match, Round, Frame, Fighter, FighterState, GameState, Health, Position, Distance, FacingDirection, Move, AnimationState, Combo, Projectile, Hitstun, Blockstun, Knockdown, Wakeup, ControllerInput, InputSequence, Observation, Action, Reward, Policy, Agent, Opponent.

Avoid: Processor, Manager, Handler, Service, Thing, DataObject.
