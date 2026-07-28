require "anyway_config"

module FightingAI
  class Config < Anyway::Config
    config_name :fighting_ai

      attr_config(
        stale_timeout:                  8.0,
        stale_distance_reset_threshold: 6.0,
        reward_damage_dealt:            10.0,
        reward_damage_taken:           -5.0,
        reward_close_range:             2.0,
        reward_approach:               14.0,
        reward_distance_reset:         20.0,
        reward_distance_escape:        16.0,
        reward_too_close:              -8.0,
        reward_win:                   200.0,
        reward_loss:                 -200.0,
        reward_draw:                 -100.0,
        reward_stale:                 -25.0
      )
  end
end
