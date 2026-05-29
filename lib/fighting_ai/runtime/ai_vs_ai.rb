require_relative "match_runner"

module FightingAI
  module Runtime
    # Runs fully autonomous AI vs AI matches.
    # Supports self-play and cross-model evaluation.
    class AIVsAI
      def initialize(
        emulator_adapter:,
        game_adapter:,
        agent1:,
        agent2:,
        recorder: nil,
        logger: nil,
        reset_strategy: :load_save_state
      )
        @emulator       = emulator_adapter
        @game           = game_adapter
        @agents         = { 1 => agent1, 2 => agent2 }
        @recorder       = recorder
        @logger         = logger
        @reset_strategy = reset_strategy
      end

      # Run a series of autonomous matches.
      # Returns an array of completed Core::Match objects.
      def run_series(
        match_count:,
        player1_character: :random,
        player2_character: :random,
        game_definition: nil
      )
        @game.start_game
        matches = []

        match_count.times do |i|
          p1_char = resolve_character(player1_character, game_definition)
          p2_char = resolve_character(player2_character, game_definition)

          log "Starting match #{i + 1}/#{match_count}: #{p1_char} vs #{p2_char}"

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

          match = runner.run(player1_character: p1_char, player2_character: p2_char)
          matches << match

          @game.reset_for_next_match(strategy: @reset_strategy) if i < match_count - 1
        end

        matches
      end

      private

      def resolve_character(selection, game_definition)
        return @game.characters.keys.sample if selection == :random
        selection
      end

      def log(msg)
        if @logger
          @logger.call("[AIVsAI] #{msg}")
        else
          $stdout.puts "[AIVsAI] #{msg}"
        end
      end
    end
  end
end
