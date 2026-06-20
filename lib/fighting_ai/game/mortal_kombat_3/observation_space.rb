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

          Core::Observation.new(
            frame_number:          game_state.frame_number,
            my_health_pct:         me.health_pct,
            opponent_health_pct:   opp.health_pct,
            my_x_normalized:       me.x.to_f / MM::X_MAX,
            my_y_normalized:       me.y.to_f / MM::Y_MAX,
            opponent_x_normalized: opp.x.to_f / MM::X_MAX,
            opponent_y_normalized: opp.y.to_f / MM::Y_MAX,
            round_time_normalized: (game_state.round_time_remaining || MM::TIMER_MAX).to_f / MM::TIMER_MAX,
            raw:                   game_state
          )
        end
      end
    end
  end
end
