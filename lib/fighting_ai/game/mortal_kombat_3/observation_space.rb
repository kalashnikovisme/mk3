require_relative "memory_map"
require_relative "../../core/observation"

module FightingAI
  module Game
    module MortalKombat3
      module ObservationSpace
        MM = MemoryMap

        def self.build(game_state, player_index:)
          me  = game_state.fighter_for(player_index)
          opp = game_state.opponent_of(player_index)

          max_distance = MM::X_MAX.to_f

          Core::Observation.new(
            frame_number:               game_state.frame_number,
            my_health_pct:              me.health_pct,
            opponent_health_pct:        opp.health_pct,
            my_x_normalized:            me.x.to_f / MM::X_MAX,
            my_y_normalized:            me.y.to_f / MM::Y_MAX,
            opponent_x_normalized:      opp.x.to_f / MM::X_MAX,
            opponent_y_normalized:      opp.y.to_f / MM::Y_MAX,
            distance_normalized:        game_state.distance.to_f / max_distance,
            my_facing:                  me.facing.value,
            opponent_facing:            opp.facing.value,
            my_in_hitstun:              me.in_hitstun,
            my_in_blockstun:            me.in_blockstun,
            my_knocked_down:            me.knocked_down,
            my_airborne:                me.airborne,
            opponent_in_hitstun:        opp.in_hitstun,
            opponent_in_blockstun:      opp.in_blockstun,
            opponent_knocked_down:      opp.knocked_down,
            opponent_airborne:          opp.airborne,
            round_time_normalized:      game_state.round_time_remaining.to_f / MM::TIMER_MAX,
            round_number:               game_state.round_number,
            raw:                        game_state
          )
        end
      end
    end
  end
end
