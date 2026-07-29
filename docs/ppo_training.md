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
VISION_ACTION=front_kick VISION_AREAS="36,96,96,120;164,96,96,120" dip learn sub-zero-vs-sub-zero
VISION_ACTION=idle dip learn sub-zero-vs-sub-zero
VISION=0 dip learn sub-zero-vs-sub-zero
```

If `VISION_ACTION` is omitted, learning uses `all` and scans every non-reference
action template inside the active ROIs. `VISION_ACTION` accepts the same action
modes as `dip vision:detect`; use `VISION_ACTION=idle` for faster
startup-stance-only detection. When `VISION_AREAS` is omitted, the detector uses
the default initial stance ROIs. `dip learn` runs through the GPU Compose service
so the detector can use CUDA.

## PPO Evaluation Fights

`dip fight` and `dip fight_watch` run trained PPO policies against each other.
Both commands enable runtime vision by default and pass vision-overridden
positions into the same observation vector used during training. `dip fight`
runs through the GPU Compose service; `dip fight_watch` uses the watch service,
which also extends the GPU service.

Use `VISION=0` to evaluate with WRAM-derived positions only:

```bash
VISION=0 dip fight data/matches/sub-zero-vs-sub-zero.state models/ppo_10 models/ppo_5
VISION=0 dip fight_watch data/matches/sub-zero-vs-sub-zero.state models/ppo_10 models/ppo_5
```

## Training Status Bar

During non-debug `dip learn` runs, the PPO status bar prints the latest
post-extraction fighter positions. When vision is enabled, these are the
vision-detected positions after scaling into the MK3 coordinate range; when
vision is disabled, they are the WRAM-derived positions.

`dip learn_watch` refreshes the status display every frame. In watch mode the
position chart is suppressed, so both the on-screen block and the log file keep
only the main episode/status line. In watch mode the status line is shortened
to the episode, timer, health, position, and fight state fields that fit on one
row. The status block is cursor-anchored so other terminal messages do not push
it downward, and Ctrl+C clears the current line before printing `Stopped.`. The
watch display is detected from the host watch scene, so the compact view stays
active whenever the Xephyr watch window is running. The UI also
opens a second `ffplay` window named
`Reconstructed Scene` next to RetroArch and renders the detected sprite
rectangles at their current coordinates. The window also shows a visible
placeholder frame immediately, even before the first vision snapshot is ready.
If `ffplay` is missing from the watch image, that reconstruction window will
not appear.
The live block shows:

```text
Ep 0012 │ The Rooftop │ t:87 │ P1 ... │ P2 ... │ [fight] │ buf 128/512
```

Per-frame fight logs now stay on this single-line status format in every mode.
They no longer record the `raw`, `mk3`, or `roi` chart lines.

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
| `close_range` | +2 | positive only inside the preferred spacing band; peaks near the band midpoint |
| `approach` | +14 | `((prev_distance - next_distance) / MAX_FIGHT_DISTANCE) × 14` only when `prev_distance` is in the far band |
| `distance_reset` | +20 | `((next_distance - prev_distance) / MAX_FIGHT_DISTANCE) × 20` only when `prev_distance` is in the too-close band |
| `distance_escape` | +16 | flat bonus when the fighters move from the too-close band back into the preferred spacing band |
| `too_close` | −8 | flat penalty whenever the fighters stay inside the too-close band |
| `round_win` | +200 | flat bonus on round win |
| `round_loss` | −200 | flat penalty on round loss |
| `round_draw` | −100 | flat penalty on draw |
| `stale` | −25 | flat penalty when HP and fighter spacing are both unchanged for `STALL_TIMEOUT` seconds |

The dense learning signal is now split across five spacing regimes. `approach` rewards closing distance only when the fighters are too far apart, `close_range` rewards maintaining a preferred neutral band, `too_close` penalizes lingering in point-blank range, `distance_reset` rewards backing out after the fighters become too close, and `distance_escape` gives a discrete bonus for actually returning from point-blank range into the neutral band. This prevents the policy from learning a single always-rush or always-retreat objective and makes disengagement easier to learn.

Before PPO sees a transition, `Agent::PPOAgent` clips each accumulated reward to `±15` and scales it by `0.1`. The reward components in the logs remain raw, but the training signal is intentionally compressed to reduce variance and early entropy collapse.

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
| `ENTROPY_COEF` | 0.50 | Entropy bonus coefficient — higher values force more exploration |
| `GAE_LAMBDA` | 0.95 | GAE λ for advantage estimation |
| `GAMMA` | 0.99 | Discount factor |
| `PPO_EPOCHS` | 8 | Gradient passes per collected batch |
| `MINI_BATCH_SIZE` | 64 | Mini-batch size per gradient step |

## Match Runner

File: `lib/fighting_ai/runtime/match_runner.rb`

| Parameter | Value | Description |
|-----------|-------|-------------|
| `STALL_TIMEOUT` | 8.0 s | Round ends as stale only if HP and spacing are both unchanged for this duration |
| `stale_distance_reset_threshold` | 6 | Any fighter-spacing change at or above this threshold resets the stale timer |

### Per-frame timing logs

`dip learn` and `dip learn_watch` write one block per runtime iteration to
`data/fight_logs/episode_%05d.log`. Timing values are rounded milliseconds:

| Field | Measured work |
|-------|---------------|
| `snapshot_ms` | Emulator step wait and snapshot construction |
| `capture_ms` | Fetching the latest screenshot from the streaming frame grabber |
| `detect_ms` | Synchronous health detection and vision-result submission/readback |
| `agents_ms` | Rewards, observation construction, both PPO agent decisions, action translation, and input injection including `xdotool` calls |
| `runtime_ms` | All work after detection, including UI/status updates, frame bookkeeping, stale/round checks, and `agents_ms` |
| `fight_log_ms` | Writing and flushing the frame data fields to the fight log |
| `total_ms` | End-to-end iteration time from before the emulator step through the main fight-log write |

`runtime_ms` includes `agents_ms`, so those fields must not be added together.
The final two timing lines written after the measured fight-log flush are not
included in `total_ms`.

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
obs (7-dim) → Linear(7→64) → ReLU → Linear(64→64) → ReLU
                                                         ├── actor:  Linear(64→7)  → logits → Categorical
                                                         └── critic: Linear(64→1)  → value
```

Observation dimension: 7 (`OBS_DIM` in `bin/learn`).
Action dimension: 7 (length of `ActionTranslator::ACTIONS`).

Observation vector layout (all floats, range [0, 1]):
| Index | Field |
|-------|-------|
| 0 | `my_health_pct` |
| 1 | `opponent_health_pct` |
| 2 | `my_x_normalized` |
| 3 | `my_y_normalized` |
| 4 | `opponent_x_normalized` |
| 5 | `opponent_y_normalized` |
| 6 | `round_time_normalized` |

All values come from vision only (health bar pixel scan + template matching). WRAM is no longer used for observation fields.

## Checkpoints

Saved to `models/` after every PPO update. Resumed automatically on the next `dip learn` run.
Manual path: `dip learn_from_ppo <path>`. `<path>` may be either a checkpoint directory such as `models/ppo_15` or the nested file path `models/ppo_15/policy.pt`.

Automatic resume only loads checkpoints whose saved model state matches the current observation and action dimensions. If `models/latest` points at an older incompatible checkpoint, `dip learn` prints a warning and starts a fresh policy instead of crashing. Manual restore still raises an error for an incompatible checkpoint so the mismatch is visible immediately.
