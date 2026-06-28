module FightingAI
  module Runtime
    class FrameCaptureRunner
      INITIAL_FRAME_NUMBER = 1
      FRAME_INCREMENT      = 1
      FRAME_HEADER_PREFIX  = "frame: "
      FIELD_INDENT         = "  "
      FIELD_FORMAT         = "%s: %s"
      MS_PER_SECOND        = 1000
      CAPTURE_MS_KEY       = :capture_ms
      DETECT_MS_KEY        = :detect_ms
      TOTAL_MS_KEY         = :total_ms

      def initialize(emulator:, output:, frame_limit:, frame_advancer: nil, metadata_detector: nil)
        @emulator       = emulator
        @output         = output
        @frame_limit    = frame_limit
        @frame_advancer = frame_advancer || -> { @emulator.frame_advance }
        @metadata_detector = metadata_detector
        @running        = false
        @interrupted    = false
      end

      def run
        @running = true
        frame_number = INITIAL_FRAME_NUMBER

        while @running && frame_number <= @frame_limit
          @frame_advancer.call

          t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          frame = capture_frame
          break unless frame
          t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          fields = { frame_bytes: frame.byte_size }
          fields.merge!(@metadata_detector.call(frame)) if @metadata_detector
          t2 = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          fields[CAPTURE_MS_KEY] = ((t1 - t0) * MS_PER_SECOND).round
          fields[DETECT_MS_KEY]  = ((t2 - t1) * MS_PER_SECOND).round
          fields[TOTAL_MS_KEY]   = ((t2 - t0) * MS_PER_SECOND).round

          @output.puts(FRAME_HEADER_PREFIX + frame_number.to_s)
          fields.each { |name, value| @output.puts(FIELD_INDENT + format(FIELD_FORMAT, name, value)) }
          @output.puts
          frame_number += FRAME_INCREMENT
        end
      end

      def stop
        @running     = false
        @interrupted = true
      end

      def interrupted?
        @interrupted
      end

      private

      def capture_frame
        @emulator.capture_frame
      rescue Emulator::RetroArch::StreamingFrameGrabber::CaptureError
        raise if @running
      end
    end
  end
end
