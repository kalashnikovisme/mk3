require "fileutils"

module FightingAI
  module Training
    class ScreenshotSaver
      PPM_MAGIC                     = "P6"
      PPM_MAX_COLOR                 = 255
      FRAME_FILENAME_FORMAT         = "frame_%05d.ppm"
      SCREEN_DIRNAME                = "screen"
      RECONSTRUCTION_DIRNAME        = "reconstruction"
      FIGHTER1_DIRNAME              = "fighter1"
      FIGHTER2_DIRNAME              = "fighter2"
      AREA_DIRNAMES                 = [FIGHTER1_DIRNAME, FIGHTER2_DIRNAME].freeze
      BYTES_PER_PIXEL               = 3
      WORKER_JOIN_TIMEOUT           = 10
      RECONSTRUCTION_BACKGROUND_RED = 44
      RECONSTRUCTION_BACKGROUND_GREEN = 44
      RECONSTRUCTION_BACKGROUND_BLUE = 44
      RECONSTRUCTION_BORDER_RED     = 255
      RECONSTRUCTION_BORDER_GREEN   = 255
      RECONSTRUCTION_BORDER_BLUE    = 255
      P1_BORDER_RED                 = 0
      P1_BORDER_GREEN               = 200
      P1_BORDER_BLUE                = 255
      P2_BORDER_RED                 = 255
      P2_BORDER_GREEN               = 96
      P2_BORDER_BLUE                = 255

      def initialize(dir, width:, height:)
        @dir    = dir
        @width  = width
        @height = height
        @queue  = Queue.new
        prepare_directories
        @worker = Thread.new { work_loop }
        @worker.report_on_exception = true
      end

      def save(frame_observation, frame_number, areas: nil, vision_snapshot: nil)
        return unless frame_observation&.raw_bytes

        @queue.push([
          frame_observation.raw_bytes,
          frame_observation.width,
          frame_observation.height,
          frame_number,
          areas,
          vision_snapshot
        ])
      end

      def stop
        @queue.push(nil)
        @worker.join(WORKER_JOIN_TIMEOUT)
      end

      private

      def work_loop
        loop do
          item = @queue.pop
          break if item.nil?

          bytes, width, height, frame_number, areas, vision_snapshot = item
          write_ppm(bytes, width, height, frame_number)
          write_area_ppms(bytes, width, height, frame_number, areas) if areas && !areas.empty?
          write_reconstruction_ppm(bytes, width, height, frame_number, vision_snapshot)
        end
      end

      def write_ppm(bytes, width, height, frame_number)
        path = File.join(@dir, SCREEN_DIRNAME, FRAME_FILENAME_FORMAT % frame_number)
        File.open(path, "wb") do |f|
          f.write("#{PPM_MAGIC}\n#{width} #{height}\n#{PPM_MAX_COLOR}\n")
          f.write(bytes)
        end
      end

      def write_reconstruction_ppm(bytes, width, height, frame_number, vision_snapshot)
        path = File.join(@dir, RECONSTRUCTION_DIRNAME, FRAME_FILENAME_FORMAT % frame_number)
        File.open(path, "wb") do |f|
          reconstruction = compose_reconstruction_bytes(bytes, width, height, vision_snapshot)
          f.write("#{PPM_MAGIC}\n#{width} #{height}\n#{PPM_MAX_COLOR}\n")
          f.write(reconstruction)
        end
      end

      def write_area_ppms(bytes, width, height, frame_number, areas)
        areas.each_with_index do |area, index|
          dirname = AREA_DIRNAMES[index]
          next unless dirname

          cropped = crop_rgb_bytes(bytes, width, height, area)
          next unless cropped

          path = File.join(@dir, dirname, FRAME_FILENAME_FORMAT % frame_number)
          File.open(path, "wb") do |f|
            f.write("#{PPM_MAGIC}\n#{area.fetch("width")} #{area.fetch("height")}\n#{PPM_MAX_COLOR}\n")
            f.write(cropped)
          end
        end
      end

      def crop_rgb_bytes(bytes, width, height, area)
        x            = area.fetch("x")
        y            = area.fetch("y")
        area_width   = area.fetch("width")
        area_height  = area.fetch("height")

        return nil if area_width <= 0 || area_height <= 0
        return nil if x < 0 || y < 0 || x + area_width > width || y + area_height > height

        row_stride      = width * BYTES_PER_PIXEL
        crop_row_bytes  = area_width * BYTES_PER_PIXEL
        col_offset      = x * BYTES_PER_PIXEL

        cropped = "".b
        area_height.times do |row|
          row_start = (y + row) * row_stride + col_offset
          cropped << bytes.byteslice(row_start, crop_row_bytes)
        end
        cropped
      end

      def compose_reconstruction_bytes(source, width, height, vision_snapshot)
        canvas = background_canvas(width, height)
        draw_canvas_border!(canvas, width, height)

        detections = vision_snapshot&.fetch(:player_detections, {}) || {}
        detections.each do |player_index, detection|
          next unless detection

          copy_detection!(canvas, source, width, height, detection)
          draw_border!(canvas, width, height, detection, border_color_for(player_index))
        end

        canvas
      end

      def background_canvas(width, height)
        pixel = [
          RECONSTRUCTION_BACKGROUND_RED,
          RECONSTRUCTION_BACKGROUND_GREEN,
          RECONSTRUCTION_BACKGROUND_BLUE
        ].pack("C*")
        pixel * (width * height)
      end

      def draw_canvas_border!(canvas, width, height)
        color_bytes = [
          RECONSTRUCTION_BORDER_RED,
          RECONSTRUCTION_BORDER_GREEN,
          RECONSTRUCTION_BORDER_BLUE
        ].pack("C*")
        (0...width).each do |x|
          set_pixel!(canvas, width, x, 0, color_bytes)
          set_pixel!(canvas, width, x, height - 1, color_bytes)
        end
        (0...height).each do |y|
          set_pixel!(canvas, width, 0, y, color_bytes)
          set_pixel!(canvas, width, width - 1, y, color_bytes)
        end
      end

      def copy_detection!(canvas, source, width, height, detection)
        x_start = clamp(detection.x, 0, width - 1)
        y_start = clamp(detection.y, 0, height - 1)
        x_end = clamp(detection.x + detection.width - 1, 0, width - 1)
        y_end = clamp(detection.y + detection.height - 1, 0, height - 1)
        return if x_end < x_start || y_end < y_start

        row_width = (x_end - x_start + 1) * BYTES_PER_PIXEL
        x_offset = x_start * BYTES_PER_PIXEL

        (y_start..y_end).each do |y|
          row_offset = y * width * BYTES_PER_PIXEL
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
        offset = ((y * width) + x) * BYTES_PER_PIXEL
        canvas[offset, BYTES_PER_PIXEL] = color_bytes
      end

      def border_color_for(player_index)
        case player_index
        when 1 then [P1_BORDER_RED, P1_BORDER_GREEN, P1_BORDER_BLUE]
        when 2 then [P2_BORDER_RED, P2_BORDER_GREEN, P2_BORDER_BLUE]
        else [RECONSTRUCTION_BORDER_RED, RECONSTRUCTION_BORDER_GREEN, RECONSTRUCTION_BORDER_BLUE]
        end
      end

      def clamp(value, min_value, max_value)
        [[value.to_i, min_value].max, max_value].min
      end

      def prepare_directories
        FileUtils.mkdir_p(File.join(@dir, SCREEN_DIRNAME))
        FileUtils.mkdir_p(File.join(@dir, RECONSTRUCTION_DIRNAME))
        AREA_DIRNAMES.each do |dirname|
          FileUtils.mkdir_p(File.join(@dir, dirname))
        end
      end
    end
  end
end
