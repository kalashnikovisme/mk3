module FightingAI
  module Training
    # Accumulates RL transitions from both self-play agents.
    # Both P1 and P2 push into the same buffer; the shared policy trains on
    # the combined experience.
    class TrajectoryBuffer
      def initialize(min_size: 512)
        @min_size    = min_size
        @transitions = []
      end

      def push(obs:, action:, log_prob:, value:, reward:, done:)
        @transitions << {
          obs:      obs,
          action:   action,
          log_prob: log_prob,
          value:    value,
          reward:   reward,
          done:     done
        }
      end

      def size
        @transitions.size
      end

      def ready?
        @transitions.size >= @min_size
      end

      # Returns all stored transitions and clears the buffer.
      def flush
        data = @transitions.dup
        @transitions.clear
        data
      end
    end
  end
end
