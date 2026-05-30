module FightingAI
  module Game
    # Reward weights for PPO self-play training.
    # Combat-only reward shaping: damage and round outcomes.
    # No movement or positioning rewards.
    module RewardCalculator
      DAMAGE_DEALT_WEIGHT =  0.5
      DAMAGE_TAKEN_WEIGHT = -0.1
      WIN_REWARD          =  20.0
      LOSS_REWARD         = -10.0
      DRAW_REWARD         = -20.0
      STALE_REWARD        = -10.0

      def self.weights
        {
          damage_dealt: DAMAGE_DEALT_WEIGHT,
          damage_taken: DAMAGE_TAKEN_WEIGHT,
          round_win:    WIN_REWARD,
          round_loss:   LOSS_REWARD,
          round_draw:   DRAW_REWARD,
          stale:        STALE_REWARD
        }
      end
    end
  end
end
