module FightingAI
  module Runtime
    class FrameCaptureRunner
      INITIAL_FRAME_NUMBER = 1
      FRAME_INCREMENT      = 1
      FRAME_LOG_FORMAT     = "f: %d; size: %d"

      def initialize(emulator:, output:, frame_limit:, frame_duration: Emulator::RetroArch::Adapter::FRAME_DURATION,
        sleeper: ->(duration) { sleep(duration) })
        @emulator       = emulator
        @output         = output
        @frame_limit    = frame_limit
        @frame_duration = frame_duration
        @sleeper        = sleeper
        @running        = false
        @interrupted    = false
      end

      def run
        @running = true
        frame_number = INITIAL_FRAME_NUMBER

        while @running && frame_number <= @frame_limit
          @sleeper.call(@frame_duration)
          frame = capture_frame
          break unless frame

          @output.puts(format(FRAME_LOG_FORMAT, frame_number, File.size(frame.path)))
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
      rescue Emulator::RetroArch::FrameGrabber::CaptureError
        raise if @running
      end
    end
  end
end
