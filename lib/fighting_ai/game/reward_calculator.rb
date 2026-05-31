module FightingAI
  module Game
    # Reward weights for PPO self-play training.
    # Combat reward shaping: damage, round outcomes, and proximity.
    module RewardCalculator
      DAMAGE_DEALT_WEIGHT =  10
      DAMAGE_TAKEN_WEIGHT =  -5
      WIN_REWARD          =  200.0
      LOSS_REWARD         =  -200.0
      DRAW_REWARD         =  -100.0
      STALE_REWARD        = -100.0
      # Per-frame weight for proximity shaping.
      # +DISTANCE_WEIGHT when fighters are adjacent, -DISTANCE_WEIGHT at maximum separation.
      DISTANCE_WEIGHT     =  1

      def self.weights
        {
          damage_dealt: DAMAGE_DEALT_WEIGHT,
          damage_taken: DAMAGE_TAKEN_WEIGHT,
          round_win:    WIN_REWARD,
          round_loss:   LOSS_REWARD,
          round_draw:   DRAW_REWARD,
          stale:        STALE_REWARD,
          distance:     DISTANCE_WEIGHT
        }
      end
    end
  end
end
