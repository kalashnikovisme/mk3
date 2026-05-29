module FightingAI
  module Game
    module MortalKombat3
      # SNES memory addresses for Mortal Kombat 3.
      # All offsets are in the WRAM address space as seen by BizHawk.
      # These are the canonical addresses used by the Lua bridge.
      module MemoryMap
        # --- Game flow ---
        GAME_STATE_ADDR   = 0x0101  # 0 = menu, 1 = char select, 2 = fighting, 3 = round over
        ROUND_NUMBER_ADDR = 0x018A
        ROUND_TIMER_ADDR  = 0x01A0  # BCD encoded, 2 bytes

        # --- Player 1 ---
        P1_HEALTH_ADDR    = 0x011A  # current health
        P1_MAX_HEALTH     = 0x011C  # max health (usually 0x90 = 144)
        P1_X_ADDR         = 0x0120  # X position (2 bytes, big-endian)
        P1_Y_ADDR         = 0x0122  # Y position (2 bytes)
        P1_FACING_ADDR    = 0x0126  # 0 = right, 1 = left
        P1_ANIM_ADDR      = 0x012A  # current animation ID
        P1_ANIM_FRAME     = 0x012C  # frame within current animation
        P1_STATE_ADDR     = 0x0130  # bitfield: hitstun, blockstun, knockdown, airborne

        # --- Player 2 ---
        P2_HEALTH_ADDR    = 0x014A
        P2_MAX_HEALTH     = 0x014C
        P2_X_ADDR         = 0x0150
        P2_Y_ADDR         = 0x0152
        P2_FACING_ADDR    = 0x0156
        P2_ANIM_ADDR      = 0x015A
        P2_ANIM_FRAME     = 0x015C
        P2_STATE_ADDR     = 0x0160

        # --- State bitfield masks (P1_STATE_ADDR / P2_STATE_ADDR) ---
        STATE_HITSTUN   = 0x01
        STATE_BLOCKSTUN = 0x02
        STATE_KNOCKDOWN = 0x04
        STATE_AIRBORNE  = 0x08

        # --- Screen bounds (SNES pixels) ---
        X_MIN = 0
        X_MAX = 383
        Y_MIN = 0
        Y_MAX = 223

        # --- Max timer value (99 seconds in BCD) ---
        TIMER_MAX = 99

        def self.player_addresses(player_index)
          case player_index
          when 1
            {
              health:     P1_HEALTH_ADDR,
              max_health: P1_MAX_HEALTH,
              x:          P1_X_ADDR,
              y:          P1_Y_ADDR,
              facing:     P1_FACING_ADDR,
              anim:       P1_ANIM_ADDR,
              anim_frame: P1_ANIM_FRAME,
              state:      P1_STATE_ADDR
            }
          when 2
            {
              health:     P2_HEALTH_ADDR,
              max_health: P2_MAX_HEALTH,
              x:          P2_X_ADDR,
              y:          P2_Y_ADDR,
              facing:     P2_FACING_ADDR,
              anim:       P2_ANIM_ADDR,
              anim_frame: P2_ANIM_FRAME,
              state:      P2_STATE_ADDR
            }
          else
            raise ArgumentError, "player_index must be 1 or 2"
          end
        end
      end
    end
  end
end
