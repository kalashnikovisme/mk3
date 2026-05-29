require "spec_helper"

RSpec.describe FightingAI::Core::FighterState do
  let(:base_attrs) do
    {
      player_index:    1,
      health:          100,
      max_health:      144,
      x:               100,
      y:               40,
      facing:          FightingAI::Core::FacingDirection::RIGHT,
      animation_state: FightingAI::Core::AnimationState.new(name: "idle", frame_index: 0, total_frames: 8),
      in_hitstun:      false,
      in_blockstun:    false,
      knocked_down:    false,
      airborne:        false
    }
  end

  subject(:fighter) { described_class.new(**base_attrs) }

  describe "#health_pct" do
    it "returns the correct percentage" do
      expect(fighter.health_pct).to be_within(0.001).of(100.0 / 144)
    end

    it "returns 0.0 when health is 0" do
      dead = described_class.new(**base_attrs.merge(health: 0))
      expect(dead.health_pct).to eq(0.0)
    end
  end

  describe "#alive?" do
    it "is true when health > 0" do
      expect(fighter.alive?).to be true
    end

    it "is false when health is 0" do
      dead = described_class.new(**base_attrs.merge(health: 0))
      expect(dead.alive?).to be false
    end
  end

  describe "#distance_to" do
    let(:other) { described_class.new(**base_attrs.merge(player_index: 2, x: 200)) }

    it "returns the absolute x-axis distance" do
      expect(fighter.distance_to(other)).to eq(100)
    end

    it "is symmetric" do
      expect(other.distance_to(fighter)).to eq(fighter.distance_to(other))
    end
  end

  describe "FacingDirection" do
    it "knows left from right" do
      expect(FightingAI::Core::FacingDirection::LEFT.left?).to be true
      expect(FightingAI::Core::FacingDirection::RIGHT.right?).to be true
    end

    it "returns the opposite direction" do
      expect(FightingAI::Core::FacingDirection::LEFT.opposite).to eq(FightingAI::Core::FacingDirection::RIGHT)
    end
  end
end
