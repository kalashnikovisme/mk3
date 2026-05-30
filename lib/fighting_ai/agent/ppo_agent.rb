require_relative "base"
require_relative "../game/side_normalizer"

module FightingAI
  module Agent
    # Self-play PPO agent backed by a shared Training::Policy.
    #
    # Both P1 and P2 point at the same Policy and TrajectoryBuffer so the
    # shared policy trains from the combined experience of both sides.
    #
    # SideNormalizer ensures the policy always receives a canonical left-side
    # view of the match so it never has to learn separate left/right behaviors.
    #
    # Frame skip: the policy is consulted once every FRAME_SKIP game frames.
    # Between decisions the same action is repeated and rewards are accumulated.
    # This makes each button press last long enough for the game engine to
    # register it, and reduces Python IPC overhead per second of play.
    #
    # Transition ordering (observe_reward is called before act each frame):
    #   Frame 0:              observe_reward(∅)  → no-op  |  act → new decision, start skip window
    #   Frames 1..SKIP-1:     observe_reward(r)  → accumulate  |  act → repeat cached action
    #   Frame SKIP:           observe_reward(r)  → window done → push accumulated transition  |  act → new decision
    class PPOAgent < Base
      FRAME_SKIP = 6

      attr_reader :episode_reward

      def initialize(player_index:, policy:, action_translator:, buffer:)
        super(player_index: player_index)
        @policy            = policy
        @action_translator = action_translator
        @buffer            = buffer
        @normalizer        = Game::SideNormalizer.new
        reset_state
      end

      def act(observation)
        if @frames_until_decision.zero?
          normalized = @normalizer.normalize(observation)
          obs_vector = normalized.to_vector
          result     = @policy.forward(obs_vector)

          @pending = {
            obs:      obs_vector,
            action:   result[:action_index],
            log_prob: result[:log_prob],
            value:    result[:value]
          }

          @current_action       = @action_translator.to_game_action(result[:action_index])
          @frames_until_decision = FRAME_SKIP
        end

        @frames_until_decision -= 1
        @current_action
      end

      # Called once per game frame (before act) with the reward for the
      # preceding transition. Rewards are summed across the frame-skip window;
      # the accumulated total is pushed when the window closes.
      def observe_reward(reward, done: false)
        @accumulated_reward += reward.to_f
        @episode_reward     += reward.to_f

        push_transition(done: done) if @pending && (@frames_until_decision.zero? || done)
      end

      def on_match_start(match)
        reset_state
      end

      def on_match_end(match, result)
        push_transition(done: true) if @pending
        @episode_reward = 0.0
      end

      private

      def push_transition(done:)
        @buffer.push(**@pending, reward: @accumulated_reward, done: done)
        @accumulated_reward = 0.0
        @pending            = nil
      end

      def reset_state
        @pending               = nil
        @current_action        = Core::Action::IDLE
        @frames_until_decision = 0
        @accumulated_reward    = 0.0
        @episode_reward        = 0.0
      end
    end
  end
end
