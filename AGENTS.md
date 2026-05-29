# AGENTS.md

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
