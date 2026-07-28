require_relative "../../core/reward"
require_relative "../reward_calculator"
require_relative "memory_map"

module FightingAI
  module Game
    module MortalKombat3
      class RewardFunction
        DISTANCE_REWARD_FLOOR = 0.0
        DISTANCE_REWARD_CEILING = 1.0
        TOO_CLOSE_DISTANCE = 60.0
        PREFERRED_RANGE_MIN_DISTANCE = 70.0
        PREFERRED_RANGE_MAX_DISTANCE = 120.0
        APPROACH_RANGE_START_DISTANCE = 140.0

        def initialize(weights: nil)
          @weights = RewardCalculator.weights.merge(weights || {})
        end

        # Calculate reward for player_index between two consecutive game states.
        def call(prev_state, next_state, player_index:, stale: false, round_over: false)
          me_prev  = prev_state.fighter_for(player_index)
          me_next  = next_state.fighter_for(player_index)
          opp_prev = prev_state.opponent_of(player_index)
          opp_next = next_state.opponent_of(player_index)

          damage_dealt = [opp_prev.health - opp_next.health, 0].max.to_f
          damage_taken = [me_prev.health  - me_next.health,  0].max.to_f

          components = {
            damage_dealt:      damage_dealt * @weights[:damage_dealt],
            damage_taken:      damage_taken * @weights[:damage_taken],
            close_range:       close_range_reward(me_next, opp_next),
            approach:          approach_reward(me_prev, opp_prev, me_next, opp_next),
            distance_reset:    distance_reset_reward(me_prev, opp_prev, me_next, opp_next)
          }

          if stale
            components[:stale] = @weights[:stale]
          elsif next_state.round_over? || round_over
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

        def close_range_reward(me, opponent)
          distance = clamped_distance(me, opponent)
          return DISTANCE_REWARD_FLOOR unless preferred_range?(distance)

          preferred_range_ratio(distance) * @weights[:close_range]
        end

        def approach_reward(me_prev, opp_prev, me_next, opp_next)
          prev_distance = clamped_distance(me_prev, opp_prev)
          next_distance = clamped_distance(me_next, opp_next)
          return DISTANCE_REWARD_FLOOR unless far_range?(prev_distance)

          closing_delta = [prev_distance - next_distance, DISTANCE_REWARD_FLOOR].max
          (closing_delta / MemoryMap::MAX_FIGHT_DISTANCE.to_f) * @weights[:approach]
        end

        def distance_reset_reward(me_prev, opp_prev, me_next, opp_next)
          prev_distance = clamped_distance(me_prev, opp_prev)
          next_distance = clamped_distance(me_next, opp_next)
          return DISTANCE_REWARD_FLOOR unless too_close_range?(prev_distance)

          opening_delta = [next_distance - prev_distance, DISTANCE_REWARD_FLOOR].max
          (opening_delta / MemoryMap::MAX_FIGHT_DISTANCE.to_f) * @weights[:distance_reset]
        end

        def preferred_range_ratio(distance)
          range_width = PREFERRED_RANGE_MAX_DISTANCE - PREFERRED_RANGE_MIN_DISTANCE
          range_midpoint = PREFERRED_RANGE_MIN_DISTANCE + (range_width / 2.0)
          distance_from_midpoint = (distance - range_midpoint).abs
          raw_ratio = 1.0 - (distance_from_midpoint / (range_width / 2.0))
          [[raw_ratio, DISTANCE_REWARD_FLOOR].max, DISTANCE_REWARD_CEILING].min
        end

        def preferred_range?(distance)
          distance >= PREFERRED_RANGE_MIN_DISTANCE && distance <= PREFERRED_RANGE_MAX_DISTANCE
        end

        def far_range?(distance)
          distance >= APPROACH_RANGE_START_DISTANCE
        end

        def too_close_range?(distance)
          distance <= TOO_CLOSE_DISTANCE
        end

        def clamped_distance(me, opponent)
          [me.distance_to(opponent), MemoryMap::MAX_FIGHT_DISTANCE].min.to_f
        end

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
