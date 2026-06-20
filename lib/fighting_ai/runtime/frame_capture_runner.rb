module FightingAI
  module Runtime
    class FrameCaptureRunner
      INITIAL_FRAME_NUMBER = 1
      FRAME_INCREMENT      = 1
      FIELD_SEPARATOR      = "; "

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
          frame = capture_frame
          break unless frame

          fields = { f: frame_number, size: File.size(frame.path) }
          fields.merge!(@metadata_detector.call(frame)) if @metadata_detector
          @output.puts(fields.map { |name, value| "#{name}: #{value}" }.join(FIELD_SEPARATOR))
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
