module FightingAI
  module Game
    # Transforms observations so the policy always perceives itself as the left-side fighter.
    #
    # In a fighting game, the same fighting logic applies regardless of which side of the
    # screen the character occupies. Without normalization the policy must learn two
    # symmetric copies of every behavior — one for each side.
    #
    # Canonical view: the agent is always on the left, facing right toward the opponent.
    # When the fighter is on the right (facing left):
    #   - x positions are mirrored: x_norm → 1.0 - x_norm
    #   - my_facing and opponent_facing are flipped to their canonical values
    #   - all other fields are unchanged
    #
    # Action direction is already handled by Game::Adapter#action_to_input_sequence,
    # which flips walk_forward / walk_back based on the fighter's facing direction
    # in the live game state. SideNormalizer therefore only acts on the observation.
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
          distance_normalized:   observation.distance_normalized,
          my_facing:             :right,
          opponent_facing:       :left,
          my_in_hitstun:         observation.my_in_hitstun,
          my_in_blockstun:       observation.my_in_blockstun,
          my_knocked_down:       observation.my_knocked_down,
          my_airborne:           observation.my_airborne,
          opponent_in_hitstun:   observation.opponent_in_hitstun,
          opponent_in_blockstun: observation.opponent_in_blockstun,
          opponent_knocked_down: observation.opponent_knocked_down,
          opponent_airborne:     observation.opponent_airborne,
          round_time_normalized: observation.round_time_normalized,
          round_number:          observation.round_number,
          raw:                   observation.raw
        )
      end

      private

      # A fighter facing right is on the left side of the screen.
      def on_left_side?(observation)
        observation.my_facing == :right
      end
    end
  end
end
