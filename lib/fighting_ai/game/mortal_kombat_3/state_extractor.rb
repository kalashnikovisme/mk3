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

          screen               = snapshot.fetch("screen", MM::SCREEN_TITLE).to_i
          in_fight             = MM::FIGHT_SCREENS.include?(screen)
          round_time_remaining = snapshot.fetch("timer", 99).to_i
          round_over           = in_fight && (fighter1.health == 0 || fighter2.health == 0 || round_time_remaining == 0)
          fight_active         = in_fight && !round_over

          Core::GameState.new(
            frame_number:         snapshot.fetch("frame").to_i,
            fighter1:             fighter1,
            fighter2:             fighter2,
            round_number:         1,
            round_time_remaining: snapshot.fetch("timer", 99).to_i,
            fight_active:         fight_active,
            round_over:           round_over,
            match_over:           false
          )
        end

        private_class_method def self.build_fighter(player_index, data)
          animation_state = Core::AnimationState.new(
            name:         data.fetch("anim", 0).to_s,
            frame_index:  data.fetch("anim_frame", 0).to_i,
            total_frames: data.fetch("anim_total", 1).to_i
          )

          Core::FighterState.new(
            player_index:    player_index,
            health:          data.fetch("health").to_i,
            max_health:      data.fetch("max_health", MM::MAX_HEALTH).to_i,
            x:               data.fetch("x").to_i,
            y:               data.fetch("y").to_i,
            facing:          Core::FacingDirection::RIGHT,
            animation_state: animation_state,
            in_hitstun:      false,
            in_blockstun:    false,
            knocked_down:    false,
            airborne:        false
          )
        end
      end
    end
  end
end
