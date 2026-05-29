module FightingAI
  module Core
    # Processed representation of GameState fed to an Agent.
    # Normalized to floats in [0, 1] or known discrete values so agents
    # need no knowledge of raw memory layout or emulator internals.
    Observation = Data.define(
      :frame_number,
      :my_health_pct,
      :opponent_health_pct,
      :my_x_normalized,
      :my_y_normalized,
      :opponent_x_normalized,
      :opponent_y_normalized,
      :distance_normalized,
      :my_facing,
      :opponent_facing,
      :my_in_hitstun,
      :my_in_blockstun,
      :my_knocked_down,
      :my_airborne,
      :opponent_in_hitstun,
      :opponent_in_blockstun,
      :opponent_knocked_down,
      :opponent_airborne,
      :round_time_normalized,
      :round_number,
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
          distance_normalized,
          my_facing == :right ? 1.0 : 0.0,
          opponent_facing == :right ? 1.0 : 0.0,
          my_in_hitstun ? 1.0 : 0.0,
          my_in_blockstun ? 1.0 : 0.0,
          my_knocked_down ? 1.0 : 0.0,
          my_airborne ? 1.0 : 0.0,
          opponent_in_hitstun ? 1.0 : 0.0,
          opponent_in_blockstun ? 1.0 : 0.0,
          opponent_knocked_down ? 1.0 : 0.0,
          opponent_airborne ? 1.0 : 0.0,
          round_time_normalized
        ]
      end
    end
  end
end
