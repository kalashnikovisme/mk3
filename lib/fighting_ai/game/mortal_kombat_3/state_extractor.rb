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

        PLAYER_ONE = 1
        PLAYER_TWO = 2
        PLAYER_ONE_KEY = "1"
        PLAYER_TWO_KEY = "2"
        DEFAULT_ROUND_NUMBER = 1
        ACTIVE_GAME_STATE = 2
        INACTIVE_GAME_STATE = 0
        DEFAULT_ANIMATION = 0
        DEFAULT_ANIMATION_FRAME = 0
        DEFAULT_ANIMATION_TOTAL = 1
        DEFAULT_X = 0
        DEFAULT_FACING = 0
        DEFAULT_STATE = 0
        EMPTY_BITFIELD = 0
        FACING_LEFT_VALUE = 1
        HITSTUN_STATE_BIT = 1
        BLOCKSTUN_STATE_BIT = 2
        KNOCKED_DOWN_STATE_BIT = 4
        AIRBORNE_STATE_BIT = 8

        def self.extract(snapshot, vision_positions: nil, vision_timer: nil)
          players = snapshot.fetch("players")

          fighter1 = build_fighter(PLAYER_ONE, players.fetch(PLAYER_ONE_KEY), vision_positions&.fetch(PLAYER_ONE, nil))
          fighter2 = build_fighter(PLAYER_TWO, players.fetch(PLAYER_TWO_KEY), vision_positions&.fetch(PLAYER_TWO, nil))

          screen               = snapshot.fetch("screen", nil)&.to_i
          in_fight             = screen ? MM::FIGHT_SCREENS.include?(screen) : snapshot.fetch("game_state", INACTIVE_GAME_STATE).to_i == ACTIVE_GAME_STATE
          round_time_remaining = vision_timer&.to_i
          round_over           = in_fight && (fighter1.health == 0 || fighter2.health == 0 || round_time_remaining == 0)
          fight_active         = in_fight && !round_over

          Core::GameState.new(
            frame_number:         snapshot.fetch("frame").to_i,
            fighter1:             fighter1,
            fighter2:             fighter2,
            round_number:         snapshot.fetch("round", DEFAULT_ROUND_NUMBER).to_i,
            round_time_remaining: round_time_remaining,
            fight_active:         fight_active,
            round_over:           round_over,
            match_over:           false
          )
        end

        private_class_method def self.build_fighter(player_index, data, vision_position)
          animation_state = Core::AnimationState.new(
            name:         data.fetch("anim", DEFAULT_ANIMATION).to_s,
            frame_index:  data.fetch("anim_frame", DEFAULT_ANIMATION_FRAME).to_i,
            total_frames: data.fetch("anim_total", DEFAULT_ANIMATION_TOTAL).to_i
          )
          state = data.fetch("state", DEFAULT_STATE).to_i

          Core::FighterState.new(
            player_index:    player_index,
            health:          data.fetch("health").to_i,
            max_health:      data.fetch("max_health", MM::MAX_HEALTH).to_i,
            x:               vision_position&.fetch(:x, nil) || data.fetch("x", DEFAULT_X).to_i,
            y:               vision_position&.fetch(:y, nil) || data.fetch("y").to_i,
            facing:          data.fetch("facing", DEFAULT_FACING).to_i == FACING_LEFT_VALUE ? Core::FacingDirection::LEFT : Core::FacingDirection::RIGHT,
            animation_state: animation_state,
            in_hitstun:      bit_set?(state, HITSTUN_STATE_BIT),
            in_blockstun:    bit_set?(state, BLOCKSTUN_STATE_BIT),
            knocked_down:    bit_set?(state, KNOCKED_DOWN_STATE_BIT),
            airborne:        bit_set?(state, AIRBORNE_STATE_BIT)
          )
        end

        private_class_method def self.bit_set?(value, bit)
          (value & bit) != EMPTY_BITFIELD
        end
      end
    end
  end
end
