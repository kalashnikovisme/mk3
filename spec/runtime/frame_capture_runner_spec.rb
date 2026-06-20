require "spec_helper"
require "stringio"
require "tmpdir"

RSpec.describe FightingAI::Runtime::FrameCaptureRunner do
  SCREENSHOT_CONTENT = "captured-frame"
  SINGLE_FRAME_LIMIT = 1
  PLAYER_ONE_HEALTH = 166
  PLAYER_TWO_HEALTH = 84

  it "writes the frame number next to its PNG byte size" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "frame.png")
      File.binwrite(path, SCREENSHOT_CONTENT)
      emulator = instance_double(FightingAI::Emulator::Adapter, capture_frame: double("Frame", path: path))
      output = StringIO.new
      frame_advancer = double("FrameAdvancer", call: nil)
      runner = described_class.new(
        emulator: emulator,
        output: output,
        frame_limit: SINGLE_FRAME_LIMIT,
        frame_advancer: frame_advancer
      )

      runner.run

      expect(output.string).to eq("f: #{described_class::INITIAL_FRAME_NUMBER}; size: #{SCREENSHOT_CONTENT.bytesize}\n")
      expect(emulator).to have_received(:capture_frame).once
      expect(frame_advancer).to have_received(:call).once
      expect(runner).not_to be_interrupted
    end
  end

  it "appends enabled detector metadata to the frame log" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "frame.png")
      File.binwrite(path, SCREENSHOT_CONTENT)
      frame = double("Frame", path: path)
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

      expect(output.string).to eq(
        "f: #{described_class::INITIAL_FRAME_NUMBER}; size: #{SCREENSHOT_CONTENT.bytesize}; " \
        "h1: #{PLAYER_ONE_HEALTH}; h2: #{PLAYER_TWO_HEALTH}\n"
      )
    end
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
