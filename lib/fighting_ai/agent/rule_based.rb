require_relative "base"
require_relative "../core/action"

module FightingAI
  module Agent
    # A deterministic rule-based agent for MK3.
    # Decision tree operates purely on normalized Observation fields;
    # no game-specific constants or memory addresses are used here.
    #
    # Strategy:
    #   - If close: combo attacks
    #   - If medium range: walk forward + attack
    #   - If far: walk forward
    #   - If health low and opponent is close: block
    class RuleBased < Base
      CLOSE_DISTANCE  = 0.15
      MEDIUM_DISTANCE = 0.35
      LOW_HEALTH      = 0.30

      def act(observation)
        distance   = (observation.my_x_normalized - observation.opponent_x_normalized).abs
        my_health  = observation.my_health_pct
        action_name = choose_action(distance, my_health, observation.frame_number)
        Core::Action.named(action_name)
      end

      private

      def choose_action(distance, my_health, frame_number)
        return :block if my_health < LOW_HEALTH && distance < CLOSE_DISTANCE

        case distance
        when 0..CLOSE_DISTANCE
          close_range_action(frame_number)
        when CLOSE_DISTANCE..MEDIUM_DISTANCE
          frame_number.even? ? :walk_forward : :high_punch
        else
          :walk_forward
        end
      end

      def close_range_action(frame_number)
        case frame_number % 4
        when 0 then :high_punch
        when 1 then :low_kick
        when 2 then :high_kick
        when 3 then :low_punch
        end
      end
    end
  end
end
