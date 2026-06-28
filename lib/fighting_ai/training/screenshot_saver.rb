require "fileutils"

module FightingAI
  module Training
    class ScreenshotSaver
      PPM_MAGIC            = "P6"
      PPM_MAX_COLOR        = 255
      FRAME_FILENAME_FORMAT = "frame_%05d.ppm"
      WORKER_JOIN_TIMEOUT  = 10

      def initialize(dir, width:, height:)
        FileUtils.mkdir_p(dir)
        @dir    = dir
        @width  = width
        @height = height
        @queue  = Queue.new
        @worker = Thread.new { work_loop }
        @worker.report_on_exception = true
      end

      def save(frame_observation, frame_number)
        return unless frame_observation&.raw_bytes

        @queue.push([frame_observation.raw_bytes, frame_number])
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

          bytes, frame_number = item
          write_ppm(bytes, frame_number)
        end
      end

      def write_ppm(bytes, frame_number)
        path = File.join(@dir, FRAME_FILENAME_FORMAT % frame_number)
        File.open(path, "wb") do |f|
          f.write("#{PPM_MAGIC}\n#{@width} #{@height}\n#{PPM_MAX_COLOR}\n")
          f.write(bytes)
        end
      end
    end
  end
end
