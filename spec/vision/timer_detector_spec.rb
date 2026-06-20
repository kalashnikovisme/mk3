require "spec_helper"

RSpec.describe FightingAI::Vision::TimerDetector do
  TIMER_VALUE = 87

  it "returns only the timer value from the timer-only detector" do
    frame = double("FrameObservation")
    detector = instance_double(
      FightingAI::Vision::CharacterPositionDetector,
      detect: { timer: TIMER_VALUE },
      start: nil,
      stop: nil
    )
    timer_detector = described_class.new(detector: detector)

    timer_detector.start
    expect(detector).to have_received(:start)

    expect(timer_detector.detect(frame)).to eq(TIMER_VALUE)
    timer_detector.stop
    expect(detector).to have_received(:stop)
  end
end
