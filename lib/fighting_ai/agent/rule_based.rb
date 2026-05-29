require_relative "base"
require_relative "../core/action"

module FightingAI
  module Agent
    # A deterministic rule-based agent for MK3.
    # Decision tree operates purely on normalized Observation fields;
    # no game-specific constants or memory addresses are used here.
    #
    # Strategy:
    #   - If opponent is stunned/knocked down: attack
    #   - If close: combo attacks
    #   - If medium range: walk forward + attack
    #   - If far: walk forward
    #   - If health low and opponent close: block
    class RuleBased < Base
      CLOSE_DISTANCE  = 0.15
      MEDIUM_DISTANCE = 0.35
      LOW_HEALTH      = 0.30

      def act(observation)
        distance = observation.distance_normalized
        my_health = observation.my_health_pct
        opp_stunned = observation.opponent_in_hitstun || observation.opponent_knocked_down

        action_name = choose_action(distance, my_health, opp_stunned, observation)
        Core::Action.named(action_name)
      end

      private

      def choose_action(distance, my_health, opp_stunned, obs)
        # Punish stunned opponents immediately
        return punish_action(distance) if opp_stunned

        # Defensive when low health and opponent is close
        return :block if my_health < LOW_HEALTH && distance < CLOSE_DISTANCE

        # Don't act when in hitstun or blockstun ourselves
        return :idle if obs.my_in_hitstun || obs.my_in_blockstun

        case distance
        when 0..CLOSE_DISTANCE
          close_range_action(obs)
        when CLOSE_DISTANCE..MEDIUM_DISTANCE
          mid_range_action(obs)
        else
          :walk_forward
        end
      end

      def close_range_action(obs)
        # Alternate between punches and kicks for a simple combo
        frame = obs.frame_number
        case frame % 4
        when 0 then :high_punch
        when 1 then :low_kick
        when 2 then :high_kick
        when 3 then :low_punch
        end
      end

      def mid_range_action(obs)
        frame = obs.frame_number
        frame.even? ? :walk_forward : :high_punch
      end

      def punish_action(distance)
        distance < CLOSE_DISTANCE ? :high_punch : :walk_forward
      end
    end
  end
end
