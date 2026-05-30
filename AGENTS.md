# AGENTS.md

## Development Environment

**All commands must run inside the dip configuration.** Do not run Ruby, Python, or system binaries directly on the host.

```bash
dip provision   # first-time setup: build image, install gems and Python packages
dip learn       # start PPO self-play training
dip rspec       # run tests
dip shell       # interactive shell in the container
```

## Understanding the Codebase

**Always read `docs/` before diving into source files.** The docs are the authoritative description of how the system works, not the code.

- `docs/architecture.md` — full layer diagram and data flow
- `docs/game_adapter_contract.md` — what a game adapter must implement
- `docs/observation_system.md` — how observations are built from game state
- `docs/input_system.md` — how actions become key presses
- `docs/training_dsl.md` — training loop, PPO pipeline, reward structure

## Keeping Docs Current

**Updating `docs/` is a required step of every task that involves code changes. A task is not done until the relevant docs are updated.**

Before finishing any task:
1. Identify which `docs/` files are affected.
2. Update or extend them to reflect the new reality.
3. If no existing doc covers the topic, add a section to the most relevant one.

Do not leave docs stale. This applies to every change: memory addresses, protocols, new components, reward structures, agent behaviour, training configuration.

**Do not read `mk3.md` or `mk3.sfc`** — both are binary ROM files.

## Agent Contract

All agents inherit from `FightingAI::Agent::Base`.

### Interface

```ruby
# Required: return a Core::Action given a Core::Observation
def act(observation) → Core::Action

# Optional lifecycle hooks
def on_match_start(match)
def on_match_end(match, result)
def on_round_start(round)
def on_round_end(round)
```

### Rules

- Agents receive only `Core::Observation` (normalized floats, no memory addresses).
- Agents return only `Core::Action` (symbolic name, no button codes).
- Agents have no knowledge of emulator internals, Lua, BizHawk, memory maps, or menus.
- Agents are stateless by default; stateful agents manage their own state in instance variables.

## Implemented Agents

### RuleBased (`lib/fighting_ai/agent/rule_based.rb`)

Deterministic decision tree. Strategy:
- If opponent is stunned/knocked down → attack.
- If low health and close → block.
- If in hitstun/blockstun → idle.
- If close range → combo attacks.
- If medium range → advance and punch.
- Otherwise → walk forward.

Thresholds:
- Close: distance < 0.15
- Medium: distance < 0.35
- Low health: health < 30%

## Planned Agents

- `ImitationLearning` — trained on recorded human sessions (Python ML adapter behind boundary).
- `ReinforcementLearning` — trained via self-play (Python ML adapter behind boundary).
- `GreedyPolicy` — always chooses highest-reward action according to reward function.

## Human Passthrough

`Runtime::HumanVsAI::HumanPassthrough` is a special agent that returns `Action::IDLE`, causing the runtime to inject no buttons for that player side. The human's physical controller inputs flow directly through BizHawk.
