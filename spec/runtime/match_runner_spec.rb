require "spec_helper"

RSpec.describe FightingAI::Runtime::MatchRunner do
  EXPECTED_WARNING_COUNT = 1
  CAPTURE_ERROR_MESSAGE = "X server screenshot capture failed"
  STALL_DISTANCE = 100.0
  MOVED_DISTANCE = STALL_DISTANCE - FightingAI.config.stale_distance_reset_threshold
  MINOR_MOVED_DISTANCE = STALL_DISTANCE - (FightingAI.config.stale_distance_reset_threshold / 2.0)

  let(:capture_error) do
    FightingAI::Emulator::RetroArch::StreamingFrameGrabber::CaptureError.new(CAPTURE_ERROR_MESSAGE)
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
    it "returns nil when vision screenshot capture fails" do
      allow(emulator).to receive(:capture_frame).and_raise(capture_error)

      expect(runner.send(:capture_frame_observation)).to be_nil
      expect(logger_messages.join).to include("positions will use last known values")
    end

    it "logs the vision screenshot capture warning only once" do
      allow(emulator).to receive(:capture_frame).and_raise(capture_error)

      runner.send(:capture_frame_observation)
      runner.send(:capture_frame_observation)

      warning_count = logger_messages.count { |message| message.include?("positions will use last known values") }
      expect(warning_count).to eq(EXPECTED_WARNING_COUNT)
    end
  end

  describe "#meaningful_movement_since_stall?" do
    it "returns true when there is no stall baseline yet" do
      expect(runner.send(:meaningful_movement_since_stall?, nil, STALL_DISTANCE)).to be true
    end

    it "returns true when spacing changes by at least the reset threshold" do
      expect(runner.send(:meaningful_movement_since_stall?, STALL_DISTANCE, MOVED_DISTANCE)).to be true
    end

    it "returns false when spacing changes by less than the reset threshold" do
      expect(runner.send(:meaningful_movement_since_stall?, STALL_DISTANCE, MINOR_MOVED_DISTANCE)).to be false
    end
  end
end
