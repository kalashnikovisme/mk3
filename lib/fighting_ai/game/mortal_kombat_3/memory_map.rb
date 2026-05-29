module FightingAI
  module Game
    module MortalKombat3
      module MemoryMap
        # --- Screen / navigation state (7E3A7E) ---
        SCREEN_ADDR       = 0x3A7E

        SCREEN_ROOFTOP        = 0x00
        SCREEN_JADES_DESERT   = 0x01
        SCREEN_SCORPIONS_LAIR = 0x02
        SCREEN_KAHNS_KAVE     = 0x03
        SCREEN_WATERFRONT     = 0x04
        SCREEN_THE_PORTAL     = 0x05
        SCREEN_PIT3_UMK3      = 0x06
        SCREEN_PIT3_MK3       = 0x09
        SCREEN_VERSUS         = 0x0B
        SCREEN_TITLE          = 0x0C
        SCREEN_CHAR_SELECT    = 0x0D
        SCREEN_CONTINUE       = 0x0F
        SCREEN_DESTINY        = 0x11
        SCREEN_MAIN_MENU      = 0x13

        # Fight screens: 0x00–0x09 (arena levels during active play)
        FIGHT_SCREENS = (0x00..0x09).freeze

        # --- Timers ---
        LEVEL_TIMER_ADDR    = 0x3BD4
        FATALITY_TIMER_ADDR = 0x3BE0

        # --- Player 1 ---
        P1_HEALTH_ADDR    = 0x36D4
        P1_ROUNDS_WON     = 0x36E0
        P1_WIN_STREAK     = 0x3AA2

        # --- Player 2 ---
        P2_HEALTH_ADDR    = 0x3898
        P2_ROUNDS_WON     = 0x38A4
        P2_WIN_STREAK     = 0x3AA4

        # --- Health constant ---
        MAX_HEALTH = 0xA6  # 166 — same for both players

        # --- Not yet located (need RAM search) ---
        # P1_X_ADDR, P1_Y_ADDR, P1_FACING_ADDR, P1_ANIM_ADDR
        # P2_X_ADDR, P2_Y_ADDR, P2_FACING_ADDR, P2_ANIM_ADDR

        def self.player_addresses(player_index)
          case player_index
          when 1
            { health: P1_HEALTH_ADDR, rounds_won: P1_ROUNDS_WON }
          when 2
            { health: P2_HEALTH_ADDR, rounds_won: P2_ROUNDS_WON }
          else
            raise ArgumentError, "player_index must be 1 or 2"
          end
        end
      end
    end
  end
end
