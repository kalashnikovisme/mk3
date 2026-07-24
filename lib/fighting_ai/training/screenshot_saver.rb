require "fileutils"

module FightingAI
  module Training
    class ScreenshotSaver
      PPM_MAGIC             = "P6"
      PPM_MAX_COLOR         = 255
      FRAME_FILENAME_FORMAT = "frame_%05d.ppm"
      AREA_FILENAME_FORMAT  = "frame_%05d%s.ppm"
      FIGHTER1_AREA_SUFFIX  = "_fighter1_area"
      FIGHTER2_AREA_SUFFIX  = "_fighter2_area"
      AREA_SUFFIXES         = [FIGHTER1_AREA_SUFFIX, FIGHTER2_AREA_SUFFIX].freeze
      BYTES_PER_PIXEL       = 3
      WORKER_JOIN_TIMEOUT   = 10

      def initialize(dir, width:, height:)
        FileUtils.mkdir_p(dir)
        @dir    = dir
        @width  = width
        @height = height
        @queue  = Queue.new
        @worker = Thread.new { work_loop }
        @worker.report_on_exception = true
      end

      def save(frame_observation, frame_number, areas: nil)
        return unless frame_observation&.raw_bytes

        @queue.push([frame_observation.raw_bytes, frame_number, areas])
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

          bytes, frame_number, areas = item
          write_ppm(bytes, frame_number)
          write_area_ppms(bytes, frame_number, areas) if areas && !areas.empty?
        end
      end

      def write_ppm(bytes, frame_number)
        path = File.join(@dir, FRAME_FILENAME_FORMAT % frame_number)
        File.open(path, "wb") do |f|
          f.write("#{PPM_MAGIC}\n#{@width} #{@height}\n#{PPM_MAX_COLOR}\n")
          f.write(bytes)
        end
      end

      def write_area_ppms(bytes, frame_number, areas)
        areas.each_with_index do |area, index|
          suffix = AREA_SUFFIXES[index]
          next unless suffix

          cropped = crop_rgb_bytes(bytes, area)
          next unless cropped

          path = File.join(@dir, AREA_FILENAME_FORMAT % [frame_number, suffix])
          File.open(path, "wb") do |f|
            f.write("#{PPM_MAGIC}\n#{area.fetch("width")} #{area.fetch("height")}\n#{PPM_MAX_COLOR}\n")
            f.write(cropped)
          end
        end
      end

      def crop_rgb_bytes(bytes, area)
        x            = area.fetch("x")
        y            = area.fetch("y")
        area_width   = area.fetch("width")
        area_height  = area.fetch("height")

        return nil if area_width <= 0 || area_height <= 0
        return nil if x < 0 || y < 0 || x + area_width > @width || y + area_height > @height

        row_stride      = @width * BYTES_PER_PIXEL
        crop_row_bytes  = area_width * BYTES_PER_PIXEL
        col_offset      = x * BYTES_PER_PIXEL

        cropped = "".b
        area_height.times do |row|
          row_start = (y + row) * row_stride + col_offset
          cropped << bytes.byteslice(row_start, crop_row_bytes)
        end
        cropped
      end
    end
  end
end
