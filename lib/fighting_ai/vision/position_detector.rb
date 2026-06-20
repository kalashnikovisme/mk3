module FightingAI
  module Vision
    class PositionDetector
      def initialize(detector: CharacterPositionDetector.new, x_max: Game::MortalKombat3::MemoryMap::X_MAX,
        y_max: Game::MortalKombat3::MemoryMap::Y_MAX)
        @detector = detector
        @x_max    = x_max
        @y_max    = y_max
      end

      def detect(frame_observation)
        result = @detector.detect(frame_observation)
        {
          player1: scale(result[:player1], result),
          player2: scale(result[:player2], result),
          timer: result[:timer]
        }
      end

      def start
        @detector.start
      end

      def stop
        @detector.stop
      end

      private

      def scale(detection, result)
        CharacterPositionDetector.scale_position(
          detection,
          image_width: result.fetch(:image_width),
          image_height: result.fetch(:image_height),
          x_max: @x_max,
          y_max: @y_max
        )
      end
    end
  end
end
