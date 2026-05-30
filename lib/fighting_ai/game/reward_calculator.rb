module FightingAI
  module Game
    # Reward weights for PPO self-play training.
    # Combat-only reward shaping: damage and round outcomes.
    # No movement or positioning rewards.
    module RewardCalculator
      DAMAGE_DEALT_WEIGHT =  0.05
      DAMAGE_TAKEN_WEIGHT = -0.05
      WIN_REWARD          =  10.0
      LOSS_REWARD         = -10.0

      def self.weights
        {
          damage_dealt: DAMAGE_DEALT_WEIGHT,
          damage_taken: DAMAGE_TAKEN_WEIGHT,
          round_win:    WIN_REWARD,
          round_loss:   LOSS_REWARD
        }
      end
    end
  end
end
