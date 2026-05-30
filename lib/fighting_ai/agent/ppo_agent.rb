require_relative "base"
require_relative "../game/side_normalizer"

module FightingAI
  module Agent
    # Self-play PPO agent backed by a shared Training::Policy.
    #
    # Both P1 and P2 are instances of this class pointing at the same Policy
    # and TrajectoryBuffer. The shared policy trains from the combined experience
    # of both sides.
    #
    # SideNormalizer ensures the policy always receives a canonical left-side view
    # of the match so it never has to learn separate left/right behaviors.
    #
    # Transition storage follows the standard RL ordering:
    #   act(obs_t)            → stores pending (obs_t, action_t, log_prob_t, value_t)
    #   observe_reward(r_t)   → completes pending with reward, pushes to buffer
    class PPOAgent < Base
      attr_reader :episode_reward

      def initialize(player_index:, policy:, action_translator:, buffer:)
        super(player_index: player_index)
        @policy            = policy
        @action_translator = action_translator
        @buffer            = buffer
        @normalizer        = Game::SideNormalizer.new
        @pending           = nil
        @episode_reward    = 0.0
      end

      def act(observation)
        normalized = @normalizer.normalize(observation)
        obs_vector = normalized.to_vector
        result     = @policy.forward(obs_vector)

        @pending = {
          obs:      obs_vector,
          action:   result[:action_index],
          log_prob: result[:log_prob],
          value:    result[:value]
        }

        @action_translator.to_game_action(result[:action_index])
      end

      def observe_reward(reward, done: false)
        return unless @pending

        @episode_reward += reward.to_f
        @buffer.push(**@pending, reward: reward.to_f, done: done)
        @pending = nil
      end

      def on_match_start(match)
        @episode_reward = 0.0
        @pending        = nil
      end

      def on_match_end(match, result)
        # Safety flush: push any pending step that never received its reward.
        # Under normal operation this should not happen because MatchRunner
        # calls notify_agents_terminal_reward before finishing the last round.
        if @pending
          @buffer.push(**@pending, reward: 0.0, done: true)
          @pending = nil
        end
        @episode_reward = 0.0
      end
    end
  end
end
