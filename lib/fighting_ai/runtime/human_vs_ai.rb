require_relative "match_runner"
require_relative "../agent/base"

module FightingAI
  module Runtime
    # Runs a Human vs AI session.
    # The human side is represented by a PassthroughAgent that forwards
    # real controller inputs from the emulator (the human presses buttons
    # on the physical controller; BizHawk passes them through normally).
    # The AI agent controls the other side.
    class HumanVsAI
      # For the human player we do NOT inject inputs — the physical controller
      # handles it. We still need to send a noop so the bridge loop advances.
      class HumanPassthrough < Agent::Base
        def act(_observation)
          Core::Action::IDLE  # results in no injected input
        end
      end

      def initialize(
        emulator_adapter:,
        game_adapter:,
        ai_agent:,
        human_player: 1,
        recorder: nil,
        logger: nil
      )
        @emulator     = emulator_adapter
        @game         = game_adapter
        @ai_agent     = ai_agent
        @human_player = human_player
        @recorder     = recorder
        @logger       = logger

        ai_player = human_player == 1 ? 2 : 1
        @ai_agent = ai_agent
        @ai_agent.instance_variable_set(:@player_index, ai_player) if ai_agent.player_index != ai_player

        @agents = {
          human_player => HumanPassthrough.new(player_index: human_player),
          ai_player    => ai_agent
        }
      end

      def run(player1_character:, player2_character:, setup: nil)
        run_lifecycle(player1_character, player2_character)
      end

      private

      def run_lifecycle(p1_char, p2_char)
        @game.start_game
        @game.open_player_vs_player_mode
        @game.select_characters(player1_character: p1_char, player2_character: p2_char)
        @game.wait_for_fight_start

        runner = MatchRunner.new(
          emulator_adapter: @emulator,
          game_adapter:     @game,
          agents:           @agents,
          recorder:         @recorder,
          logger:           @logger
        )

        runner.run(player1_character: p1_char, player2_character: p2_char)
      end
    end
  end
end
