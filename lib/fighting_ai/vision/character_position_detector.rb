require_relative "template_matcher"

module FightingAI
  module Vision
    class CharacterPositionDetector
      DEFAULT_CHARACTER = :sub_zero
      DEFAULT_TEMPLATE_ROOT = File.expand_path("../../../data/vision/templates", __dir__).freeze
      PLAYER_ONE = 1
      PLAYER_TWO = 2
      IMAGE_MAX_INDEX_ADJUSTMENT = 1
      DEFAULT_AXIS_MAX = 255

      attr_reader :character

      def initialize(character: DEFAULT_CHARACTER, template_root: DEFAULT_TEMPLATE_ROOT, min_confidence: TemplateMatcher::DEFAULT_MIN_CONFIDENCE)
        @character = character.to_sym
        @matcher = TemplateMatcher.new(
          template_dir: File.join(template_root, character.to_s),
          min_confidence: min_confidence
        )
      end

      def available?
        @matcher.templates.any?
      end

      def detect(frame_observation)
        detections, image_width, image_height = @matcher.detect_with_size(frame_observation)
        {
          character: @character,
          detections: detections,
          image_width: image_width,
          image_height: image_height,
          player1: detections.fetch(TemplateMatcher::FIRST_DETECTION_INDEX, nil),
          player2: detections.fetch(TemplateMatcher::SECOND_DETECTION_INDEX, nil)
        }
      end

      def self.scale_position(detection, image_width:, image_height:, x_max: DEFAULT_AXIS_MAX, y_max: DEFAULT_AXIS_MAX)
        return nil unless detection

        {
          x: scale_axis(detection.center_x, image_width, x_max),
          y: scale_axis(detection.bottom_y, image_height, y_max),
          confidence: detection.confidence,
          template_name: detection.template_name
        }
      end

      def self.scale_axis(value, image_size, axis_max)
        denominator = [image_size - IMAGE_MAX_INDEX_ADJUSTMENT, IMAGE_MAX_INDEX_ADJUSTMENT].max
        (value.to_f * axis_max / denominator).round
      end
    end
  end
end
