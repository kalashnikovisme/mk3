require "spec_helper"
require "tmpdir"

RSpec.describe FightingAI::Emulator::RetroArch::FrameGrabber do
  SCREENSHOT_NAME = "capture.png"
  EMPTY_SCREENSHOT_BYTES = "".b
  COMPLETE_SCREENSHOT_BYTES = "png-data".b
  WRITE_DELAY_SECONDS = 0.08

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  it "waits until a new screenshot file is non-empty before returning" do
    stub_const("#{described_class}::SCREENSHOT_DIR", @dir)
    screenshot_path = File.join(@dir, SCREENSHOT_NAME)

    allow(FightingAI::Emulator::RetroArch::NetworkCommands).to receive(:screenshot) do
      File.binwrite(screenshot_path, EMPTY_SCREENSHOT_BYTES)
      Thread.new do
        sleep WRITE_DELAY_SECONDS
        File.binwrite(screenshot_path, COMPLETE_SCREENSHOT_BYTES)
      end
    end

    frame = described_class.new.capture

    expect(frame.path).to eq(screenshot_path)
    expect(File.size(frame.path)).to eq(COMPLETE_SCREENSHOT_BYTES.bytesize)
  end
end
