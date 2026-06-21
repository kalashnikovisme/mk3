require "fileutils"

module FightingAI
  module Training
    class FightLogger
      FRAME_HEADER_PREFIX = "frame: "
      FIELD_INDENT        = "  "
      FIELD_FORMAT        = "%s: %s"
      MS_PER_SECOND       = 1000
      CAPTURE_MS_KEY      = :capture_ms
      DETECT_MS_KEY       = :detect_ms
      TOTAL_MS_KEY        = :total_ms

      def initialize(path)
        FileUtils.mkdir_p(File.dirname(path))
        @file = File.open(path, "w")
        @file.sync = true
      end

      def log_frame(game_state, capture_ms: nil, detect_ms: nil, total_ms: nil)
        @file.puts(format_frame(game_state, capture_ms: capture_ms, detect_ms: detect_ms, total_ms: total_ms))
      end

      def close
        @file.close
      end

      private

      def format_frame(gs, capture_ms:, detect_ms:, total_ms:)
        fields = {
          timer:      gs.round_time_remaining,
          health_1:   gs.fighter1.health,
          health_2:   gs.fighter2.health,
          fighter1_x: gs.fighter1.x,
          fighter1_y: gs.fighter1.y,
          fighter2_x: gs.fighter2.x,
          fighter2_y: gs.fighter2.y
        }
        fields[CAPTURE_MS_KEY] = capture_ms unless capture_ms.nil?
        fields[DETECT_MS_KEY]  = detect_ms  unless detect_ms.nil?
        fields[TOTAL_MS_KEY]   = total_ms   unless total_ms.nil?

        lines = [FRAME_HEADER_PREFIX + gs.frame_number.to_s]
        fields.each { |name, value| lines << FIELD_INDENT + format(FIELD_FORMAT, name, value) }
        lines << ""
        lines.join("\n")
      end
    end
  end
end
