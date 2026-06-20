module FightingAI
  module Vision
    class TimerDetector
      TIMER_ONLY_ACTION_MODE = "timer_only"

      def initialize(detector: CharacterPositionDetector.new(action_mode: TIMER_ONLY_ACTION_MODE))
        @detector = detector
      end

      def detect(frame_observation)
        @detector.detect(frame_observation).fetch(:timer)
      end

      def start
        @detector.start
      end

      def stop
        @detector.stop
      end
    end
  end
end
