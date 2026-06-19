require "fileutils"

module FightingAI
  module Training
    class FightLogger
      def initialize(path)
        FileUtils.mkdir_p(File.dirname(path))
        @file = File.open(path, "w")
        @file.sync = true
      end

      def log_frame(game_state)
        @file.puts format_frame(game_state)
      end

      def close
        @file.close
      end

      private

      def format_frame(gs)
        "f: #{gs.frame_number}; t: #{gs.round_time_remaining}; " \
        "h1: #{gs.fighter1.health}; h2: #{gs.fighter2.health}; " \
        "x1: #{gs.fighter1.x}; x2: #{gs.fighter2.x}"
      end
    end
  end
end
