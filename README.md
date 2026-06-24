# FightingAI

Ruby framework for training AI agents to play fighting games through real emulators.

## Local Development

### Prerequisites

Allow Docker to connect to your X display (run once per session):

```bash
xhost +local:docker
```

### Installing Dip

**macOS / Linux (Homebrew):**
```bash
brew tap bibendi/dip
brew install dip
```

**Linux (RubyGems):**
```bash
gem install dip
```

**Windows:** Use WSL2, then follow the Linux instructions inside WSL.

**Any OS with Ruby:**
```bash
gem install dip
```

Precompiled binaries are also available at the [Dip releases page](https://github.com/bibendi/dip/releases).

### Setup

```bash
dip provision
```

This builds the Docker image (Ruby 4.0 + RetroArch + xdotool + X screenshot tools), installs gem dependencies, and grants X11 access.

### Daily Commands

| Command | Description |
|---|---|
| `dip shell` | Open a shell in the container |
| `dip bundle` | Run bundler |
| `dip ruby` | Run a Ruby script |
| `dip rspec` | Run RSpec tests |
| `dip rubocop` | Run RuboCop linter |
| `dip learn` | Record AI vs AI self-play to `data/recordings/mk3/` |
| `dip learn_empty [health] [time] [positions] [match-name]` | Write frame sizes and selected detector values to per-episode logs |
| `dip watch-match` | Replay a recorded match |
| `dip play-vs-ai` | Play against the trained AI |

### Notes

- `dip learn`, `dip watch-match`, and `dip play-vs-ai` open a RetroArch window on your host display via X11 forwarding. Run `xhost +local:docker` if the window fails to appear.
- Match save states live in `data/matches/`. At least one `.state` file is required before running `dip learn`.
- ROM (`mk3.sfc`) and the snes9x libretro core are expected at their default paths inside the container.

## Vision Detection

`dip vision:detect` runs Sub-Zero sprite template detection against one or more screenshots and prints per-player positions, detected actions, health, and the round timer.

```bash
dip vision:detect [action_mode] [--verbose] <screenshot.png> [more.png ...]
```

### Examples

```bash
# Detect everything across the full screen (default)
dip vision:detect frame.png

# Restrict to guard-related templates only
dip vision:detect guard frame.png

# Check a specific single action
dip vision:detect guard_ready frame.png

# Batch — detect across multiple screenshots
dip vision:detect frame1.png frame2.png frame3.png

# Print the full candidate list from the detector pass
dip vision:detect --verbose frame.png
```

### Output

```
frame.png
  #1 guard_ready/03_left   action=guard_ready          mk3=(54,203)  conf=0.891
  #2 idle_fighting_stance/05_right  action=idle_fighting_stance  mk3=(179,248)  conf=0.856
  timer:     92
  detect_ms: 184
  P1: 166/166  x=54 y=203   action=guard_ready
  P2: 165/166  x=179 y=248  action=idle_fighting_stance
```

- `#N` — ranked detections sorted by x position (P1 left, P2 right)
- `mk3=(x,y)` — foot position scaled to the MK3 coordinate space (0–255)
- `conf` — template match confidence (0.0–1.0); templates matched at the `MIN_CONFIDENCE` threshold
- `detect_ms` — time spent on template matching (excludes image load and timer detection)
- `P1 / P2` — player health, scaled position, and detected action
- `--verbose` — also print every candidate template match returned by the detector, not just the final selected detections
- verbose candidates are sorted by confidence and colorized for faster inspection

### Action Modes

The optional first argument restricts which template groups are loaded. Using a specific mode is faster and useful when diagnosing a single pose.

| Mode | Templates searched |
|---|---|
| *(omitted)* / `all` | Every template group |
| `idle` | `idle_fighting_stance` |
| `walk` | `walking` |
| `run` | `running` |
| `crouch` | `crouching`, `crouch_guard`, `crouch_punch` |
| `guard` | `guard_ready`, `crouch_guard` |
| `punch` | `standing_punch_combo`, `straight_punch`, `crouch_punch` |
| `kick` | `front_kick`, `high_kick`, `low_kick_combo`, `roundhouse_kick`, `rising_kick`, `sweep_or_low_attack`, `jump_kick_or_aerial_attack` |
| `jump` | `jump_up_reaching`, `jump_kick_or_aerial_attack` |
| `hurt` | `hit_reaction`, `standing_hurt_or_dizzy`, `dizzy_or_recovering`, `fatality_dizzy_bent_over` |
| `knockdown` | `knocked_down_fall`, `airborne_fall_knockdown`, `lying_on_ground` |
| `projectile` | `ice_blast_casting` |
| `slide` | `slide_attack` |
| `roll` | `forward_roll_flip` |
| `special` | `ice_blast_casting`, `ice_clone_crouch`, `slide_attack` |
| `victory` | `victory_or_turnaround`, `victory_pose_raise_arms`, `victory_raise_arms` |
| `timer_only` | *(no character templates — timer only)* |
| Any single group name | That group only (e.g. `guard_ready`, `crouch_guard`, `hit_reaction`, …) |

### Environment Variables

All variables are optional. They override the defaults from `config/detection.yml` when set.

| Variable | Default | Description |
|---|---|---|
| `MIN_CONFIDENCE` | `0.82` | Minimum match confidence to count as a detection |
| `MAX_DETECTIONS` | `2` | Maximum number of detections returned per frame |
| `SEARCH_STRIDE` | `1` (all) / `4` (single mode) | Pixel stride for the sliding-window search; higher = faster but may miss sub-pixel alignments |
| `VISION_DEVICE` | auto | PyTorch device: `cuda`, `cpu`, or a specific index like `cuda:0` |
| `TEMPLATE_ROOT` | `data/vision/templates` | Root directory for character template folders |
| `TEMPLATE_NAME_PREFIXES` | *(from action mode)* | Comma-separated path prefixes to include (e.g. `guard_ready/,crouch_guard/`) |
| `TEMPLATE_NAME_EXCLUDE_SUBSTRINGS` | `reference` | Comma-separated substrings — templates whose name contains any of these are skipped |

```bash
# Example: lower threshold and force CPU
MIN_CONFIDENCE=0.75 VISION_DEVICE=cpu dip vision:detect frame.png

# Example: custom template subset
TEMPLATE_NAME_PREFIXES=guard_ready/,hit_reaction/ dip vision:detect frame.png
```
