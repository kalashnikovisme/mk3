require "spec_helper"

RSpec.describe FightingAI::Game::MortalKombat3::InputMap do
  describe ".to_bizhawk" do
    it "maps logical buttons to BizHawk P1 names" do
      result = described_class.to_bizhawk([:left, :high_punch], player_index: 1)
      expect(result["P1 Left"]).to be true
      expect(result["P1 X"]).to be true
    end

    it "maps P2 buttons with the correct prefix" do
      result = described_class.to_bizhawk([:low_kick], player_index: 2)
      expect(result["P2 B"]).to be true
    end

    it "raises for unknown buttons" do
      expect { described_class.to_bizhawk([:teleport], player_index: 1) }
        .to raise_error(ArgumentError, /Unknown button/)
    end
  end

  describe ".all_released" do
    it "returns false for every button" do
      result = described_class.all_released(player_index: 1)
      expect(result.values).to all(be false)
      expect(result.keys).to all(start_with("P1 "))
    end
  end
end
