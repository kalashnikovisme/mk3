require "spec_helper"

RSpec.describe FightingAI::Core::Reward do
  describe ".compose" do
    it "sums components into the total value" do
      reward = described_class.compose(damage_dealt: 5.0, damage_taken: -2.0)
      expect(reward.value).to eq(3.0)
    end

    it "stores individual components" do
      reward = described_class.compose(damage_dealt: 5.0, round_win: 10.0)
      expect(reward.components[:damage_dealt]).to eq(5.0)
      expect(reward.components[:round_win]).to eq(10.0)
    end
  end

  describe "ZERO constant" do
    it "has zero value" do
      expect(described_class::ZERO.value).to eq(0.0)
    end
  end

  describe "#+" do
    it "merges two rewards" do
      a = described_class.compose(damage_dealt: 3.0)
      b = described_class.compose(damage_taken: -1.0)
      combined = a + b
      expect(combined.value).to eq(2.0)
      expect(combined.components[:damage_dealt]).to eq(3.0)
      expect(combined.components[:damage_taken]).to eq(-1.0)
    end
  end

  describe "predicates" do
    it "is positive? when value > 0" do
      expect(described_class.compose(x: 1.0).positive?).to be true
    end

    it "is negative? when value < 0" do
      expect(described_class.compose(x: -1.0).negative?).to be true
    end
  end
end
