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
      SNAPSHOT_MS_KEY     = :snapshot_ms
      AGENTS_MS_KEY       = :agents_ms
      RUNTIME_MS_KEY      = :runtime_ms
      FIGHT_LOG_MS_KEY    = :fight_log_ms
      TOTAL_MS_KEY        = :total_ms

      def initialize(path)
        FileUtils.mkdir_p(File.dirname(path))
        @file = File.open(path, "w")
        @file.sync = true
      end

      def log_frame(
        game_state,
        snapshot_ms: nil,
        capture_ms: nil,
        detect_ms: nil,
        agents_ms: nil,
        runtime_ms: nil,
        work_ms: nil
      )
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @file.puts(format_frame(
          game_state,
          snapshot_ms: snapshot_ms,
          capture_ms: capture_ms,
          detect_ms: detect_ms,
          agents_ms: agents_ms,
          runtime_ms: runtime_ms
        ))
        fight_log_ms = elapsed_ms(started_at)
        total_ms = work_ms.nil? ? nil : work_ms + fight_log_ms
        @file.puts(FIELD_INDENT + format(FIELD_FORMAT, FIGHT_LOG_MS_KEY, fight_log_ms))
        @file.puts(FIELD_INDENT + format(FIELD_FORMAT, TOTAL_MS_KEY, total_ms)) unless total_ms.nil?
        @file.puts
      end

      def close
        @file.close
      end

      private

      def format_frame(gs, snapshot_ms:, capture_ms:, detect_ms:, agents_ms:, runtime_ms:)
        fields = {
          timer:      gs.round_time_remaining,
          health_1:   gs.fighter1.health,
          health_2:   gs.fighter2.health,
          fighter1_x: gs.fighter1.x,
          fighter1_y: gs.fighter1.y,
          fighter2_x: gs.fighter2.x,
          fighter2_y: gs.fighter2.y
        }
        fields[SNAPSHOT_MS_KEY] = snapshot_ms unless snapshot_ms.nil?
        fields[CAPTURE_MS_KEY]  = capture_ms unless capture_ms.nil?
        fields[DETECT_MS_KEY]   = detect_ms  unless detect_ms.nil?
        fields[AGENTS_MS_KEY]   = agents_ms  unless agents_ms.nil?
        fields[RUNTIME_MS_KEY]  = runtime_ms unless runtime_ms.nil?

        lines = [FRAME_HEADER_PREFIX + gs.frame_number.to_s]
        fields.each { |name, value| lines << FIELD_INDENT + format(FIELD_FORMAT, name, value) }
        lines.join("\n")
      end

      def elapsed_ms(started_at)
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
        (elapsed * MS_PER_SECOND).round
      end
    end
  end
end
