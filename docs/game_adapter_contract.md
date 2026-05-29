# Game Adapter Contract

Every game adapter must inherit from `FightingAI::Game::Adapter` and implement the full match lifecycle contract.

## Required Methods

### State Extraction

```ruby
# Parse a raw frame snapshot Hash into a Core::GameState.
def extract_game_state(raw_snapshot)

# Build a Core::Observation from a Core::GameState for the given player.
def build_observation(game_state, player_index:)
```

### Action Translation

```ruby
# Translate a Core::Action into a Core::InputSequence.
def action_to_input_sequence(action, player_index:, game_state:)

# Translate an InputSequence into a raw buttons Hash for the emulator adapter.
def input_sequence_to_buttons(input_sequence, player_index:, frame_offset: 0)
```

### Reward

```ruby
# Calculate a Core::Reward between two consecutive game states.
def calculate_reward(prev_game_state, next_game_state, player_index:)
```

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
- Use an `InputMap` module for button translation.
- Use an `ActionSpace` module for action → InputSequence mapping.
- Use an `ObservationSpace` module for GameState → Observation normalization.
- Use a `RewardFunction` class for configurable reward calculation.
- Use a `StateExtractor` module for raw snapshot → GameState parsing.
- Use a `MenuNavigator` class for autonomous menu driving.
