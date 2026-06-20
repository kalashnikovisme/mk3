require "spec_helper"

RSpec.describe FightingAI::Vision::PositionDetector do
  IMAGE_WIDTH = 297
  IMAGE_HEIGHT = 216
  PLAYER_ONE_CENTER_X = 54
  PLAYER_ONE_BOTTOM_Y = 190
  PLAYER_TWO_CENTER_X = 173
  PLAYER_TWO_BOTTOM_Y = 192
  POSITION_TIMER_VALUE = 99

  it "scales both ordered character detections and preserves the shared timer result" do
    player1 = build_detection(PLAYER_ONE_CENTER_X, PLAYER_ONE_BOTTOM_Y)
    player2 = build_detection(PLAYER_TWO_CENTER_X, PLAYER_TWO_BOTTOM_Y)
    detector = instance_double(
      FightingAI::Vision::CharacterPositionDetector,
      detect: {
        player1: player1,
        player2: player2,
        image_width: IMAGE_WIDTH,
        image_height: IMAGE_HEIGHT,
        timer: POSITION_TIMER_VALUE
      }
    )
    position_detector = described_class.new(detector: detector)

    result = position_detector.detect(double("FrameObservation"))

    expect(result[:player1]).to include(x: 47, y: 225)
    expect(result[:player2]).to include(x: 149, y: 228)
    expect(result[:timer]).to eq(POSITION_TIMER_VALUE)
  end

  def build_detection(center_x, bottom_y)
    FightingAI::Vision::Detection.new(
      template_name: "idle",
      x: center_x,
      y: bottom_y,
      width: 1,
      height: 1,
      center_x: center_x,
      bottom_y: bottom_y,
      confidence: 1.0
    )
  end
end
