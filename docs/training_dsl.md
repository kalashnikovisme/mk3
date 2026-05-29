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

## Training Session Definition

```ruby
FightingAI.training :mk3_imitation do
  game :mortal_kombat_3
  mode :imitation_learning

  dataset do
    recordings_path "data/recordings/mk3"
  end

  reward do
    plus  :damage_dealt, weight: 1.0
    minus :damage_taken, weight: 1.0
    plus  :round_win,    weight: 10.0
    minus :round_loss,   weight: 10.0
  end
end
```

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

# Character pools
setup = FightingAI.match_setup do
  player1 FightingAI.sample_from_pool(:ninjas)
  player2 FightingAI.sample_from_pool(:all)
end
```

## Running a Human vs AI Match

```ruby
require "fighting_ai"

FightingAI.configure_game :mortal_kombat_3 do
  emulator :bizhawk
  # ... inputs and actions ...
end

emulator = FightingAI.build_bizhawk_adapter
emulator.connect

game = FightingAI.build_mk3_adapter(emulator_adapter: emulator)
agent = FightingAI::Agent::RuleBased.new(player_index: 2)

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
