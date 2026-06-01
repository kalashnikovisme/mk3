# Training DSL

## Game Definition

```ruby
FightingAI.configure_game :mortal_kombat_3 do
  emulator :bizhawk

  inputs do
    button :up
    button :down
    button :left
    button :right
    button :low_punch
    button :high_punch
    button :low_kick
    button :high_kick
    button :block
    button :run
  end

  actions do
    action :idle
    action :walk_forward
    action :walk_back
    action :low_punch
    action :high_punch
    action :low_kick
    action :high_kick
    action :block
  end
end
```

## PPO Self-Play Training

The active training mode is PPO self-play via `dip learn`. See `docs/ppo_training.md` for the full configuration reference including reward weights, hyperparameters, action space, and entropy collapse detection.

## Match Setup

```ruby
# Fixed characters
setup = FightingAI.match_setup do
  player1 :sub_zero
  player2 :scorpion
end

# Random selection
setup = FightingAI.match_setup do
  player1 FightingAI.random_character
  player2 FightingAI.random_character
end
```

## Running a Human vs AI Match

```ruby
require "fighting_ai"

emulator = FightingAI.build_retro_arch_adapter
game     = FightingAI.build_mk3_adapter(emulator_adapter: emulator)
agent    = FightingAI::Agent::RuleBased.new(player_index: 2)

recorder = FightingAI::Training::Recorder.new(path: "data/recordings/mk3/session.jsonl")

runtime = FightingAI::Runtime::HumanVsAI.new(
  emulator_adapter: emulator,
  game_adapter:     game,
  ai_agent:         agent,
  human_player:     1,
  recorder:         recorder
)

runtime.run(player1_character: :sub_zero, player2_character: :scorpion)
```

## Scenario DSL

Inside a scenario file the following top-level methods are available:

| Method | Description |
|--------|-------------|
| `speed(preset_or_multiplier)` | Set emulation speed (`:normal`, `:fast`, `:turbo`, `:slow`, `:slow_mo`, or a numeric multiplier) |
| `wait(frames)` | Pause all input for the given number of frames |
| `save_state(name = nil)` | Save the current RetroArch state to `/app/data/states/<name>.state`. If `name` is omitted, named by timestamp. |
| `save_memory(name = nil)` | Capture a raw binary WRAM dump (exactly 131072 bytes) and write it to `/app/data/memory/<name>.bin`. Subdirectories are created automatically — e.g. `"p1_x/idle"` → `/app/data/memory/p1_x/idle.bin`. The first call in each session also prints the memory source, SNES bus base address (`0x7E0000`), and size. If `name` is omitted, named by timestamp. |
| `reload_state` | Reload the initial match state that was installed at scenario start. Use between test sections to reset fighter positions, health, and timer. |

See `docs/scenario_dsl.md` for the full player-input API (`P1.right`, `P2.block`, etc.).

Example — WRAM snapshots for memory analysis:

```ruby
speed :normal

save_memory "idle"

P1.right 1
save_memory "p1_r_1"

wait 30

reload_state

P2.left 1
save_memory "p2_l_1"
```

After the scenario finishes, `dip scenario` prints a size-verification table confirming every `.bin` file is exactly 131072 bytes:

```
Memory dump size verification:
  idle.bin: 131072 bytes
  p1_r_1.bin: 131072 bytes
  p2_l_1.bin: 131072 bytes
✓ All 3 dumps: 131072 bytes (128 KB)
```

## Running AI vs AI

```ruby
agent1 = FightingAI::Agent::RuleBased.new(player_index: 1)
agent2 = FightingAI::Agent::RuleBased.new(player_index: 2)

runtime = FightingAI::Runtime::AIVsAI.new(
  emulator_adapter: emulator,
  game_adapter:     game,
  agent1:           agent1,
  agent2:           agent2,
  recorder:         recorder
)

matches = runtime.run_series(match_count: 10, player1_character: :random, player2_character: :random)
```

## Memory Address Discovery

The memory analysis framework in `lib/memory_analysis/` discovers WRAM addresses automatically from raw binary dumps. It has no knowledge of any specific game or emulator — the same tools work for any title.

### Workflow

```bash
dip memory:analyze    # Phase 1: run scenarios; Phase 2: rank candidates; writes data/candidates.json
dip memory:verify     # Phase 1: 120-frame motion sequences; Phase 2: confirm/reject candidates
dip memory:find-p2    # Full-WRAM scan for P2 coordinate, correlated against confirmed P1 series
```

### Step 1 — `dip memory:analyze`

Runs `scenarios/memory_analysis.rb`, which exercises each variable and saves raw 128 KB WRAM snapshots to categorised subdirectories under `/app/data/memory/`. Then `MemoryAnalysis::AddressFinder` loads the dumps and runs five algorithms:

| Algorithm | Categories | Primary width | What it finds |
|-----------|-----------|---------------|---------------|
| `Monotonic` | P1 X, P2 X | u16le | Addresses monotonically increasing or decreasing across 6 snapshots |
| `Bracketed` | Distance | u16le | Addresses where idle is between far and close |
| `BinaryTransition` | Facing | u8 | Addresses that toggle between a small value set |
| `Decreasing` | Health | u8 | Addresses that drop after taking damage |
| `Stepped` | Timer | u8 | Addresses that change by a constant step (±1) across 3 snapshots |

Output: top 20 candidates per category, ranked by algorithm score. Also writes `data/candidates.json` (top 5 per category) for use by `dip memory:verify`.

### Step 2 — `dip memory:verify`

Reads `data/candidates.json` and verifies each address using two 120-frame motion sequences:

| Sequence | Directory | What it exercises |
|----------|-----------|-------------------|
| `p1_right` | `p1_right/0..119.bin` | P1 walks right every frame |
| `p2_left`  | `p2_left/0..119.bin`  | P2 walks left every frame |

`MemoryAnalysis::CandidateVerifier` reads each candidate across all 120 frames and computes:

| Metric | Description |
|--------|-------------|
| `motion_rate` | % of frames where the value changed |
| `monotonicity` | % of consecutive pairs moving in the dominant direction |
| `avg_delta` | mean absolute frame-to-frame change |
| `delta_variance` | variance of absolute deltas (low = consistent step size) |
| `direction_changes` | sign flips among non-zero deltas (low = clean monotonic motion) |
| `correlation` | Pearson r of values against frame index (±1 = perfectly linear motion) |
| `min_value` / `max_value` | observed range across the 120 frames |

Width strategy per category:
- `p1_x`, `p2_x`, `distance` — u16le primary (MK3 stores coordinates as 16-bit values)
- `facing`, `health`, `timer` — u8 primary

**Explicit u16le verification:** `bin/memory_verify` also verifies a hardcoded list of candidate addresses unconditionally as u16le (the `EXPLICIT_U16LE` constant), regardless of what `data/candidates.json` contains. Each gets its own CSV and appears in an `EXPLICIT u16le VERIFICATION` section of the report.

**Confirmation thresholds:**

Position coordinates (u16le):
```
monotonicity    ≥ 75%
avg_delta       ≥ 0.5
direction_changes ≤ frame_count × 20%
```

Explicit u16le addresses (correlation-based):
```
|correlation|   ≥ 0.85
direction_changes ≤ frame_count × 20%
```

Discrete flags (facing):
```
motion_rate     > 0
unique_values   ≤ 4
direction_changes ≤ 3
```

**Mirror detection:** `CandidateVerifier#detect_mirrors` computes pairwise Pearson r across all active verifications. Addresses with r ≥ 0.98 are grouped as mirrors. The first entry in each group (highest `|correlation|` with frame index) is the likely canonical address.

Per-address CSV files land at `/app/data/memory/verification/<category>/0x<addr>_<sequence>_<width>.csv`:

```
frame,value
0,2836
1,2841
2,2846
...
```

Example summary output:

```
CONFIRMED P1 X POSITION:
  0x01A0A  (u16le, avg_delta=4.800, monotonicity=98.3%, correlation=+0.9987)

CONFIRMED FACING DIRECTION:
  0x0062C  (u8, avg_delta=0.008, monotonicity=0.8%, correlation=+0.8661)
```

### Step 3 — `dip memory:find-p2`

After confirming P1 X, this command discovers P2 X by:

1. Running `scenarios/p2_verification.rb` — 120 frames of P2 walking left, dumped to `p2_walk/`.
2. Loading the P1 X reference series from `p1_right/` (generated by `dip memory:verify`).
3. Scanning all ~65 000 u16le addresses in WRAM, computing Pearson r against the P1 reference series.
4. Excluding known P1 addresses and their mirror family.
5. Also probing struct-offset candidates at `P1_X_ADDR + {0x10, 0x20, 0x30, 0x40, 0x50, 0x60}` — MK3 appears to store fighter data in parallel blocks separated by a fixed stride.

Output: ranked table of top 30 correlated addresses with confirmation status, plus a detail section (first/last 20 samples, CSV paths) for the top confirmed candidates.

### Ruby API

```ruby
# Address discovery
finder = MemoryAnalysis::AddressFinder.new(dump_dir: "/app/data/memory")
report = finder.report
# { p1_x: [Candidate(address:, score:, values:, width:), ...], ... }
MemoryAnalysis::ReportPrinter.print(report)

# Candidate verification
verifier = MemoryAnalysis::CandidateVerifier.new(
  dump_dir:       "/app/data/memory",
  candidates:     { p1_x: [0x1A0A], facing: [0x0062C] },
  explicit_u16le: [0x1A0A, 0x1A0C, 0x1A0E, 0x0206, 0x040E]
)
results       = verifier.verify
mirror_groups = verifier.detect_mirrors(results)
MemoryAnalysis::VerificationPrinter.print(results, mirror_groups: mirror_groups)

# P2 coordinate scan
finder = MemoryAnalysis::P2Finder.new(
  dump_dir: "/app/data/memory",
  sequence: "p2_walk",
  exclude:  [0x1A0A, 0x1A0C, 0x1A0E]
)
scan_results   = finder.scan(reference_series: p1_values, anchor_address: 0x1A0A)
struct_results = finder.probe_struct_offsets(anchors: { p1_x: 0x1A0A })
MemoryAnalysis::P2ScanPrinter.print(scan_results, struct_results, reference_addr: 0x1A0A)
```
