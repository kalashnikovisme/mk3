# Adding a New Fighting Game

Supporting a new fighting game requires only implementing game-specific adapters. Core, Emulator Adapters, the Input layer, and the Training Runtime require no modifications.

## Steps

### 1. Create the directory structure

```
lib/fighting_ai/game/street_fighter_2/
├── adapter.rb
├── memory_map.rb
├── input_map.rb
├── action_space.rb
├── observation_space.rb
├── reward_function.rb
├── state_extractor.rb
├── menu_navigator.rb
└── characters.rb
```

### 2. Define the memory map

Create a `MemoryMap` module with the WRAM addresses for your game. Find them with a memory editor (e.g., Cheat Engine attached to RetroArch, or the RetroArch RAM search tool).

```ruby
module FightingAI
  module Game
    module StreetFighter2
      module MemoryMap
        GAME_STATE_ADDR = 0x0200
        P1_HEALTH_ADDR  = 0x0210
        # ...
      end
    end
  end
end
```

### 3. Define the input map

Map logical button names to their SNES equivalents. The `to_logical` method converts button arrays to the `{ symbol => bool }` hash that the emulator adapter expects.

```ruby
module InputMap
  BUTTON_MAP = {
    punch_lp: "Y",
    punch_mp: "X",
    # ...
  }.freeze

  def self.to_logical(buttons_array, player_index: nil) = ...
  def self.all_released = ...
end
```

### 4. Define the action space

```ruby
module ActionSpace
  ACTIONS = {
    idle:         ->(_pi) { Core::InputSequence.empty },
    walk_forward: ->(_pi) { Core::InputSequence.single(:right) },
    hadouken:     ->(_pi) {
      Core::InputSequence.new
        .press([:down], hold_frames: 2)
        .press([:down, :right], hold_frames: 1)
        .press([:right, :punch_lp])
    },
    # ...
  }.freeze
end
```

### 5. Implement the state extractor

Parse raw WRAM snapshot hashes into `Core::GameState` and `Core::FighterState`. The snapshot format is the same dict that `RetroArch::Adapter#next_frame_snapshot` produces.

### 6. Implement the observation space

Normalize `GameState` to `Core::Observation` with values in `[0, 1]`.

### 7. Implement the reward function

Subclass or compose a reward function using `Core::Reward.compose`.

### 8. Implement the menu navigator

Drive the game's menus autonomously using timed button press sequences. Receive an emulator adapter and call `send_input(player_index, logical_hash)` and `send_noop`.

### 9. Implement the adapter

Inherit from `FightingAI::Game::Adapter` and implement all lifecycle methods.

```ruby
module FightingAI
  module Game
    module StreetFighter2
      class Adapter < FightingAI::Game::Adapter
        GAME_ID = :street_fighter_2

        def extract_game_state(raw_snapshot) = StateExtractor.extract(raw_snapshot)
        def build_observation(game_state, player_index:) = ObservationSpace.build(game_state, player_index: player_index)
        def action_to_input_sequence(action, player_index:, game_state:) = ActionSpace.to_input_sequence(action.name, player_index: player_index)
        def input_sequence_to_buttons(seq, player_index:, frame_offset: 0) = InputMap.to_logical(seq.to_button_frames[frame_offset] || [], player_index: player_index)
        def calculate_reward(prev, next_s, player_index:) = @reward_function.call(prev, next_s, player_index: player_index)
        def start_game = @navigator.wait(60)
        def open_player_vs_player_mode = @navigator.navigate_to_versus_mode
        def select_characters(player1_character:, player2_character:) = ...
        def wait_for_fight_start(timeout: 600) = ...
        def fight_active?(gs) = gs.fight_active?
        def fight_finished?(gs) = gs.match_over?
        def collect_match_result(match) = ...
        def reset_for_next_match(strategy: :load_save_state) = ...
        def characters = Characters.all
      end
    end
  end
end
```

### 10. Configure the RetroArch adapter for the new game's WRAM

The RetroArch adapter currently hard-codes the MK3 WRAM scanner in `WramReader#mk3_wram?`. For a new game, subclass or extend `WramReader` with a game-specific signature scanner, and update `RetroArch::Adapter#read_[game]_snapshot` to read your game's addresses.

### 11. Update the keyboard bindings (if needed)

If the new game uses different buttons, update `Input::KeyboardInput::PLAYER_KEYS` or configure your game's key layout in `RetroArch::ConfigBuilder`.

### 12. Register in the DSL

```ruby
FightingAI.configure_game :street_fighter_2 do
  emulator :retro_arch
  inputs do
    button :up; button :down; button :left; button :right
    button :punch_lp; button :punch_mp; button :punch_hp
    button :kick_lk;  button :kick_mk;  button :kick_hk
  end
  actions do
    action :idle; action :walk_forward; action :hadouken
    # ...
  end
end
```

### 13. Write specs

Mirror the `spec/game/mortal_kombat_3/` structure with game-specific test data.
