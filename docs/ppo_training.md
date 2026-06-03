# PPO Self-Play Training

## Overview

Both players share a single `PPOAgent` backed by one `Training::Policy` (Python/PyTorch subprocess).
The policy is trained by self-play: both P1 and P2 experience are pushed into the same `TrajectoryBuffer`, so the policy trains against itself.

A `SideNormalizer` flips the observation so the policy always sees itself on the left side of the screen, eliminating the need to learn separate left/right behaviours.

## Running

```bash
dip learn                          # headless
dip learn_watch                    # with Xephyr window on host desktop
dip learn sub-zero-vs-sindel       # specific match state
dip learn sub-zero-vs-sindel debug # verbose + per-second WRAM dump to data/memory/
```

Vision training is enabled by default and uses the same persistent Python CUDA
detector as `dip vision:detect`:

```bash
dip learn sub-zero-vs-sub-zero
VISION_ACTION=front_kick VISION_AREAS="40,104,72,120;152,104,72,120" dip learn sub-zero-vs-sub-zero
VISION_ACTION=idle dip learn sub-zero-vs-sub-zero
VISION=0 dip learn sub-zero-vs-sub-zero
```

If `VISION_ACTION` is omitted, learning uses `all` and scans every non-reference
action template inside the active ROIs. `VISION_ACTION` accepts the same action
modes as `dip vision:detect`; use `VISION_ACTION=idle` for faster
startup-stance-only detection. When `VISION_AREAS` is omitted, the detector uses
the default initial stance ROIs. `dip learn` runs through the GPU Compose service
so the detector can use CUDA.

## Training Status Bar

During non-debug `dip learn` runs, the PPO status bar prints the latest
post-extraction fighter positions. When vision is enabled, these are the
vision-detected positions after scaling into the MK3 coordinate range; when
vision is disabled, they are the WRAM-derived positions.

The `screen` segment draws a fixed-width horizontal line for the MK3 screen
coordinate range (`PPODisplay::POSITION_MIN..MemoryMap::X_MAX`). The blue dot is
the left detected character and the red dot is the right detected character, so
the dots move as the detected `x` positions change:

```text
screen |-----●-------------------●------|
```

## Action Space

Defined in `lib/fighting_ai/game/mortal_kombat_3/action_translator.rb`.

| Index | Action | Game mapping |
|-------|--------|-------------|
| 0 | `forward` | `walk_forward` |
| 1 | `backward` | `walk_back` |
| 2 | `block` | `block` |
| 3 | `high_punch` | `high_punch` |
| 4 | `low_punch` | `low_punch` |
| 5 | `high_kick` | `high_kick` |
| 6 | `low_kick` | `low_kick` |

Idle is intentionally absent from the action space.

## Reward Function

Defined in `lib/fighting_ai/game/mortal_kombat_3/reward_function.rb`.
Weights defined in `lib/fighting_ai/game/reward_calculator.rb`.

| Component | Weight | Formula |
|-----------|--------|---------|
| `damage_dealt` | +10 | `(opp_prev.health − opp_next.health) × 10` per step |
| `damage_taken` | −5 | `(me_prev.health − me_next.health) × 5` per step |
| `distance` | ±1 | `(closeness × 2 − 1) × 1` where `closeness = 1 − dist / 255`; +1 adjacent, −1 at max separation |
| `round_win` | +200 | flat bonus on round win |
| `round_loss` | −200 | flat penalty on round loss |
| `round_draw` | −100 | flat penalty on draw |
| `stale` | −100 | flat penalty when HP unchanged for `STALL_TIMEOUT` seconds |

The distance component is computed per `next_frame_snapshot` step and accumulated across the FRAME_SKIP window.

## PPO Agent

File: `lib/fighting_ai/agent/ppo_agent.rb`

| Parameter | Value | Description |
|-----------|-------|-------------|
| `FRAME_SKIP` | 2 | Frames between policy decisions. Same action is repeated and rewards accumulated within each window. |
| `exploration` | 0.2 | Fraction of decisions taken as uniform random (ε-greedy). The remaining 80% use the policy. |

## PPO Hyperparameters

File: `bin/ppo_server.py`

| Parameter | Value | Description |
|-----------|-------|-------------|
| `LEARNING_RATE` | 3e-4 | Adam optimiser learning rate |
| `CLIP_EPS` | 0.3 | PPO clipping range for policy ratio |
| `VALUE_COEF` | 0.5 | Value loss coefficient |
| `ENTROPY_COEF` | 0.30 | Entropy bonus coefficient — higher values force more exploration |
| `GAE_LAMBDA` | 0.95 | GAE λ for advantage estimation |
| `GAMMA` | 0.99 | Discount factor |
| `PPO_EPOCHS` | 8 | Gradient passes per collected batch |
| `MINI_BATCH_SIZE` | 64 | Mini-batch size per gradient step |

## Match Runner

File: `lib/fighting_ai/runtime/match_runner.rb`

| Parameter | Value | Description |
|-----------|-------|-------------|
| `STALL_TIMEOUT` | 5.0 s | Round ends as stale if HP is unchanged for this duration |

## Training Loop

File: `lib/fighting_ai/training/ppo_trainer.rb`

| Parameter | Value | Description |
|-----------|-------|-------------|
| `UPDATE_EVERY_EPISODES` | 5 | PPO update runs after every N episodes (if buffer is ready) |
| `ENTROPY_COLLAPSE_THRESHOLD` | 1e-6 | Entropy below this is considered collapsed |
| `ENTROPY_COLLAPSE_STOP_AFTER` | 2 | Training stops if entropy is collapsed for this many consecutive PPO updates |

## Entropy Collapse Detection

If the policy entropy falls below `1e-6` for 2 consecutive PPO updates, training stops automatically with exit code 1. This prevents wasting compute on a fully collapsed (deterministic) policy that cannot recover on its own. Restart training — possibly with a higher `ENTROPY_COEF` or lower reward weights — if this occurs.

## Network Architecture

File: `bin/ppo_server.py` — `ActorCritic`

```
obs (18-dim) → Linear(18→64) → ReLU → Linear(64→64) → ReLU
                                                          ├── actor:  Linear(64→7)  → logits → Categorical
                                                          └── critic: Linear(64→1)  → value
```

Observation dimension: 18 (`OBS_DIM` in `bin/learn`).
Action dimension: 7 (length of `ActionTranslator::ACTIONS`).

## Checkpoints

Saved to `models/` after every PPO update. Resumed automatically on the next `dip learn` run.
Manual path: `dip learn_from_ppo <path>`.
