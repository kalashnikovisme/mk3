module FightingAI
  module Game
    # Reward weights for PPO self-play training.
    # Combat reward shaping: damage, distance control, and round outcomes.
    module RewardCalculator
      DAMAGE_DEALT_WEIGHT =  10
      DAMAGE_TAKEN_WEIGHT =  -5
      DISTANCE_WEIGHT     =  25.0
      WIN_REWARD          =  200.0
      LOSS_REWARD         =  -200.0
      DRAW_REWARD         =  -100.0
      STALE_REWARD        = -100.0

      def self.weights
        {
          damage_dealt: DAMAGE_DEALT_WEIGHT,
          damage_taken: DAMAGE_TAKEN_WEIGHT,
          distance:     DISTANCE_WEIGHT,
          round_win:    WIN_REWARD,
          round_loss:   LOSS_REWARD,
          round_draw:   DRAW_REWARD,
          stale:        STALE_REWARD
        }
      end
    end
  end
end
