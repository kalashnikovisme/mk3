require "colorize"
require "io/console"
require "json"
require "unicode/display_width"
require_relative "../emulator/retro_arch/config_builder"
require_relative "reconstructed_scene_window"

module FightingAI
  module CLI
    class PPODisplay
      BAR_WIDTH      = 16
      MAX_HEALTH     = 0xA6  # 166
      P1_COL_WIDTH   = 55    # visible chars reserved for the P1 reward column
      SCREEN_TRACK_WIDTH = 32
      STATUS_AREA_LINE_COUNT = 4
      POSITION_CHART_LABEL_WIDTH = 4
      POSITION_COORD_DIGITS = 3
      RECONSTRUCTED_SCENE_WIDTH = FightingAI::Emulator::RetroArch::ConfigBuilder::RETROARCH_WINDOW_WIDTH
      RECONSTRUCTED_SCENE_HEIGHT = FightingAI::Emulator::RetroArch::ConfigBuilder::RETROARCH_WINDOW_HEIGHT
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

      def initialize(scene_window: nil)
        @episode       = 0
        @training_step = 0
        @buffer_size   = 0
        @buffer_cap    = 512
        @last_status   = ""
        @last_status_lines = []
        @log_file      = nil
        @scene_window  = scene_window || build_scene_window
      end

      def set_context(episode:, training_step:, buffer_size:, buffer_capacity:)
        @episode       = episode
        @training_step = training_step
        @buffer_size   = buffer_size
        @buffer_cap    = buffer_capacity
      end

      def update(game_state:, stage_name: nil, watches: [], vision_snapshot: nil, frame_observation: nil)
        f1    = game_state.fighter1
        f2    = game_state.fighter2
        timer = game_state.round_time_remaining

        state_tag =
          if game_state.fight_active? then "fight".green
          elsif game_state.round_over? then "over".yellow
          else "idle".light_black
          end

        compact_watch = compact_watch_output?
        status_line = build_status_line(
          episode: @episode,
          stage_name: stage_name,
          timer: timer,
          fighter1: f1,
          fighter2: f2,
          state_tag: state_tag,
          compact: compact_watch
        )

        unless watches.empty?
          watch_str = watches.map { |w| "#{w[:label]}:#{w[:value].to_s.rjust(3)}" }.join("  ")
          status_line += " │ #{watch_str}".yellow
        end

        chart_lines = position_chart_lines(game_state:, vision_snapshot: vision_snapshot)
        block_lines = compact_watch ? [status_line] : [status_line, *chart_lines]
        @scene_window&.render(frame_observation: frame_observation, vision_snapshot: vision_snapshot)
        render_status_area(block_lines, replace_previous: !@last_status_lines.empty?)
        @last_status_lines = block_lines.map { |line| fit_to_terminal_width(line) }
        @last_status = @last_status_lines.join("\n")

        return unless @log_file

        log_lines = [@last_status_lines.first]
        log_lines.each { |line| @log_file.puts line.gsub(ANSI_ESCAPE_PATTERN, "") }
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

      def build_status_line(episode:, stage_name:, timer:, fighter1:, fighter2:, state_tag:, compact:)
        episode_part = "Ep #{episode.to_s.rjust(4)} ".cyan
        timer_part = "│ t:#{timer.to_s.rjust(2)} ".white
        state_part = "│ [#{state_tag}] ".dup

        if compact
          "#{episode_part}#{timer_part}│ P1 #{fighter1.health.to_s.rjust(3)} x:#{fighter1.x.to_s.rjust(3)} " \
            "│ P2 #{fighter2.health.to_s.rjust(3)} x:#{fighter2.x.to_s.rjust(3)} #{state_part}"
        else
          buf_str = "#{@buffer_size}/#{@buffer_cap}"
          buf     = @buffer_size >= @buffer_cap ? buf_str.green : buf_str.yellow

          "#{episode_part}" \
            "#{stage_name ? "│ #{stage_name} ".light_black : ""}" \
            "#{timer_part}" \
            "│ P1 #{health_bar(fighter1.health).green} #{fighter1.health.to_s.rjust(3)} x:#{fighter1.x.to_s.rjust(3)} " \
            "│ P2 #{health_bar(fighter2.health).red} #{fighter2.health.to_s.rjust(3)} x:#{fighter2.x.to_s.rjust(3)} " \
            "#{state_part}" \
            "│ buf #{buf}"
        end
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
        visible = visible_width(str)
        str + " " * [width - visible, 0].max
      end

      def fit_to_terminal_width(line)
        max_visible_width = [terminal_width - TERMINAL_WIDTH_PADDING, MIN_TERMINAL_WIDTH].max
        return line if visible_width(line) <= max_visible_width

        truncate_ansi(line, max_visible_width)
      end

      def terminal_width
        width = $stdout.winsize.fetch(1, DEFAULT_TERMINAL_WIDTH)
        width.positive? ? width : DEFAULT_TERMINAL_WIDTH
      rescue SystemCallError, IOError
        DEFAULT_TERMINAL_WIDTH
      end

      def visible_width(str)
        Unicode::DisplayWidth.of(str.gsub(ANSI_ESCAPE_PATTERN, ""))
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
            char = str[index]
            char_width = Unicode::DisplayWidth.of(char)
            break if visible + char_width > max_visible_width

            output << char
            visible += char_width
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
        previous_line_count = @last_status_lines.size

        if replace_previous
          output << "\e[#{previous_line_count}A" if previous_line_count.positive?
        end

        output << "\r\e[2K#{rendered_lines[0]}"
        rendered_lines[1..].each do |line|
          output << "\n\e[2K#{line}"
        end

        $stdout.print(output)
        $stdout.flush
      end

      def position_chart_lines(game_state:, vision_snapshot:)
        raw_line = raw_position_line(vision_snapshot)
        mk3_line = mk3_position_line(game_state, vision_snapshot)
        roi_line = roi_position_line(vision_snapshot)

        [raw_line, mk3_line, roi_line]
      end

      def raw_position_line(vision_snapshot)
        return format_chart_line(label: "raw", chart: "n/a", suffix: "vision miss") if vision_snapshot.nil?

        raw_positions = vision_snapshot[:raw_positions] || {}
        image_width   = vision_snapshot[:image_width]
        image_height  = vision_snapshot[:image_height]
        chart         = position_track(
          axis_max: image_axis_max(image_width),
          positions: raw_positions.transform_values { |point| point[:x] },
          labels: { 1 => "1", 2 => "2" }
        )
        suffix = format_point_suffix(raw_positions, image_width, image_height)
        format_chart_line(label: "raw", chart: chart, suffix: suffix)
      end

      def mk3_position_line(game_state, vision_snapshot)
        positions = {
          1 => game_state.fighter1.x,
          2 => game_state.fighter2.x
        }
        chart = position_track(
          axis_max: POSITION_MAX,
          positions: positions,
          labels: { 1 => "1", 2 => "2" }
        )
        suffix = format_mk3_suffix(game_state, vision_snapshot)
        format_chart_line(label: "mk3", chart: chart, suffix: suffix)
      end

      def roi_position_line(vision_snapshot)
        return format_chart_line(label: "roi", chart: "n/a", suffix: "vision miss") if vision_snapshot.nil?

        areas = Array(vision_snapshot[:areas])
        image_width = vision_snapshot[:image_width]
        chart = roi_track(areas, axis_max: image_axis_max(image_width))
        suffix = areas.empty? ? "full-screen" : "areas: #{format_areas(areas)}"
        format_chart_line(label: "roi", chart: chart, suffix: suffix)
      end

      def format_chart_line(label:, chart:, suffix:)
        "#{label.ljust(POSITION_CHART_LABEL_WIDTH)}│#{chart}│ #{suffix}"
      end

      def format_point_suffix(points, image_width, image_height)
        p1 = points[1]
        p2 = points[2]
        return "vision miss" if p1.nil? && p2.nil?

        "img #{image_width.to_i}x#{image_height.to_i} " \
          "p1 #{format_point(p1)} " \
          "p2 #{format_point(p2)}"
      end

      def format_mk3_suffix(game_state, vision_snapshot)
        dx = (game_state.fighter1.x - game_state.fighter2.x).abs
        raw_part = if vision_snapshot && vision_snapshot[:scaled_positions]
          scaled = vision_snapshot[:scaled_positions]
          p1 = scaled[1]
          p2 = scaled[2]
          p1_text = p1 ? format_mk3_point(p1) : "n/a"
          p2_text = p2 ? format_mk3_point(p2) : "n/a"
          "scaled #{p1_text} #{p2_text}"
        else
          "scaled n/a"
        end

        "#{raw_part} dx=#{dx}"
      end

      def format_point(point)
        return "n/a" if point.nil?

        "#{point[:x].to_i.to_s.rjust(POSITION_COORD_DIGITS)},#{point[:y].to_i.to_s.rjust(POSITION_COORD_DIGITS)}"
      end

      def format_mk3_point(point)
        "#{point[:x].to_i.to_s.rjust(POSITION_COORD_DIGITS)},#{point[:y].to_i.to_s.rjust(POSITION_COORD_DIGITS)}"
      end

      def format_areas(areas)
        areas.map { |area| "#{area.fetch("x")},#{area.fetch("y")},#{area.fetch("width")},#{area.fetch("height")}" }.join(";")
      end

      def image_axis_max(image_width)
        [image_width.to_i - 1, 1].max
      end

      def position_track(axis_max:, positions:, labels:)
        cells = Array.new(SCREEN_TRACK_WIDTH, SCREEN_EMPTY_CELL)
        positions.each do |player_index, position|
          next if position.nil?

          marker_index = track_index(position, axis_max)
          marker_char  = labels.fetch(player_index, player_index.to_s).to_s[0]
          cells[marker_index] = marker_char
        end
        "#{SCREEN_LEFT_BOUNDARY}#{cells.join}#{SCREEN_RIGHT_BOUNDARY}"
      end

      def roi_track(areas, axis_max:)
        cells = Array.new(SCREEN_TRACK_WIDTH, SCREEN_EMPTY_CELL)
        areas.each do |area|
          start_index = track_index(area.fetch("x"), axis_max)
          end_position = area.fetch("x") + area.fetch("width")
          end_index = track_index(end_position, axis_max)
          range_start = [start_index, end_index].min
          range_end = [start_index, end_index].max

          (range_start..range_end).each do |index|
            cells[index] = '='
          end
          cells[range_start] = '['
          cells[range_end] = ']'
        end
        "#{SCREEN_LEFT_BOUNDARY}#{cells.join}#{SCREEN_RIGHT_BOUNDARY}"
      end

      def track_index(position, axis_max)
        clamped_x = [[position.to_i, POSITION_MIN].max, axis_max].min
        (clamped_x.to_f * TRACK_LAST_INDEX / axis_max).round
      end

      def build_scene_window
        return nil unless ENV["DISPLAY_HOST"]

        ReconstructedSceneWindow.new(
          width:  RECONSTRUCTED_SCENE_WIDTH,
          height: RECONSTRUCTED_SCENE_HEIGHT
        )
      rescue StandardError
        nil
      end

      def compact_watch_output?
        !@scene_window.nil? || ENV["WATCH_LOG_COMPACT"] == "1"
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
