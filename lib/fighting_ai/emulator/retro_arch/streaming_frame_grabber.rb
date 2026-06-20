require "open3"
require_relative "../../observation/frame_observation"
require_relative "frame_grabber"

module FightingAI
  module Emulator
    module RetroArch
      class StreamingFrameGrabber
        CaptureError = FrameGrabber::CaptureError

        FFMPEG_BIN           = "ffmpeg"
        FFMPEG_LOGLEVEL_ARG  = "-loglevel"
        FFMPEG_LOGLEVEL      = "quiet"
        FFMPEG_FORMAT_ARG    = "-f"
        FFMPEG_INPUT_FORMAT  = "x11grab"
        FFMPEG_FRAMERATE_ARG = "-framerate"
        FFMPEG_FRAMERATE     = 60
        FFMPEG_INPUT_ARG     = "-i"
        FFMPEG_FILTER_ARG    = "-vf"
        FFMPEG_PIXEL_FMT_ARG = "-pix_fmt"
        FFMPEG_PIXEL_FORMAT  = "rgb24"
        FFMPEG_OUTPUT_FORMAT = "rawvideo"
        FFMPEG_PIPE_OUTPUT   = "pipe:1"

        FRAME_WIDTH     = FrameGrabber::SCREENSHOT_CROP_WIDTH
        FRAME_HEIGHT    = FrameGrabber::SCREENSHOT_CROP_HEIGHT
        CROP_X          = FrameGrabber::SCREENSHOT_CROP_X
        CROP_Y          = FrameGrabber::SCREENSHOT_CROP_Y
        BYTES_PER_PIXEL = Observation::FrameObservation::RGB_CHANNELS
        FRAME_BYTES     = FRAME_WIDTH * FRAME_HEIGHT * BYTES_PER_PIXEL

        READER_JOIN_TIMEOUT = 1

        def initialize(display:)
          @display       = display
          @frame_mutex   = Mutex.new
          @latest_frame  = nil
          @start_cond    = ConditionVariable.new
          @running       = false
          @ffmpeg_pid    = nil
          @stdout        = nil
          @reader_thread = nil
        end

        def capture(display: @display)
          ensure_started(display)
          frame_bytes = @frame_mutex.synchronize { @latest_frame }
          raise CaptureError, "No frame available from ffmpeg" unless frame_bytes

          Observation::FrameObservation.from_raw_rgb(frame_bytes, width: FRAME_WIDTH, height: FRAME_HEIGHT)
        rescue IOError => e
          raise CaptureError, "Frame stream error: #{e.message}"
        end

        def stop
          @running = false
          @stdout&.close rescue nil
          begin
            Process.kill("TERM", @ffmpeg_pid) if @ffmpeg_pid
          rescue Errno::ESRCH, Errno::EPERM
            nil
          end
          @reader_thread&.join(READER_JOIN_TIMEOUT)
          @ffmpeg_pid    = nil
          @stdout        = nil
          @reader_thread = nil
          @frame_mutex.synchronize { @start_cond.signal }
        end

        private

        def ensure_started(display)
          return if @running && @reader_thread&.alive?

          stop
          @running = true

          # popen2 leaves ffmpeg's stderr connected to Ruby's $stderr so errors
          # are visible when $stderr has not been redirected to /dev/null.
          ffmpeg_stdin, ffmpeg_stdout, wait_thr = Open3.popen2(*build_ffmpeg_command(display))
          ffmpeg_stdin.close
          @ffmpeg_pid    = wait_thr.pid
          @stdout        = ffmpeg_stdout
          @reader_thread = Thread.new { reader_loop }

          @frame_mutex.synchronize do
            @start_cond.wait(@frame_mutex) while @latest_frame.nil? && @running
          end
        end

        def reader_loop
          first_frame = true
          loop do
            raw = @stdout.read(FRAME_BYTES)
            break unless raw && raw.bytesize == FRAME_BYTES

            @frame_mutex.synchronize do
              @latest_frame = raw
              @start_cond.signal if first_frame
            end
            first_frame = false
          end
        rescue IOError
          nil
        ensure
          @running = false
          @frame_mutex.synchronize { @start_cond.signal }
        end

        def build_ffmpeg_command(display)
          [
            FFMPEG_BIN,
            FFMPEG_LOGLEVEL_ARG,  FFMPEG_LOGLEVEL,
            FFMPEG_FORMAT_ARG,    FFMPEG_INPUT_FORMAT,
            FFMPEG_FRAMERATE_ARG, FFMPEG_FRAMERATE.to_s,
            FFMPEG_INPUT_ARG,     display,
            FFMPEG_FILTER_ARG,    crop_filter,
            FFMPEG_FORMAT_ARG,    FFMPEG_OUTPUT_FORMAT,
            FFMPEG_PIXEL_FMT_ARG, FFMPEG_PIXEL_FORMAT,
            FFMPEG_PIPE_OUTPUT
          ]
        end

        def crop_filter
          "crop=#{FRAME_WIDTH}:#{FRAME_HEIGHT}:#{CROP_X}:#{CROP_Y}"
        end
      end
    end
  end
end
