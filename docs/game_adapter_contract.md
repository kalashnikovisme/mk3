# Game Adapter Contract

Every game adapter must inherit from `FightingAI::Game::Adapter` and implement the full match lifecycle contract.

## Required Methods

### State Extraction

```ruby
# Parse a raw frame snapshot Hash into a Core::GameState.
def extract_game_state(raw_snapshot, frame_observation: nil)

# Build a Core::Observation from a Core::GameState for the given player.
def build_observation(game_state, player_index:)
```

Adapters that support image recognition may consume `frame_observation` to derive
game-specific fields before constructing `Core::GameState`. Agents still never
receive `Observation::FrameObservation`; they receive only `Core::Observation`.

Optional vision hooks:

```ruby
def vision_enabled? # → true when frame capture should run
def configure_vision_characters(player1_character:, player2_character:)
```

### Action Translation

```ruby
# Translate a Core::Action into a Core::InputSequence.
def action_to_input_sequence(action, player_index:, game_state:)

# Translate an InputSequence into a logical button Hash for the emulator adapter.
# Returns { up: bool, down: bool, low_punch: bool, ... }
def input_sequence_to_buttons(input_sequence, player_index:, frame_offset: 0)
```

### Reward

```ruby
# Calculate a Core::Reward between two consecutive game states.
def calculate_reward(prev_game_state, next_game_state, player_index:)
```

#### MK3 reward components (`RewardFunction`)

| Component | Sign | Formula |
|-----------|------|---------|
| `damage_dealt` | + | `(opp_prev.health − opp_next.health) × DAMAGE_DEALT_WEIGHT` |
| `damage_taken` | − | `(me_prev.health − me_next.health) × DAMAGE_TAKEN_WEIGHT` |
| `distance` | ±  | `(closeness × 2 − 1) × DISTANCE_WEIGHT` where `closeness = 1 − dist / MAX_FIGHT_DISTANCE`; +weight at zero distance, −weight at maximum separation |
| `round_win` / `round_loss` / `round_draw` | ± | flat event bonuses |
| `stale` | − | flat penalty when the round stalls (HP unchanged) |

### Match Lifecycle

```ruby
def start_game
def open_player_vs_player_mode
def select_characters(player1_character:, player2_character:)
def wait_for_fight_start(timeout: 30)
def fight_active?(game_state)
def fight_finished?(game_state)
def collect_match_result(match)
def reset_for_next_match(strategy: :load_save_state)
```

### Character Registry

```ruby
# Returns a Hash of { character_name => { cursor_index:, display_name:, ... } }
def characters

# Optional: pools for random selection
def character_pools
```

## Convention

- Game ID constant: `GAME_ID = :your_game_id`
- Use a `MemoryMap` module for all memory addresses.
- Use an `InputMap` module for button translation. `to_logical(buttons_array)` returns `{ symbol => bool }`.
- Use an `ActionSpace` module for action → InputSequence mapping.
- Character-specific special moves live in `characters/<name>.rb` modules. Each module exposes `SPECIAL_MOVES` (action_name → InputSequence builder) and `DIRECTION_SENSITIVE_MOVES`. `ActionSpace::ACTIONS` and `ActionTranslator::ACTIONS`/`GAME_ACTION_MAP` merge them in via splat so specials appear in the flat RL action space alongside normal actions. The adapter's `DIRECTION_SENSITIVE_ACTIONS` constant lists all actions that need `flip_direction` applied when the player faces left.
- Use an `ObservationSpace` module for GameState → Observation normalization.
- If using vision, keep detector output game-specific and merge it in the adapter
  or state extractor before building `Core::Observation`.
- Use a `RewardFunction` class for configurable reward calculation.
- Use a `StateExtractor` module for raw snapshot → GameState parsing.
- Use a `MenuNavigator` class for autonomous menu driving.
