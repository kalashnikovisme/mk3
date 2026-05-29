require "spec_helper"

RSpec.describe FightingAI::Core::Action do
  describe ".named" do
    it "creates an action with a symbolic name" do
      action = described_class.named(:low_punch)
      expect(action.name).to eq(:low_punch)
    end

    it "coerces string names to symbols" do
      action = described_class.named("high_kick")
      expect(action.name).to eq(:high_kick)
    end

    it "stores optional metadata" do
      action = described_class.named(:walk_forward, speed: 2)
      expect(action.metadata[:speed]).to eq(2)
    end
  end

  describe "IDLE constant" do
    it "is an idle action" do
      expect(described_class::IDLE.idle?).to be true
    end
  end
end
