require_relative "provider"

module FightingAI
  module Observation
    # Provides structured game-state observations for RL agents.
    # Wraps the game adapter's observation space without coupling agents to
    # the game layer directly.
    #
    # The API is intentionally narrow: swap this for FrameObservationProvider
    # or HybridObservationProvider later without changing agents or trainers.
    class StructuredObservationProvider
      def initialize(game_adapter:, player_index:)
        @game_adapter = game_adapter
        @player_index = player_index
      end

      def capture(game_state)
        @game_adapter.build_observation(game_state, player_index: @player_index)
      end
    end
  end
end
