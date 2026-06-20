module FightingAI
  module Game
    module MortalKombat3
      module MemoryMap
        # --- Health constant ---
        MAX_HEALTH = 0xA6  # 166 — same for both players

        # --- Normalization ranges ---
        TIMER_MAX          = 99    # MK3 round timer counts down from 99
        X_MAX              = 255   # coordinate range (vision-scaled)
        Y_MAX              = 255   # coordinate range (vision-scaled)
        MAX_FIGHT_DISTANCE = X_MAX # maximum possible distance between fighters
      end
    end
  end
end
