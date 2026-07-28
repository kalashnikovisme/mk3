require "colorize"
require "io/console"
require "json"

module FightingAI
  module CLI
    class PPODisplay
      BAR_WIDTH      = 16
      MAX_HEALTH     = 0xA6  # 166
      P1_COL_WIDTH   = 55    # visible chars reserved for the P1 reward column
      SCREEN_TRACK_WIDTH = 32
      STATUS_AREA_LINE_COUNT = 2
      SCREEN_LEFT_BOUNDARY = '|'.freeze
      SCREEN_RIGHT_BOUNDARY = '|'.freeze
      SCREEN_EMPTY_CELL = '-'.freeze
      SCREEN_LEFT_CHARACTER_DOT = '●'.freeze
      SCREEN_RIGHT_CHARACTER_DOT = '●'.freeze
      SCREEN_OVERLAP_DOT = '●'.freeze
      POSITION_MIN = 0
      POSITION_MAX = FightingAI::Game::MortalKombat3::MemoryMap::X_MAX
      TRACK_LAST_INDEX = SCREEN_TRACK_WIDTH - 1
      DEFAULT_TERMINAL_WIDTH = 120
      MIN_TERMINAL_WIDTH = 20
      TERMINAL_WIDTH_PADDING = 1
      ANSI_ESCAPE_PATTERN = /\e\[[0-9;]*m/
      ANSI_RESET = "\e[0m"

      COMPONENT_LABELS = {
        damage_dealt:      "dmg",
        damage_taken:      "tkn",
        close_range:       "rng",
        approach:          "app",
        distance_reset:    "rst",
        distance_escape:   "esc",
        too_close:         "cls",
        round_win:         "win",
        round_loss:        "loss",
        round_draw:        "draw",
        stale:             "stl"
      }.freeze

      attr_writer :log_file

      def initialize
        @episode       = 0
        @training_step = 0
        @buffer_size   = 0
        @buffer_cap    = 512
        @last_status   = ""
        @last_status_lines = []
        @log_file      = nil
      end

      def set_context(episode:, training_step:, buffer_size:, buffer_capacity:)
        @episode       = episode
        @training_step = training_step
        @buffer_size   = buffer_size
        @buffer_cap    = buffer_capacity
      end

      def update(game_state:, stage_name: nil, watches: [])
        f1    = game_state.fighter1
        f2    = game_state.fighter2
        timer = game_state.round_time_remaining

        state_tag =
          if game_state.fight_active? then "fight".green
          elsif game_state.round_over? then "over".yellow
          else "idle".light_black
          end

        buf_str = "#{@buffer_size}/#{@buffer_cap}"
        buf     = @buffer_size >= @buffer_cap ? buf_str.green : buf_str.yellow

        status_line =
          "Ep #{@episode.to_s.rjust(4)} ".cyan +
          (stage_name ? "│ #{stage_name} ".light_black : "") +
          "│ t:#{timer.to_s.rjust(2)} ".white +
          "│ P1 #{health_bar(f1.health).green} #{f1.health.to_s.rjust(3)} x:#{f1.x.to_s.rjust(3)} " +
          "│ P2 #{health_bar(f2.health).red} #{f2.health.to_s.rjust(3)} x:#{f2.x.to_s.rjust(3)} " +
          "│ [#{state_tag}] " +
          "│ buf #{buf}"

        unless watches.empty?
          watch_str = watches.map { |w| "#{w[:label]}:#{w[:value].to_s.rjust(3)}" }.join("  ")
          status_line += " │ #{watch_str}".yellow
        end

        position_line = "│ screen #{screen_track(f1.x, f2.x)}"
        render_status_area([status_line, position_line], replace_previous: !@last_status_lines.empty?)
        @last_status_lines = [status_line, position_line].map { |line| fit_to_terminal_width(line) }
        @last_status = @last_status_lines.join("\n")

        return unless @log_file

        @last_status_lines.each { |line| @log_file.puts line.gsub(ANSI_ESCAPE_PATTERN, "") }
        @log_file.flush
      end

      def episode_done(episode:, winner:, stale: false, p1_reward:, p2_reward:, p1_components: {}, p2_components: {})
        out_plain = stale ? "Stale  " : (winner ? "P#{winner} wins" : "Draw   ")
        out_color = stale ? out_plain.red : (winner ? out_plain.green : out_plain.yellow)

        p1_str = "P1 #{fmt_reward(p1_reward)} #{fmt_components(p1_components)}"
        p2_str = "P2 #{fmt_reward(p2_reward)} #{fmt_components(p2_components)}"

        line = "✓ Ep #{episode.to_s.rjust(4)}".cyan +
               "  #{out_color}  " +
               pad_col(p1_str, P1_COL_WIDTH) +
               "  " + p2_str

        event(line)
      end

      def ppo_update(step:, stats:, n:)
        line =
          "⚡ PPO ##{step}".cyan +
          "  pol #{stats[:policy_loss].to_f.round(4)}".light_blue +
          "  val #{stats[:value_loss].to_f.round(4)}".light_blue +
          "  ent #{stats[:entropy].to_f.round(4)}".light_blue +
          "  n=#{n}".light_black
        event(line)
      end

      def checkpoint(path)
        event "💾 #{File.basename(path)}".yellow
      end

      def log(message)
        event message
      end

      private

      def health_bar(hp)
        filled = [(hp.to_f / MAX_HEALTH * BAR_WIDTH).round, BAR_WIDTH].min
        "█" * filled + "░" * (BAR_WIDTH - filled)
      end

      def screen_track(p1_x, p2_x)
        cells = Array.new(SCREEN_TRACK_WIDTH, SCREEN_EMPTY_CELL)
        left_x, right_x = [p1_x, p2_x].sort
        left_index = screen_track_index(left_x)
        right_index = screen_track_index(right_x)

        if left_index == right_index
          cells[left_index] = SCREEN_OVERLAP_DOT.magenta
        else
          cells[left_index] = SCREEN_LEFT_CHARACTER_DOT.blue
          cells[right_index] = SCREEN_RIGHT_CHARACTER_DOT.red
        end

        "#{SCREEN_LEFT_BOUNDARY}#{cells.join}#{SCREEN_RIGHT_BOUNDARY}"
      end

      def screen_track_index(position_x)
        clamped_x = [[position_x.to_i, POSITION_MIN].max, POSITION_MAX].min
        (clamped_x.to_f * TRACK_LAST_INDEX / POSITION_MAX).round
      end

      def pad_col(str, width)
        visible = visible_length(str)
        str + " " * [width - visible, 0].max
      end

      def fit_to_terminal_width(line)
        max_visible_width = [terminal_width - TERMINAL_WIDTH_PADDING, MIN_TERMINAL_WIDTH].max
        return line if visible_length(line) <= max_visible_width

        truncate_ansi(line, max_visible_width)
      end

      def terminal_width
        width = $stdout.winsize.fetch(1, DEFAULT_TERMINAL_WIDTH)
        width.positive? ? width : DEFAULT_TERMINAL_WIDTH
      rescue SystemCallError, IOError
        DEFAULT_TERMINAL_WIDTH
      end

      def visible_length(str)
        str.gsub(ANSI_ESCAPE_PATTERN, '').length
      end

      def truncate_ansi(str, max_visible_width)
        visible = 0
        output = +""
        index = 0

        while index < str.length && visible < max_visible_width
          escape = str[index..].match(/\A\e\[[0-9;]*m/)
          if escape
            output << escape[0]
            index += escape[0].length
          else
            output << str[index]
            visible += 1
            index += 1
          end
        end

        output.include?("\e[") ? "#{output}#{ANSI_RESET}" : output
      end

      def fmt_reward(r)
        s = format("%+7.2f", r)
        r >= 0 ? s.green : s.red
      end

      def fmt_components(components)
        parts = COMPONENT_LABELS.filter_map do |key, label|
          val = components[key]
          next if val.nil? || val.zero?
          s = format("%+.0f", val)
          "#{label}:#{val >= 0 ? s.green : s.red}"
        end
        parts.empty? ? "" : "[#{parts.join(' ')}]"
      end

      def event(*lines)
        body = lines.map.with_index do |line, index|
          rendered_line = fit_to_terminal_width(line)
          index.zero? ? "\r\e[2K#{rendered_line}" : "\n\e[2K#{rendered_line}"
        end.join
        $stdout.print "#{body}\n\r\e[2K"
        render_status_area(@last_status_lines, replace_previous: false) unless @last_status_lines.empty?
        $stdout.flush
        if @log_file
          lines.each { |l| @log_file.puts l.gsub(ANSI_ESCAPE_PATTERN, "") }
          @log_file.flush
        end
      end

      def render_status_area(lines, replace_previous:)
        rendered_lines = lines.map { |line| fit_to_terminal_width(line) }
        output = +""

        if replace_previous
          output << "\r\e[2K"
          output << "\e[1A\r\e[2K" if STATUS_AREA_LINE_COUNT > 1
        end

        output << rendered_lines[0]
        output << "\n\e[2K#{rendered_lines[1]}"
        $stdout.print(output)
        $stdout.flush
      end
    end

    # Machine-readable display for AI-driven log analysis.
    # Emits one JSON line per event; suppresses the live status bar entirely.
    class PPOAIDisplay
      COMPONENT_KEYS = %i[damage_dealt damage_taken close_range approach distance_reset distance_escape too_close round_win round_loss round_draw stale].freeze

      attr_writer :log_file

      def initialize
        @log_file = nil
      end

      def set_context(episode:, training_step:, buffer_size:, buffer_capacity:) = nil

      def update(game_state:, stage_name:, **) = nil

      def episode_done(episode:, winner:, stale: false, p1_reward:, p2_reward:, p1_components: {}, p2_components: {})
        emit(
          type:          "episode",
          episode:       episode,
          winner:        winner,
          stale:         stale,
          p1_reward:     p1_reward.round(4),
          p2_reward:     p2_reward.round(4),
          p1_components: normalize_components(p1_components),
          p2_components: normalize_components(p2_components)
        )
      end

      def ppo_update(step:, stats:, n:)
        emit(
          type:        "ppo_update",
          step:        step,
          n:           n,
          policy_loss: stats[:policy_loss].to_f.round(6),
          value_loss:  stats[:value_loss].to_f.round(6),
          entropy:     stats[:entropy].to_f.round(6),
          total_loss:  stats[:total_loss].to_f.round(6)
        )
      end

      def checkpoint(path)
        emit(type: "checkpoint", path: File.basename(path))
      end

      def log(message)
        emit(type: "log", message: message)
      end

      private

      def normalize_components(components)
        COMPONENT_KEYS.each_with_object({}) do |key, h|
          h[key] = (components[key] || 0.0).round(4)
        end
      end

      def emit(payload)
        line = JSON.generate(payload)
        $stdout.puts line
        $stdout.flush
        return unless @log_file

        @log_file.puts line
        @log_file.flush
      end
    end
  end
end
