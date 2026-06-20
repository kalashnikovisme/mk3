require "spec_helper"
require "stringio"

RSpec.describe FightingAI::Runtime::FrameCaptureRunner do
  SCREENSHOT_BYTE_SIZE = 14
  SINGLE_FRAME_LIMIT   = 1
  PLAYER_ONE_HEALTH    = 166
  PLAYER_TWO_HEALTH    = 84

  it "writes the frame number next to its byte size" do
    frame = double("Frame", byte_size: SCREENSHOT_BYTE_SIZE)
    emulator = instance_double(FightingAI::Emulator::Adapter, capture_frame: frame)
    output = StringIO.new
    frame_advancer = double("FrameAdvancer", call: nil)
    runner = described_class.new(
      emulator: emulator,
      output: output,
      frame_limit: SINGLE_FRAME_LIMIT,
      frame_advancer: frame_advancer
    )

    runner.run

    expect(output.string).to match(
      /\Af: #{described_class::INITIAL_FRAME_NUMBER}; size: #{SCREENSHOT_BYTE_SIZE}; ms: \d+\n\z/
    )
    expect(emulator).to have_received(:capture_frame).once
    expect(frame_advancer).to have_received(:call).once
    expect(runner).not_to be_interrupted
  end

  it "appends enabled detector metadata to the frame log" do
    frame = double("Frame", byte_size: SCREENSHOT_BYTE_SIZE)
    emulator = instance_double(FightingAI::Emulator::Adapter, capture_frame: frame)
    output = StringIO.new
    metadata_detector = lambda do |received_frame|
      expect(received_frame).to equal(frame)
      { h1: PLAYER_ONE_HEALTH, h2: PLAYER_TWO_HEALTH }
    end
    runner = described_class.new(
      emulator: emulator,
      output: output,
      frame_limit: SINGLE_FRAME_LIMIT,
      frame_advancer: -> {},
      metadata_detector: metadata_detector
    )

    runner.run

    expect(output.string).to match(
      /\Af: #{described_class::INITIAL_FRAME_NUMBER}; size: #{SCREENSHOT_BYTE_SIZE}; h1: #{PLAYER_ONE_HEALTH}; h2: #{PLAYER_TWO_HEALTH}; ms: \d+\n\z/
    )
  end

  it "exits quietly when capture is interrupted during shutdown" do
    capture_error = FightingAI::Emulator::RetroArch::FrameGrabber::CaptureError.new("display stopped")
    emulator = instance_double(FightingAI::Emulator::Adapter)
    allow(emulator).to receive(:capture_frame).and_raise(capture_error)
    output = StringIO.new
    runner = nil
    frame_advancer = -> { runner.stop }
    runner = described_class.new(
      emulator: emulator,
      output: output,
      frame_limit: SINGLE_FRAME_LIMIT,
      frame_advancer: frame_advancer
    )

    expect { runner.run }.not_to raise_error
    expect(output.string).to be_empty
    expect(runner).to be_interrupted
  end
end
