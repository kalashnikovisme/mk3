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
      RUNTIME_MS_KEY      = :runtime_ms
      FIGHT_LOG_MS_KEY    = :fight_log_ms
      TOTAL_MS_KEY        = :total_ms
      FIGHTER1_ACTION_KEY = :fighter1_action
      FIGHTER2_ACTION_KEY = :fighter2_action
      FIGHTER1_AREA_KEY   = :fighter1_area
      FIGHTER2_AREA_KEY   = :fighter2_area

      def initialize(path)
        FileUtils.mkdir_p(File.dirname(path))
        @file = File.open(path, "w")
        @file.sync = true
      end

      def log_frame(
        game_state,
        actions: {},
        areas: nil,
        capture_ms: nil,
        detect_ms: nil,
        runtime_ms: nil
      )
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @file.puts(format_frame(
          game_state,
          actions: actions,
          areas: areas,
          capture_ms: capture_ms,
          detect_ms: detect_ms,
          runtime_ms: runtime_ms
        ))
        fight_log_ms = elapsed_ms(started_at)
        parts = [capture_ms, detect_ms, runtime_ms, fight_log_ms].compact
        total_ms = parts.empty? ? nil : parts.sum
        @file.puts(FIELD_INDENT + format(FIELD_FORMAT, FIGHT_LOG_MS_KEY, fight_log_ms))
        @file.puts(FIELD_INDENT + format(FIELD_FORMAT, TOTAL_MS_KEY, total_ms)) unless total_ms.nil?
        @file.puts
      end

      def close
        @file.close
      end

      private

      def format_frame(gs, actions:, areas:, capture_ms:, detect_ms:, runtime_ms:)
        fields = {
          timer:      gs.round_time_remaining,
          health_1:   gs.fighter1.health,
          health_2:   gs.fighter2.health,
          fighter1_x: gs.fighter1.x,
          fighter1_y: gs.fighter1.y,
          fighter2_x: gs.fighter2.x,
          fighter2_y: gs.fighter2.y
        }
        fields[FIGHTER1_ACTION_KEY] = actions[1] if actions[1]
        fields[FIGHTER2_ACTION_KEY] = actions[2] if actions[2]
        if areas
          fields[FIGHTER1_AREA_KEY] = format_area(areas[0])
          fields[FIGHTER2_AREA_KEY] = format_area(areas[1])
        end
        fields[CAPTURE_MS_KEY]  = capture_ms unless capture_ms.nil?
        fields[DETECT_MS_KEY]   = detect_ms  unless detect_ms.nil?
        fields[RUNTIME_MS_KEY]  = runtime_ms unless runtime_ms.nil?

        lines = [FRAME_HEADER_PREFIX + gs.frame_number.to_s]
        fields.each { |name, value| lines << FIELD_INDENT + format(FIELD_FORMAT, name, value) }
        lines.join("\n")
      end

      def elapsed_ms(started_at)
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
        (elapsed * MS_PER_SECOND).round
      end

      def format_area(raw_area)
        return "full-screen" if raw_area.nil? || raw_area.empty?

        "#{raw_area.fetch("x")},#{raw_area.fetch("y")},#{raw_area.fetch("width")},#{raw_area.fetch("height")}"
      end
    end
  end
end
