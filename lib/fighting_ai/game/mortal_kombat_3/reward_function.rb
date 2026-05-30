require_relative "../../core/reward"
require_relative "../reward_calculator"

module FightingAI
  module Game
    module MortalKombat3
      class RewardFunction
        DEFAULT_WEIGHTS = {
          damage_dealt: RewardCalculator::DAMAGE_DEALT_WEIGHT,
          damage_taken: RewardCalculator::DAMAGE_TAKEN_WEIGHT,
          round_win:    RewardCalculator::WIN_REWARD,
          round_loss:   RewardCalculator::LOSS_REWARD,
          round_draw:   RewardCalculator::DRAW_REWARD,
          stale:        RewardCalculator::STALE_REWARD
        }.freeze

        def initialize(weights: DEFAULT_WEIGHTS)
          @weights = DEFAULT_WEIGHTS.merge(weights)
        end

        # Calculate reward for player_index between two consecutive game states.
        def call(prev_state, next_state, player_index:, stale: false)
          me_prev  = prev_state.fighter_for(player_index)
          me_next  = next_state.fighter_for(player_index)
          opp_prev = prev_state.opponent_of(player_index)
          opp_next = next_state.opponent_of(player_index)

          damage_dealt = [opp_prev.health - opp_next.health, 0].max.to_f
          damage_taken = [me_prev.health  - me_next.health,  0].max.to_f

          components = {
            damage_dealt: damage_dealt * @weights[:damage_dealt],
            damage_taken: damage_taken * @weights[:damage_taken]
          }

          if stale
            components[:stale] = @weights[:stale]
          elsif next_state.round_over?
            round_winner = determine_round_winner(next_state)
            if round_winner == player_index
              components[:round_win] = @weights[:round_win]
            elsif round_winner.nil?
              return Core::Reward.compose(round_draw: @weights[:round_draw])
            else
              components[:round_loss] = @weights[:round_loss]
            end
          end

          Core::Reward.compose(**components)
        end

        private

        def determine_round_winner(game_state)
          h1 = game_state.fighter1.health
          h2 = game_state.fighter2.health
          return 1 if h1 > h2
          return 2 if h2 > h1
          nil # draw
        end

      end
    end
  end
end
