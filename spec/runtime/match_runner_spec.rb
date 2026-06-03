require "spec_helper"

RSpec.describe FightingAI::Runtime::MatchRunner do
  EXPECTED_WARNING_COUNT = 1
  SCREENSHOT_TIMEOUT_MESSAGE = "Screenshot timeout after #{FightingAI::Emulator::RetroArch::FrameGrabber::POLL_TIMEOUT}s"

  let(:timeout_error) do
    FightingAI::Emulator::RetroArch::FrameGrabber::TimeoutError.new(SCREENSHOT_TIMEOUT_MESSAGE)
  end
  let(:emulator) { instance_double(FightingAI::Emulator::Adapter) }
  let(:game) { double("GameAdapter", vision_enabled?: true) }
  let(:logger_messages) { [] }
  let(:runner) do
    described_class.new(
      emulator_adapter: emulator,
      game_adapter: game,
      agents: {},
      logger: ->(message) { logger_messages << message }
    )
  end

  describe "#capture_frame_observation" do
    it "falls back to WRAM positions when vision screenshot capture times out" do
      allow(emulator).to receive(:capture_frame).and_raise(timeout_error)

      expect(runner.send(:capture_frame_observation)).to be_nil
      expect(logger_messages.join).to include("falling back to WRAM positions")
    end

    it "logs the vision screenshot timeout warning only once" do
      allow(emulator).to receive(:capture_frame).and_raise(timeout_error)

      runner.send(:capture_frame_observation)
      runner.send(:capture_frame_observation)

      warning_count = logger_messages.count { |message| message.include?("falling back to WRAM positions") }
      expect(warning_count).to eq(EXPECTED_WARNING_COUNT)
    end
  end
end
