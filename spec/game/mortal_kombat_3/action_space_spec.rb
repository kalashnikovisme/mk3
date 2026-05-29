require "spec_helper"

RSpec.describe FightingAI::Game::MortalKombat3::ActionSpace do
  describe ".to_input_sequence" do
    it "returns an empty sequence for :idle" do
      seq = described_class.to_input_sequence(:idle, player_index: 1)
      expect(seq.total_frames).to eq(0)
    end

    it "returns a sequence with frames for :walk_forward" do
      seq = described_class.to_input_sequence(:walk_forward, player_index: 1)
      expect(seq.total_frames).to be >= 1
    end

    it "returns a multi-frame sequence for :block" do
      seq = described_class.to_input_sequence(:block, player_index: 1)
      expect(seq.total_frames).to be >= 2
    end

    it "raises for unknown actions" do
      expect { described_class.to_input_sequence(:hadouken, player_index: 1) }
        .to raise_error(ArgumentError, /Unknown action/)
    end
  end

  describe ".all_action_names" do
    it "includes the basic attack actions" do
      expect(described_class.all_action_names).to include(:low_punch, :high_punch, :low_kick, :high_kick)
    end

    it "includes idle" do
      expect(described_class.all_action_names).to include(:idle)
    end
  end

  describe ".valid?" do
    it "returns true for known actions" do
      expect(described_class.valid?(:walk_back)).to be true
    end

    it "returns false for unknown actions" do
      expect(described_class.valid?(:super_move)).to be false
    end
  end
end
