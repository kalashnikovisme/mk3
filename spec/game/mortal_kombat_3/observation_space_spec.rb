require "spec_helper"

RSpec.describe FightingAI::Game::MortalKombat3::ObservationSpace do
  let(:fighter_attrs) do
    {
      max_health:      144,
      animation_state: FightingAI::Core::AnimationState.new(name: "idle", frame_index: 0, total_frames: 1),
      in_blockstun:    false,
      knocked_down:    false,
      airborne:        false
    }
  end

  let(:fighter1) do
    FightingAI::Core::FighterState.new(
      **fighter_attrs,
      player_index: 1,
      health:       100,
      x:            80,
      y:            40,
      facing:       FightingAI::Core::FacingDirection::RIGHT,
      in_hitstun:   false
    )
  end

  let(:fighter2) do
    FightingAI::Core::FighterState.new(
      **fighter_attrs,
      player_index: 2,
      health:       60,
      x:            200,
      y:            40,
      facing:       FightingAI::Core::FacingDirection::LEFT,
      in_hitstun:   true
    )
  end

  let(:game_state) do
    FightingAI::Core::GameState.new(
      frame_number:         100,
      fighter1:             fighter1,
      fighter2:             fighter2,
      round_number:         1,
      round_time_remaining: 90,
      fight_active:         true,
      round_over:           false,
      match_over:           false
    )
  end

  subject(:observation) { described_class.build(game_state, player_index: 1) }

  it "normalizes health percentages" do
    expect(observation.my_health_pct).to be_within(0.001).of(100.0 / 144)
    expect(observation.opponent_health_pct).to be_within(0.001).of(60.0 / 144)
  end

  it "normalizes positions" do
    expect(observation.my_x_normalized).to be_within(0.001).of(80.0 / 383)
    expect(observation.opponent_x_normalized).to be_within(0.001).of(200.0 / 383)
  end

  it "reports opponent hitstun correctly" do
    expect(observation.opponent_in_hitstun).to be true
  end

  it "returns a vector of floats" do
    vector = observation.to_vector
    expect(vector).to be_an(Array)
    expect(vector).to all(be_a(Float).or(be_a(Integer)))
  end

  it "swaps perspective for player 2" do
    obs2 = described_class.build(game_state, player_index: 2)
    expect(obs2.my_health_pct).to be_within(0.001).of(60.0 / 144)
    expect(obs2.opponent_health_pct).to be_within(0.001).of(100.0 / 144)
  end
end
