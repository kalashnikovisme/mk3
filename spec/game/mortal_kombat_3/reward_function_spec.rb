require "spec_helper"

RSpec.describe FightingAI::Game::MortalKombat3::RewardFunction do
  let(:attrs) do
    {
      max_health:      144,
      facing:          FightingAI::Core::FacingDirection::RIGHT,
      animation_state: FightingAI::Core::AnimationState.new(name: "idle", frame_index: 0, total_frames: 1),
      in_hitstun:      false,
      in_blockstun:    false,
      knocked_down:    false,
      airborne:        false
    }
  end

  def make_state(h1:, h2:, round_over: false, match_over: false)
    FightingAI::Core::GameState.new(
      frame_number:         1,
      fighter1:             FightingAI::Core::FighterState.new(**attrs, player_index: 1, health: h1, x: 100, y: 40),
      fighter2:             FightingAI::Core::FighterState.new(**attrs, player_index: 2, health: h2, x: 200, y: 40),
      round_number:         1,
      round_time_remaining: 90,
      fight_active:         !round_over,
      round_over:           round_over,
      match_over:           match_over
    )
  end

  subject(:reward_fn) { described_class.new }

  describe "damage dealt" do
    it "gives positive reward when player deals damage" do
      prev  = make_state(h1: 100, h2: 100)
      after = make_state(h1: 100, h2: 80)
      reward = reward_fn.call(prev, after, player_index: 1)
      expect(reward.value).to be > 0
      expect(reward.components[:damage_dealt]).to eq(20.0)
    end
  end

  describe "damage taken" do
    it "gives negative reward when player takes damage" do
      prev  = make_state(h1: 100, h2: 100)
      after = make_state(h1: 70,  h2: 100)
      reward = reward_fn.call(prev, after, player_index: 1)
      expect(reward.value).to be < 0
    end
  end

  describe "round win" do
    it "gives large positive reward for winning the round" do
      prev  = make_state(h1: 50, h2: 10)
      after = make_state(h1: 50, h2: 0, round_over: true)
      reward = reward_fn.call(prev, after, player_index: 1)
      expect(reward.components[:round_win]).to eq(10.0)
    end
  end

  describe "round loss" do
    it "gives large negative reward for losing the round" do
      prev  = make_state(h1: 10, h2: 50)
      after = make_state(h1: 0,  h2: 50, round_over: true)
      reward = reward_fn.call(prev, after, player_index: 1)
      expect(reward.components[:round_loss]).to eq(-10.0)
    end
  end
end
