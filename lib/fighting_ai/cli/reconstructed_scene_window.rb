require "open3"
require_relative "../observation/frame_observation"

module FightingAI
  module CLI
    class ReconstructedSceneWindow
      FFPLAY_BIN = "ffplay"
      FFPLAY_LOG_LEVEL_ARG = "-loglevel"
      FFPLAY_LOG_LEVEL_VALUE = "quiet"
      WINDOW_TITLE = "Reconstructed Scene"
      WINDOW_GAP_PIXELS = 12
      DEFAULT_WINDOW_LEFT = FightingAI::Emulator::RetroArch::ConfigBuilder::RETROARCH_WINDOW_WIDTH + WINDOW_GAP_PIXELS
      PIXEL_BYTES = FightingAI::Observation::FrameObservation::RGB_CHANNELS
      DEFAULT_WINDOW_Y = 0
      DEFAULT_WINDOW_X = 0
      RETROARCH_DISPLAY = ":99"
      XWININFO_BIN = "xwininfo"
      XWININFO_NAME_ARG = "-name"
      FFPLAY_AUTOEXIT_ARG = "-autoexit"
      FFPLAY_NOBORDER_ARG = "-noborder"
      FFPLAY_ALWAYS_ON_TOP_ARG = "-alwaysontop"
      FFPLAY_WINDOW_TITLE_ARG = "-window_title"
      FFPLAY_VIDEO_SIZE_ARG = "-video_size"
      FFPLAY_PIXEL_FORMAT_ARG = "-pixel_format"
      FFPLAY_FRAMERATE_ARG = "-framerate"
      FFPLAY_FORMAT_ARG = "-f"
      FFPLAY_RAWVIDEO = "rawvideo"
      FFPLAY_RGB24 = "rgb24"
      FFPLAY_INPUT_ARG = "-i"
      FFPLAY_INPUT_STDIN = "-"
      FFPLAY_LEFT_ARG = "-left"
      FFPLAY_TOP_ARG = "-top"
      FFPLAY_WIDTH_ARG = "-x"
      FFPLAY_HEIGHT_ARG = "-y"
      DEFAULT_FRAME_RATE = 60
      BACKGROUND_RED = 44
      BACKGROUND_GREEN = 44
      BACKGROUND_BLUE = 44
      CANVAS_BORDER_RED = 255
      CANVAS_BORDER_GREEN = 255
      CANVAS_BORDER_BLUE = 255
      TEXT_CONTENT = "TEST"
      TEXT_LEFT_MARGIN_PIXELS = 8
      TEXT_TOP_MARGIN_PIXELS = 8
      TEXT_GLYPH_WIDTH = 5
      TEXT_GLYPH_HEIGHT = 7
      TEXT_GLYPH_SCALE = 4
      TEXT_GLYPH_SPACING_PIXELS = 1
      TEXT_COLOR_RED = 255
      TEXT_COLOR_GREEN = 255
      TEXT_COLOR_BLUE = 255
      BORDER_RED = 255
      BORDER_GREEN = 215
      BORDER_BLUE = 0
      P1_BORDER_RED = 0
      P1_BORDER_GREEN = 200
      P1_BORDER_BLUE = 255
      P2_BORDER_RED = 255
      P2_BORDER_GREEN = 96
      P2_BORDER_BLUE = 255
      GLYPHS = {
        "T" => [
          "11111",
          "00100",
          "00100",
          "00100",
          "00100",
          "00100",
          "00100"
        ],
        "E" => [
          "11111",
          "10000",
          "10000",
          "11110",
          "10000",
          "10000",
          "11111"
        ],
        "S" => [
          "01111",
          "10000",
          "10000",
          "01110",
          "00001",
          "00001",
          "11110"
        ]
      }.freeze

      def self.available?
        system("which", FFPLAY_BIN, out: File::NULL, err: File::NULL)
      end

      def initialize(width:, height:, frame_rate: DEFAULT_FRAME_RATE)
        @width = width
        @height = height
        @frame_rate = frame_rate
        @process = nil
        @stdin = nil
        @stdout = nil
        @stderr = nil
        @wait_thread = nil
        @disabled = false
        @available = self.class.available?
        at_exit { close }
      end

      def render(frame_observation:, vision_snapshot:)
        return if @disabled
        return unless @available

        ensure_started
        return unless @stdin

        frame_bytes =
          if frame_observation.nil?
            placeholder_frame
          else
            compose_frame(frame_observation, vision_snapshot || {})
          end
        @stdin.write(frame_bytes)
        @stdin.flush
      rescue StandardError
        @disabled = true
        close
      end

      def close
        @stdin&.close unless @stdin&.closed?
        @stdout&.close unless @stdout&.closed?
        @stderr&.close unless @stderr&.closed?
        if @wait_thread&.alive?
          Process.kill("TERM", @wait_thread.pid) rescue nil
          @wait_thread.join(1)
        end
        @stdin = nil
        @stdout = nil
        @stderr = nil
        @wait_thread = nil
        @process = nil
      end

      private

      def ensure_started
        return if @process && @wait_thread&.alive?

        close
        @stdin, @stdout, @stderr, @wait_thread = Open3.popen3({ "DISPLAY" => RETROARCH_DISPLAY }, *ffplay_command)
        @process = @wait_thread
        @stdout.close rescue nil
        @stderr.close rescue nil
      end

      def ffplay_command
        [
          FFPLAY_BIN,
          FFPLAY_LOG_LEVEL_ARG, FFPLAY_LOG_LEVEL_VALUE,
          FFPLAY_AUTOEXIT_ARG,
          FFPLAY_NOBORDER_ARG,
          FFPLAY_ALWAYS_ON_TOP_ARG,
          FFPLAY_LEFT_ARG, window_left.to_s,
          FFPLAY_TOP_ARG, window_top.to_s,
          FFPLAY_WIDTH_ARG, @width.to_s,
          FFPLAY_HEIGHT_ARG, @height.to_s,
          FFPLAY_VIDEO_SIZE_ARG, "#{@width}x#{@height}",
          FFPLAY_WINDOW_TITLE_ARG, WINDOW_TITLE,
          FFPLAY_PIXEL_FORMAT_ARG, FFPLAY_RGB24,
          FFPLAY_FRAMERATE_ARG, @frame_rate.to_s,
          FFPLAY_FORMAT_ARG, FFPLAY_RAWVIDEO,
          FFPLAY_INPUT_ARG, FFPLAY_INPUT_STDIN
        ]
      end

      def window_left
        geometry = retroarch_geometry
        return DEFAULT_WINDOW_LEFT unless geometry

        geometry[:x] + geometry[:width] + WINDOW_GAP_PIXELS
      end

      def window_top
        geometry = retroarch_geometry
        return DEFAULT_WINDOW_Y unless geometry

        geometry[:y]
      end

      def retroarch_geometry
        output, status = Open3.capture2(
          { "DISPLAY" => RETROARCH_DISPLAY },
          XWININFO_BIN,
          XWININFO_NAME_ARG,
          "RetroArch"
        )
        return nil unless status.success?

        parse_geometry(output)
      rescue StandardError
        nil
      end

      def parse_geometry(output)
        x = nil
        y = nil
        width = nil
        height = nil

        output.each_line do |line|
          stripped = line.strip
          if (match = stripped.match(/\AAbsolute upper-left X:\s*(\d+)\z/))
            x = match[1].to_i
          elsif (match = stripped.match(/\AAbsolute upper-left Y:\s*(\d+)\z/))
            y = match[1].to_i
          elsif (match = stripped.match(/\AWidth:\s*(\d+)\z/))
            width = match[1].to_i
          elsif (match = stripped.match(/\AHeight:\s*(\d+)\z/))
            height = match[1].to_i
          end
        end

        return nil if [x, y, width, height].any?(&:nil?)

        { x: x, y: y, width: width, height: height }
      end

      def compose_frame(frame_observation, vision_snapshot)
        source = frame_observation.raw_bytes
        return placeholder_frame if source.nil?

        width = frame_observation.width
        height = frame_observation.height
        canvas = background_canvas(width, height)
        draw_canvas_border!(canvas, width, height)
        draw_test_label!(canvas, width, height)
        detections = vision_snapshot[:player_detections] || {}
        detections.each do |player_index, detection|
          next unless detection

          copy_detection!(canvas, source, width, height, detection)
          draw_border!(canvas, width, height, detection, border_color_for(player_index))
        end
        canvas
      end

      def placeholder_frame
        canvas = background_canvas(@width, @height)
        draw_canvas_border!(canvas, @width, @height)
        draw_test_label!(canvas, @width, @height)
        canvas
      end

      def background_canvas(width, height)
        pixel = [BACKGROUND_RED, BACKGROUND_GREEN, BACKGROUND_BLUE].pack("C*")
        pixel * (width * height)
      end

      def draw_canvas_border!(canvas, width, height)
        color_bytes = [CANVAS_BORDER_RED, CANVAS_BORDER_GREEN, CANVAS_BORDER_BLUE].pack("C*")
        (0...width).each do |x|
          set_pixel!(canvas, width, x, 0, color_bytes)
          set_pixel!(canvas, width, x, height - 1, color_bytes)
        end
        (0...height).each do |y|
          set_pixel!(canvas, width, 0, y, color_bytes)
          set_pixel!(canvas, width, width - 1, y, color_bytes)
        end
      end

      def draw_test_label!(canvas, width, height)
        draw_text!(
          canvas,
          width,
          height,
          TEXT_CONTENT,
          TEXT_LEFT_MARGIN_PIXELS,
          TEXT_TOP_MARGIN_PIXELS,
          [TEXT_COLOR_RED, TEXT_COLOR_GREEN, TEXT_COLOR_BLUE]
        )
      end

      def draw_text!(canvas, width, height, text, start_x, start_y, color)
        color_bytes = color.pack("C*")
        cursor_x = start_x
        text.each_char do |character|
          draw_glyph!(canvas, width, height, character, cursor_x, start_y, color_bytes)
          cursor_x += (TEXT_GLYPH_WIDTH * TEXT_GLYPH_SCALE) + TEXT_GLYPH_SPACING_PIXELS
        end
      end

      def draw_glyph!(canvas, width, height, character, start_x, start_y, color_bytes)
        rows = GLYPHS.fetch(character)
        rows.each_with_index do |row, row_index|
          row.chars.each_with_index do |cell, col_index|
            next unless cell == "1"

            fill_rect!(
              canvas,
              width,
              height,
              start_x + (col_index * TEXT_GLYPH_SCALE),
              start_y + (row_index * TEXT_GLYPH_SCALE),
              TEXT_GLYPH_SCALE,
              TEXT_GLYPH_SCALE,
              color_bytes
            )
          end
        end
      end

      def fill_rect!(canvas, width, height, x, y, rect_width, rect_height, color_bytes)
        (0...rect_height).each do |dy|
          (0...rect_width).each do |dx|
            px = x + dx
            py = y + dy
            next if px.negative? || py.negative?
            next if px >= width || py >= height

            set_pixel!(canvas, width, px, py, color_bytes)
          end
        end
      end

      def copy_detection!(canvas, source, width, height, detection)
        x_start = clamp(detection.x, 0, width - 1)
        y_start = clamp(detection.y, 0, height - 1)
        x_end = clamp(detection.x + detection.width - 1, 0, width - 1)
        y_end = clamp(detection.y + detection.height - 1, 0, height - 1)
        return if x_end < x_start || y_end < y_start

        row_width = (x_end - x_start + 1) * PIXEL_BYTES
        x_offset = x_start * PIXEL_BYTES

        (y_start..y_end).each do |y|
          row_offset = y * width * PIXEL_BYTES
          slice = source.byteslice(row_offset + x_offset, row_width)
          canvas[row_offset + x_offset, row_width] = slice if slice
        end
      end

      def draw_border!(canvas, width, height, detection, color)
        x_start = clamp(detection.x, 0, width - 1)
        y_start = clamp(detection.y, 0, height - 1)
        x_end = clamp(detection.x + detection.width - 1, 0, width - 1)
        y_end = clamp(detection.y + detection.height - 1, 0, height - 1)
        return if x_end < x_start || y_end < y_start

        color_bytes = color.pack("C*")
        (x_start..x_end).each do |x|
          set_pixel!(canvas, width, x, y_start, color_bytes)
          set_pixel!(canvas, width, x, y_end, color_bytes)
        end
        (y_start..y_end).each do |y|
          set_pixel!(canvas, width, x_start, y, color_bytes)
          set_pixel!(canvas, width, x_end, y, color_bytes)
        end
      end

      def set_pixel!(canvas, width, x, y, color_bytes)
        offset = ((y * width) + x) * PIXEL_BYTES
        canvas[offset, PIXEL_BYTES] = color_bytes
      end

      def border_color_for(player_index)
        case player_index
        when 1 then [P1_BORDER_RED, P1_BORDER_GREEN, P1_BORDER_BLUE]
        when 2 then [P2_BORDER_RED, P2_BORDER_GREEN, P2_BORDER_BLUE]
        else [BORDER_RED, BORDER_GREEN, BORDER_BLUE]
        end
      end

      def clamp(value, min_value, max_value)
        [[value.to_i, min_value].max, max_value].min
      end
    end
  end
end
