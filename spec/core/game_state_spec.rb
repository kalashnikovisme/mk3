require "spec_helper"

RSpec.describe FightingAI::Core::GameState do
  let(:fighter_attrs) do
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

  let(:fighter1) do
    FightingAI::Core::FighterState.new(
      **fighter_attrs.merge(player_index: 1, health: 100, x: 80, y: 40)
    )
  end

  let(:fighter2) do
    FightingAI::Core::FighterState.new(
      **fighter_attrs.merge(player_index: 2, health: 60, x: 200, y: 40)
    )
  end

  subject(:state) do
    described_class.new(
      frame_number:         500,
      fighter1:             fighter1,
      fighter2:             fighter2,
      round_number:         1,
      round_time_remaining: 80,
      fight_active:         true,
      round_over:           false,
      match_over:           false
    )
  end

  describe "#distance" do
    it "returns the x distance between fighters" do
      expect(state.distance).to eq(120)
    end
  end

  describe "#fighter_for" do
    it "returns fighter1 for player 1" do
      expect(state.fighter_for(1)).to eq(fighter1)
    end

    it "returns fighter2 for player 2" do
      expect(state.fighter_for(2)).to eq(fighter2)
    end

    it "raises for invalid player index" do
      expect { state.fighter_for(3) }.to raise_error(ArgumentError)
    end
  end

  describe "#opponent_of" do
    it "returns fighter2 as the opponent of player 1" do
      expect(state.opponent_of(1)).to eq(fighter2)
    end
  end

  describe "fight status predicates" do
    it "is fight_active? when fighting" do
      expect(state.fight_active?).to be true
    end

    it "is not round_over?" do
      expect(state.round_over?).to be false
    end
  end
end
