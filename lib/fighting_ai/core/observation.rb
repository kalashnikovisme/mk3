module FightingAI
  module Core
    # Processed representation of GameState fed to an Agent.
    # Normalized to floats in [0, 1] so agents need no knowledge of raw
    # memory layout or emulator internals.
    Observation = Data.define(
      :frame_number,
      :my_health_pct,
      :opponent_health_pct,
      :my_x_normalized,
      :my_y_normalized,
      :opponent_x_normalized,
      :opponent_y_normalized,
      :round_time_normalized,
      :raw
    ) do
      def to_vector
        [
          my_health_pct,
          opponent_health_pct,
          my_x_normalized,
          my_y_normalized,
          opponent_x_normalized,
          opponent_y_normalized,
          round_time_normalized
        ]
      end
    end

    Observation::VECTOR_SIZE = 7
  end
end
