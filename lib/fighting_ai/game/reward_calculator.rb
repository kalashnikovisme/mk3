module FightingAI
  module Game
    module RewardCalculator
      def self.weights
        config = FightingAI.config
        {
          damage_dealt: config.reward_damage_dealt,
          damage_taken: config.reward_damage_taken,
          distance:     config.reward_distance,
          round_win:    config.reward_win,
          round_loss:   config.reward_loss,
          round_draw:   config.reward_draw,
          stale:        config.reward_stale
        }
      end
    end
  end
end
