module FightingAI
  module Core
    class Round
      attr_reader :number, :frames, :winner

      def initialize(number:)
        @number   = number
        @frames   = []
        @winner   = nil
        @stale    = false
        @finished = false
      end

      def record_frame(frame)
        raise "Cannot add frames to a finished round" if finished?
        @frames << frame
      end

      def finish!(winner:, stale: false)
        @winner   = winner
        @stale    = stale
        @finished = true
      end

      def finished? = @finished
      def stale?    = @stale
      def frame_count = @frames.size

      def last_game_state
        @frames.last&.game_state
      end
    end
  end
end
