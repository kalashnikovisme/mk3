require_relative "memory_map"
require_relative "../../core/game_state"
require_relative "../../core/fighter_state"

module FightingAI
  module Game
    module MortalKombat3
      # Converts vision detections into typed Core::GameState / Core::FighterState objects.
      # All state comes from vision: health from HealthBarDetector, positions and timer
      # from CharacterPositionDetector. WRAM is not used.
      module StateExtractor
        MM = MemoryMap

        PLAYER_ONE   = 1
        PLAYER_TWO   = 2
        DEFAULT_X    = 0
        DEFAULT_Y    = 0
        ZERO_HEALTH  = 0
        ZERO_TIMER   = 0

        def self.extract(frame_number, vision_positions: nil, vision_timer: nil, vision_health: nil)
          fighter1 = build_fighter(PLAYER_ONE, vision_positions&.fetch(PLAYER_ONE, nil), vision_health&.fetch(PLAYER_ONE, nil))
          fighter2 = build_fighter(PLAYER_TWO, vision_positions&.fetch(PLAYER_TWO, nil), vision_health&.fetch(PLAYER_TWO, nil))

          round_time_remaining = vision_timer
          round_over = fighter1.health == ZERO_HEALTH ||
                       fighter2.health == ZERO_HEALTH ||
                       (round_time_remaining.is_a?(Integer) && round_time_remaining == ZERO_TIMER)
          fight_active = !round_over

          Core::GameState.new(
            frame_number:         frame_number,
            fighter1:             fighter1,
            fighter2:             fighter2,
            round_time_remaining: round_time_remaining,
            fight_active:         fight_active,
            round_over:           round_over,
            match_over:           false
          )
        end

        private_class_method def self.build_fighter(player_index, vision_position, vision_health)
          Core::FighterState.new(
            player_index: player_index,
            health:       vision_health || MM::MAX_HEALTH,
            max_health:   MM::MAX_HEALTH,
            x:            vision_position&.fetch(:x, nil) || DEFAULT_X,
            y:            vision_position&.fetch(:y, nil) || DEFAULT_Y
          )
        end
      end
    end
  end
end
