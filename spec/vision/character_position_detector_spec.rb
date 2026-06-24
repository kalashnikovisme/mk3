require "spec_helper"

RSpec.describe FightingAI::Vision::CharacterPositionDetector do
  DETECTOR_IMAGE_WIDTH = 297
  DETECTOR_IMAGE_HEIGHT = 216
  DETECTOR_MATCH_SECONDS = 0.184

  describe "#parse_response" do
    it "parses both selected detections and verbose candidates" do
      detector = described_class.new
      payload = {
        ok: true,
        image_width: DETECTOR_IMAGE_WIDTH,
        image_height: DETECTOR_IMAGE_HEIGHT,
        match_seconds: DETECTOR_MATCH_SECONDS,
        detections: [
          detection_payload("idle/01", center_x: 54, bottom_y: 190, confidence: 0.91)
        ],
        candidates: [
          detection_payload("walk/02", center_x: 173, bottom_y: 192, confidence: 0.83),
          detection_payload("idle/01", center_x: 54, bottom_y: 190, confidence: 0.91)
        ]
      }.to_json

      detector.instance_variable_set(:@stdout, StringIO.new("#{payload}\n"))

      result = detector.send(:parse_response)

      expect(result[:detections].map(&:template_name)).to eq(["idle/01"])
      expect(result[:candidates].map(&:template_name)).to eq(["walk/02", "idle/01"])
      expect(result[:player1]&.template_name).to eq("idle/01")
      expect(result[:player2]).to be_nil
      expect(result[:detect_ms]).to eq(184)
    end
  end

  def detection_payload(template_name, center_x:, bottom_y:, confidence:)
    {
      "template_name" => template_name,
      "x" => center_x - 10,
      "y" => bottom_y - 20,
      "width" => 20,
      "height" => 20,
      "center_x" => center_x,
      "bottom_y" => bottom_y,
      "confidence" => confidence
    }
  end
end
