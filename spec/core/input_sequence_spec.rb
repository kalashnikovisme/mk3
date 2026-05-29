require "spec_helper"

RSpec.describe FightingAI::Core::InputSequence do
  describe ".single" do
    it "creates a one-frame sequence" do
      seq = described_class.single(:low_punch)
      expect(seq.total_frames).to eq(1)
      expect(seq.to_button_frames.first).to include(:low_punch)
    end
  end

  describe ".empty" do
    it "has no frames" do
      expect(described_class.empty.total_frames).to eq(0)
    end
  end

  describe "#press" do
    it "accumulates entries" do
      seq = described_class.new.press([:down], hold_frames: 2).press([:low_kick])
      expect(seq.total_frames).to eq(3)
    end

    it "returns self for chaining" do
      seq = described_class.new
      expect(seq.press(:up)).to be(seq)
    end
  end

  describe "#to_button_frames" do
    it "expands hold_frames correctly" do
      seq = described_class.new.press([:block], hold_frames: 3)
      frames = seq.to_button_frames
      expect(frames.length).to eq(3)
      frames.each { |f| expect(f).to include(:block) }
    end
  end
end
