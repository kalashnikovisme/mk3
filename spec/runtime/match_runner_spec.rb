require "spec_helper"

RSpec.describe FightingAI::Runtime::MatchRunner do
  EXPECTED_WARNING_COUNT = 1
  CAPTURE_ERROR_MESSAGE = "X server screenshot capture failed"
  STALL_DISTANCE = 100.0
  MOVED_DISTANCE = STALL_DISTANCE - FightingAI.config.stale_distance_reset_threshold
  MINOR_MOVED_DISTANCE = STALL_DISTANCE - (FightingAI.config.stale_distance_reset_threshold / 2.0)
  TEST_GAME_ID = "match-runner-test"
  TEST_FRAME_COUNT = 3
  TEST_DISTANCE = 88.0

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

  describe "#run_round" do
    it "updates the live ui on every frame" do
      ui = instance_double("UI")
      game = FakeMatchRunnerGameAdapter.new(
        frame_states: [
          FakeFrameState.new(frame_number: 1, fight_active: true, round_over: false, distance: TEST_DISTANCE),
          FakeFrameState.new(frame_number: 2, fight_active: true, round_over: false, distance: TEST_DISTANCE),
          FakeFrameState.new(frame_number: 3, fight_active: false, round_over: true, distance: TEST_DISTANCE)
        ]
      )
      emulator = instance_double(FightingAI::Emulator::Adapter)
      allow(emulator).to receive(:advance_frame).and_return(1, 2, 3)
      allow(game).to receive(:vision_enabled?).and_return(false)
      allow(game).to receive(:extract_game_state).and_return(*game.frame_states)

      runner = described_class.new(
        emulator_adapter: emulator,
        game_adapter: game,
        agents: {},
        ui: ui,
        logger: ->(_message) {}
      )
      match = instance_double("Match", id: "match-1")
      round = instance_double("Round", number: 1)

      expect(ui).to receive(:update).exactly(TEST_FRAME_COUNT).times
      allow(round).to receive(:record_frame)
      allow(round).to receive(:finish!)

      runner.send(:run_round, match, round)
    end
  end
end

class FakeMatchRunnerGameAdapter
  GAME_ID = "match-runner-test"

  attr_reader :frame_states

  def initialize(frame_states:)
    @frame_states = frame_states
  end

  def vision_enabled?
    false
  end

  def extract_game_state(frame_number, frame_observation:)
    @frame_states.shift
  end
end

FakeFighterState = Struct.new(:health, :distance) do
  def distance_to(_other)
    distance
  end
end

FakeFrameState = Struct.new(:frame_number, :fight_active, :round_over, :distance) do
  def fighter1
    FakeFighterState.new(100, distance)
  end

  def fighter2
    FakeFighterState.new(100, distance)
  end

  def round_time_remaining
    90
  end

  def fight_active?
    fight_active
  end

  def round_over?
    round_over
  end
end
