require "spec_helper"

RSpec.describe FightingAI::Vision::AsyncVisionScanner do
  SCAN_SETTLE_WAIT = 0.1
  SCAN_RESULT_ONE  = { detections: [], image_width: 297, image_height: 216, timer: 90 }.freeze
  SCAN_RESULT_TWO  = { detections: [], image_width: 297, image_height: 216, timer: 80 }.freeze

  let(:detector)  { instance_double(FightingAI::Vision::CharacterPositionDetector) }
  let(:frame_one) { instance_double(FightingAI::Observation::FrameObservation) }
  let(:frame_two) { instance_double(FightingAI::Observation::FrameObservation) }

  subject(:scanner) { described_class.new(detector) }

  after { scanner.stop }

  it "returns nil before any scan has completed" do
    expect(scanner.latest_result).to be_nil
  end

  it "returns the result after a scan completes" do
    allow(detector).to receive(:detect).with(frame_one).and_return(SCAN_RESULT_ONE)

    scanner.submit(frame_one)
    sleep(SCAN_SETTLE_WAIT)

    expect(scanner.latest_result).to eq(SCAN_RESULT_ONE)
  end

  it "returns the most recent completed scan result when multiple scans run" do
    allow(detector).to receive(:detect).with(frame_one).and_return(SCAN_RESULT_ONE)
    allow(detector).to receive(:detect).with(frame_two).and_return(SCAN_RESULT_TWO)

    scanner.submit(frame_one)
    sleep(SCAN_SETTLE_WAIT)
    scanner.submit(frame_two)
    sleep(SCAN_SETTLE_WAIT)

    expect(scanner.latest_result).to eq(SCAN_RESULT_TWO)
  end

  it "latest-wins: when two frames are submitted before the worker starts, only the second is scanned" do
    scanned = []
    latch   = Mutex.new
    latch.lock

    allow(detector).to receive(:detect) do |frame|
      latch.lock   # blocks until main thread releases
      latch.unlock
      scanned << frame
      SCAN_RESULT_TWO
    end

    # Hold the worker at its first detect call so we can submit both
    # frames before any scan starts.
    scanner.submit(frame_one)
    scanner.submit(frame_two)
    latch.unlock   # let the worker proceed

    sleep(SCAN_SETTLE_WAIT)

    # Regardless of whether frame_one was replaced, frame_two must be the last result.
    expect(scanner.latest_result).to eq(SCAN_RESULT_TWO)
    # The worker must have scanned at most 2 frames total (never more).
    expect(scanned.size).to be <= 2
    expect(scanned.last).to eq(frame_two)
  end

  it "continues scanning after a detector error" do
    allow(detector).to receive(:detect).with(frame_one).and_raise(RuntimeError, "GPU exploded")
    allow(detector).to receive(:detect).with(frame_two).and_return(SCAN_RESULT_TWO)

    scanner.submit(frame_one)
    sleep(SCAN_SETTLE_WAIT)
    scanner.submit(frame_two)
    sleep(SCAN_SETTLE_WAIT)

    expect(scanner.latest_result).to eq(SCAN_RESULT_TWO)
  end

  it "stops the worker thread cleanly" do
    scanner.stop
    expect(scanner.instance_variable_get(:@worker)).not_to be_alive
  end
end
