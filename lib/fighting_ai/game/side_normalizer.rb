module FightingAI
  module Game
    # Transforms observations so the policy always perceives itself as the left-side fighter.
    #
    # In a fighting game, the same fighting logic applies regardless of which side of the
    # screen the character occupies. Without normalization the policy must learn two
    # symmetric copies of every behavior — one for each side.
    #
    # Canonical view: the agent is always on the left (lower x) facing the opponent.
    # When the agent is on the right side (my_x > opponent_x), x positions are mirrored.
    class SideNormalizer
      def normalize(observation)
        return observation if on_left_side?(observation)

        Core::Observation.new(
          frame_number:          observation.frame_number,
          my_health_pct:         observation.my_health_pct,
          opponent_health_pct:   observation.opponent_health_pct,
          my_x_normalized:       1.0 - observation.my_x_normalized,
          my_y_normalized:       observation.my_y_normalized,
          opponent_x_normalized: 1.0 - observation.opponent_x_normalized,
          opponent_y_normalized: observation.opponent_y_normalized,
          round_time_normalized: observation.round_time_normalized,
          raw:                   observation.raw
        )
      end

      private

      def on_left_side?(observation)
        observation.my_x_normalized <= observation.opponent_x_normalized
      end
    end
  end
end
