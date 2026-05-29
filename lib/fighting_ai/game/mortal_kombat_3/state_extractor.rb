require_relative "memory_map"
require_relative "../../core/game_state"
require_relative "../../core/fighter_state"

module FightingAI
  module Game
    module MortalKombat3
      # Converts raw frame snapshot hashes (sent by the Lua bridge)
      # into typed Core::GameState / Core::FighterState objects.
      module StateExtractor
        MM = MemoryMap

        def self.extract(snapshot)
          players = snapshot.fetch("players")

          fighter1 = build_fighter(1, players.fetch("1"))
          fighter2 = build_fighter(2, players.fetch("2"))

          raw_game_state = snapshot.fetch("game_state", 2).to_i
          round_over     = raw_game_state == 3
          match_over     = snapshot.fetch("match_over", false)
          fight_active   = raw_game_state == 2 && !round_over

          Core::GameState.new(
            frame_number:          snapshot.fetch("frame").to_i,
            fighter1:              fighter1,
            fighter2:              fighter2,
            round_number:          snapshot.fetch("round", 1).to_i,
            round_time_remaining:  snapshot.fetch("timer", MM::TIMER_MAX).to_i,
            fight_active:          fight_active,
            round_over:            round_over,
            match_over:            match_over
          )
        end

        private_class_method def self.build_fighter(player_index, data)
          state_bits = data.fetch("state", 0).to_i

          facing_raw = data.fetch("facing", 0).to_i
          facing = facing_raw == 0 ? Core::FacingDirection::RIGHT : Core::FacingDirection::LEFT

          animation_state = Core::AnimationState.new(
            name:         data.fetch("anim", 0).to_s,
            frame_index:  data.fetch("anim_frame", 0).to_i,
            total_frames: data.fetch("anim_total", 1).to_i
          )

          Core::FighterState.new(
            player_index:   player_index,
            health:         data.fetch("health").to_i,
            max_health:     data.fetch("max_health", 144).to_i,
            x:              data.fetch("x").to_i,
            y:              data.fetch("y").to_i,
            facing:         facing,
            animation_state: animation_state,
            in_hitstun:     (state_bits & MM::STATE_HITSTUN)   != 0,
            in_blockstun:   (state_bits & MM::STATE_BLOCKSTUN) != 0,
            knocked_down:   (state_bits & MM::STATE_KNOCKDOWN) != 0,
            airborne:       (state_bits & MM::STATE_AIRBORNE)  != 0
          )
        end
      end
    end
  end
end
