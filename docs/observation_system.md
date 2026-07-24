# Observation System

## Overview

The Observation layer wraps raw emulator output into typed objects. It sits between the Emulator Adapter and the Game Adapter — emulator adapters produce observation objects, game adapters may consume them for vision-based features.

Observation types live in `FightingAI::Observation`, not in `FightingAI::Core`. Core's `Core::Observation` is the normalized agent-facing vector; `Observation::FrameObservation` is raw emulator output.

## Classes

### `Observation::Provider` (abstract)

```ruby
capture  # → an Observation object
```

### `Observation::FrameObservation`

Wraps a path to a PNG screenshot captured by `RetroArch::FrameGrabber`.
`FrameGrabber` captures the isolated X display with `xwd`, crops the top-left
`297x216` pixels, converts the crop to PNG with ImageMagick, and returns the
observation. The PNG encoder is pinned to 8-bit truecolor (PNG color type 2),
which is the pixel layout consumed by `FrameObservation`; this prevents
ImageMagick from opportunistically emitting indexed-palette frames.

```ruby
frame = Observation::FrameObservation.new("/tmp/fighting_ai/screenshots/frame_001.png")

frame.path           # → String, absolute PNG path
frame.width          # → Integer (lazy, parsed from PNG IHDR on first access)
frame.height         # → Integer (lazy, parsed from PNG IHDR on first access)
frame.pixel_rgb(x,y) # → [r, g, b] Integer triple read directly from binary scanline
frame.to_tensor      # → flat Float Array, values in [0.0, 1.0], row-major, channels last
```

PNG decoding is pure Ruby using `Zlib::Inflate` on the PNG IDAT chunks — no image library required. The decompressed scanlines are stored as binary `String` objects; `pixel_rgb(x, y)` reads them with `String#getbyte` without allocating intermediate objects, making per-pixel health-bar scanning fast.

All image data is loaded and decompressed once on the first method call that needs it.

### Capture Throughput Diagnostic

`dip learn_empty [match-name]` starts the requested save state and captures a
PNG every frame interval without constructing a game adapter or invoking health,
timer, character-position, or PPO processing. Each line in
`data/fight_logs/episode_%05d.log` contains the capture frame number and PNG size,
for example `f: 1; size: 35416`. Frames are written to
`/tmp/fighting_ai/screenshots` inside the command container.

Pass detector names before the optional match name. `health` enables only the
pure-Ruby health-bar scan and appends `h1` and `h2` to each line:

```bash
dip learn_empty health
dip learn_empty health sub-zero-vs-sub-zero
```

Health-mode lines have the form
`f: 1; size: 35416; h1: 166; h2: 166`. Position and timer detection remain off.

`time` enables only timer-template detection and appends `t`. Detector arguments
are composable and may appear in either order:

```bash
dip learn_empty time
dip learn_empty health time
dip learn_empty time health sub-zero-vs-sub-zero
```

Combined lines have the form
`f: 1; size: 35416; h1: 166; h2: 166; t: 87`. Timer-only mode does not load or
match fighter templates.

`positions` enables character-template matching and appends scaled `x1`, `y1`,
`x2`, and `y2` coordinates. It composes with the other detectors:

```bash
dip learn_empty health time positions
dip learn_empty positions sub-zero-vs-sub-zero
```

When `time` and `positions` are both requested, one persistent Python scan
produces both results. With `positions` alone, timer matching is disabled.
Missing character detections are logged as empty coordinate values. The command
uses the GPU-enabled Dip service so position template matching does not fall back
to the much slower CPU path. Default player ROIs retain at most one
highest-confidence candidate each, preventing two P1-region matches from being
misreported as P1 and P2.

Timer templates are matched across a small horizontal search window because
captured timer digits can shift by one pixel relative to their prepared
templates. This prevents a visible `99` from being classified as `89` based on
better-aligned background pixels.

The persistent timer process is warmed before the match state is loaded. The
load-state and pause commands are then sent in order through one UDP socket so
the loaded state cannot advance before capture. Each logging iteration sends one
RetroArch `FRAMEADVANCE` command before capture. Screenshot encoding and enabled
detector work therefore cannot consume additional emulated frames.

The first stale display frame after a save-state load is advanced without being
logged. Frame 1 is captured from the rendered match state.

Without vision scanning there is no gameplay-derived match-end signal. Empty-mode
episodes therefore last 5,940 capture intervals (99 timer seconds at 60 FPS),
then reload the selected match state. Set `LEARN_EMPTY_EPISODE_FRAMES` to a
positive frame count to shorten or extend diagnostic episodes.

### `Observation::MemoryObservation`

Stub for a future structured observation built directly from WRAM values rather than pixel data. Wraps a raw snapshot hash from `WramReader`.

```ruby
obs = Observation::MemoryObservation.new(snapshot_hash)
obs.snapshot  # → Hash
```

## Relationship to `Core::Observation`

`Core::Observation` is the normalized float vector that agents receive. It is produced by `Game::Adapter#build_observation` from a `Core::GameState`. `FrameObservation` is a separate concept — raw pixels for potential future vision-based agents — and is never passed to agents directly in the current architecture.

## Vision Template Assets

Sprite templates for image-based character position detection are prepared outside the
agent boundary. Source sprites should be placed under
`data/vision/source/<character>/` and converted with:

```bash
dip provision
dip vision:prepare-sprites data/vision/source/sub_zero -- --binary
```

The converter writes templates to `data/vision/templates/sub_zero/` by default:

- `*_gray.png` — grayscale template with transparent source pixels painted black.
- `*_mask.png` — black/white alpha mask for masked template matching.
- `*_binary.png` — optional black/white thresholded template when `--binary` is used.

Mirrored templates are generated by default so one facing direction is enough.
Use `--no-mirror` only when you intentionally want source-orientation templates.

The default workflow uses grayscale templates plus masks. Pure black/white templates
are available for experiments, but grayscale keeps sprite shading and usually gives
more stable matches against varied MK3 backgrounds.

## Runtime Vision Flow

MK3 game state is extracted entirely from vision — no WRAM reads are made for observable fields. WRAM is only used to read the frame counter.

The three observable quantities and their sources:

| Observable | Source |
|------------|--------|
| Health (P1 & P2) | Blue-pixel scan of health bar region in the PNG frame (`Vision::HealthBarDetector`) |
| Fighter x/y position | Template matching via persistent Python CUDA detector (`bin/vision_detect.py --server`) |
| Round timer | Digit templates compared at a fixed crop position; `nil` when no template passes threshold |

Round over is detected when either fighter's health reaches zero or when the timer reaches zero. WRAM screen/round/animation state is not used.

When enabled, `Runtime::MatchRunner` captures a `FrameObservation` and passes it to `Game::MortalKombat3::Adapter#extract_game_state`. The adapter runs `Vision::CharacterPositionDetector`, which keeps a persistent `python3 bin/vision_detect.py --server` process alive. Runtime vision therefore uses the same Python CUDA detector, action modes, ROI defaults, and early-stop rules as `dip vision:detect`.

The adapter also records `latest_vision_actions` for fight logs. Those action labels are now derived from the same player-to-detection assignment used for positions, so the logged action for each fighter stays aligned with the fighter that produced the detection instead of being inferred from raw detection order alone.

When a new match starts, the adapter clears cached vision positions, timer, areas, and per-frame action labels before the first scan. Missing detections now log as absent instead of carrying labels forward from a previous frame.

If X display capture fails, runtime training treats that frame as a vision miss instead of aborting the episode. `MatchRunner` logs one warning; health defaults to `MAX_HEALTH` and positions to 0 for that frame.

Runtime vision is enabled by default for `dip learn`, `dip learn_from_ppo`,
`dip fight`, and `dip fight_watch`. Use `VISION=0` to force WRAM-only training
or evaluation. Action and area settings are controlled by environment variables:

```bash
dip learn sub-zero-vs-sub-zero
VISION_ACTION=front_kick VISION_AREAS="36,96,96,120;164,96,96,120" dip learn sub-zero-vs-sub-zero
VISION_ACTION=idle dip learn sub-zero-vs-sub-zero
VISION=0 dip learn sub-zero-vs-sub-zero
VISION=0 dip fight data/matches/sub-zero-vs-sub-zero.state models/ppo_10 models/ppo_5
```

If `VISION_ACTION` is omitted, runtime vision uses `all`, so learning scans every
non-reference action template inside the active ROIs. Use `VISION_ACTION=idle`
for the faster startup-stance-only workflow. If `VISION_AREAS` is omitted, the
runtime detector uses the same two default initial stance ROIs as before.

The per-frame fight log records `fighter1_area` and `fighter2_area` so you can
see the search regions the detector used on that frame. When the detector scans
full-screen, the log writes `full-screen` for both fields.
When fight screenshot saving is enabled, each episode directory under
`data/fight_screenshots` contains three subdirectories:

| Directory | Contents |
|-----------|----------|
| `screen/` | Whole captured frame PPMs named `frame_%05d.ppm` |
| `fighter1/` | PPM crops for the first detector ROI, using the same frame filename |
| `fighter2/` | PPM crops for the second detector ROI, using the same frame filename |

## Character Tracking (`Vision::CharacterTracker`)

`Vision::CharacterTracker` wraps `CharacterPositionDetector` with the same `detect(frame_observation)` interface and adds an optimization layer that avoids scanning the full screen on every frame.

### Tracking lifecycle

| State | Trigger | Action |
|-------|---------|--------|
| No tracks (startup or all tracks lost) | — | Full-screen scan, `areas: []` |
| Tracks active | frame % `full_screen_interval` == 0 | Periodic full-screen recovery scan |
| Tracks active | all other frames | Regional scan: one padded area per active track |

### Track initialization and update algorithm

1. **Full-screen frame** — `reinitialize_tracks`: replace all tracks with one `Track` per detection. Each `Track` stores the detection bounding box and `frames_lost: 0`.
2. **Regional frame** — `update_existing_tracks`: for each active track compute its `padded_region`, find any detection whose center falls inside that region, update the track's bounding box and reset `frames_lost`, or increment `frames_lost`. Tracks with `frames_lost >= max_lost_frames` are discarded.
3. **All tracks lost** — fall back to full-screen on the next frame.

### Padded region

```
x      = max(bbox.x - pad, 0)
y      = max(bbox.y - pad, 0)
right  = min(bbox.x + bbox.width + pad, image_width)
bottom = min(bbox.y + bbox.height + pad, image_height)
```

where `pad = max_movement_per_frame`. The clamping prevents search areas from extending outside the captured frame.
After padding, regional search areas are expanded around the tracked box center
to at least `96x120` pixels when the frame bounds allow it. This keeps the next
scan covering a full standing/crouching fighter even if the previous selected
template was a small partial match.

### Configuration

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `max_movement_per_frame` | 15 px | Padding added to each side of a track bounding box to form the search area |
| `max_lost_frames` | 5 | Frames without a match before a track is discarded |
| `full_screen_interval` | 60 | Frames between forced full-screen recovery scans (0 disables) |
| `min_search_region_width` | 96 px | Minimum regional ROI width after padding |
| `min_search_region_height` | 120 px | Minimum regional ROI height after padding |

### Usage

`FightingAI.build_mk3_adapter` wraps `CharacterPositionDetector` in `CharacterTracker` automatically when vision is enabled:

```ruby
inner = Vision::CharacterPositionDetector.new(
  search_stride: Vision::CharacterPositionDetector::POSITION_SEARCH_STRIDE
)
tracker = Vision::CharacterTracker.new(detector: inner)
```

`POSITION_SEARCH_STRIDE = 4` makes full-screen scans ~16× faster (every 4th pixel checked vs every pixel). The tracker further reduces per-frame scan area to small padded regions once characters are located, giving an additional 4–8× speedup.

### Per-request ROI protocol

The tracker passes per-frame `areas:` to `CharacterPositionDetector#detect`. The detector serializes them as a JSON `rois` array in the stdin request to `bin/vision_detect.py`:

```json
{"path": "/tmp/.../frame.png", "detect_timer": true, "rois": [{"x": 30, "y": 90, "width": 70, "height": 100}]}
```

If `rois` is absent the Python server uses its startup ROIs (or full-screen when none were given). The `rois` key overrides startup ROIs for that single request only.

## Detection Debugging

Prepared templates can be tested against screenshot PNGs without starting
training. The command uses a Torch backend and runs on CUDA when the dip
container has GPU access:

```bash
dip vision:detect data/screenshots/example.png
dip vision:detect idle data/screenshots/example.png
dip vision:detect idle --area 36,96,96,120 --area 164,96,96,120 data/screenshots/example.png
```

`dip vision:detect` runs through the `app_gpu` Compose service, which requests
`gpus: all`. If Docker is not configured for NVIDIA GPU containers, the command
fails before detection starts with an error such as:

```text
failed to discover GPU vendor from CDI: no known GPU vendor found
```

In that case, verify the host Docker GPU runtime first:

```bash
nvidia-smi
docker run --rm --gpus all ubuntu:24.04 nvidia-smi
```

The first command confirms the host driver. The second command must work before
`dip vision:detect` can use CUDA. Use `dip vision:detect-cpu ...` as a fallback
while Docker GPU support is being configured.

`requirements.txt` pins PyTorch to the CUDA 12.1 wheel (`torch==2.5.1+cu121`)
from the official PyTorch wheel index. Keep this pin unless the host NVIDIA
driver is also upgraded for newer CUDA runtimes; otherwise `dip provision` can
install a newer Torch wheel whose compiled CUDA runtime is newer than the host
driver, causing `dip vision:detect` to fall back to CPU. The provision command
force-reinstalls Python packages so an existing `pip` volume is corrected when
the pinned Torch wheel changes.

For each screenshot, the command prints the matched template name, screen-space
foot position, scaled MK3 `x/y` position, confidence, image dimensions, template
count, candidate count, timing, and selected device. The default minimum
confidence is `0.82`; override it for tuning:

```bash
MIN_CONFIDENCE=0.75 dip vision:detect data/screenshots/example.png
```

Add `--verbose` when you need the full candidate list from the detector pass,
including rejected template matches that did not survive non-overlap selection:
verbose output sorts candidates by descending confidence and highlights the
ranked confidence values for quick scanning.

Selected character detections are ranked by confidence plus a small template
coverage bias for bounding-box area and height. Short bounding boxes below the
full-body minimum also receive a score penalty. This keeps small partial
matches, such as a low knockdown fragment that resembles a standing fighter's
legs, from displacing a slightly lower-confidence full-body match in the active
ROI. The raw `top_candidates` debug list remains sorted by confidence so false
positives are still visible during tuning.

```bash
dip vision:detect --verbose data/screenshots/example.png
dip vision:detect idle --verbose data/screenshots/example.png
```

Without an action argument, `dip vision:detect` scans every non-reference
template across the full screenshot. Use `all --full-screen` only when you want
the full-screen behavior explicit. For targeted checks, pass an action mode as
the first argument:

```bash
dip vision:detect idle data/screenshots/example.png
dip vision:detect walk data/screenshots/example.png
dip vision:detect kick data/screenshots/example.png
dip vision:detect all --full-screen data/screenshots/example.png
```

Action modes scan only templates for that action and use the action-mode stride
defined in `bin/vision_detect.py`. Broad aliases include `all`, `idle`, `walk`,
`run`, `crouch`, `guard`, `punch`, `kick`, `jump`, `hurt`, `knockdown`,
`projectile`, `slide`, `roll`, `victory`, and `special`. Exact sprite-group
modes are also supported from `data/vision/sprites/subzero`, including
`idle_fighting_stance`, `walking`, `running`, `crouch_guard`, `front_kick`,
`high_kick`, `standing_punch_combo`, `jump_up_reaching`,
`jump_kick_or_aerial_attack`, `knocked_down_fall`, `airborne_fall_knockdown`,
and `ice_blast_casting`. Prefer exact sprite-group modes when you need the
fastest targeted check; broad modes scan more templates. The detector warms up
CUDA after loading templates so reported per-frame matching time does not
include the first CUDA kernel initialization cost.

Detection uses the full screenshot by default. Pass one or more `--area`/`--roi`
arguments to narrow the search to regions of interest. Each area is treated as
one character slot: once an area produces a detection above `MIN_CONFIDENCE`,
that area is skipped for the remaining templates. Use `--full-screen` to make
the default explicit:

```bash
dip vision:detect idle --area 36,96,96,120 --area 164,96,96,120 data/screenshots/example.png
dip vision:detect idle --roi 32,96,88,128 --roi 144,96,88,128 data/screenshots/example.png
dip vision:detect idle --full-screen data/screenshots/example.png
```

Other useful debug knobs:

```bash
MAX_DETECTIONS=4 dip vision:detect data/screenshots/example.png
SEARCH_STRIDE=2 dip vision:detect data/screenshots/example.png
TEMPLATE_ROOT=data/vision/templates dip vision:detect data/screenshots/example.png
VISION_DEVICE=cpu dip vision:detect data/screenshots/example.png
TEMPLATE_NAME_PREFIXES=idle_fighting_stance_ dip vision:detect data/screenshots/example.png
TEMPLATE_NAME_EXCLUDE_SUBSTRINGS=reference dip vision:detect data/screenshots/example.png
```

If detection appears stuck, it is usually scanning many large templates across a
full screenshot. The command prints progress at least once per second. Increase
`SEARCH_STRIDE` to trade precision for speed while debugging.
