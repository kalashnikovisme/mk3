require "fileutils"
require "open3"
require "securerandom"
require_relative "../../observation/frame_observation"

module FightingAI
  module Emulator
    module RetroArch
      class FrameGrabber
        CaptureError = Class.new(RuntimeError)

        SCREENSHOT_DIR         = ConfigBuilder::SCREENSHOT_DIR
        X_DISPLAY_FALLBACK     = ":99"
        XWD_BIN                = "xwd"
        XWD_SILENT_ARG         = "-silent"
        XWD_DISPLAY_ARG        = "-display"
        XWD_ROOT_ARG           = "-root"
        CONVERT_BIN             = "convert"
        CONVERT_XWD_STDIN       = "xwd:-"   # format prefix tells ImageMagick the stdin stream is XWD
        CONVERT_TYPE_ARG        = "-type"
        CONVERT_TYPE_TRUECOLOR  = "TrueColor"
        CONVERT_DEPTH_ARG       = "-depth"
        CONVERT_BIT_DEPTH       = "8"
        CONVERT_CROP_ARG        = "-crop"
        CONVERT_REPAGE_ARG      = "+repage"
        CONVERT_DEFINE_ARG      = "-define"
        CONVERT_PNG_FILTER      = "png:compression-filter=0"
        PNG_COLOR_TYPE_TRUECOLOR = 2
        CONVERT_PNG_COLOR_TYPE  = "png:color-type=#{PNG_COLOR_TYPE_TRUECOLOR}"
        PNG_PREFIX              = "png:"
        PNG_EXTENSION          = ".png"
        SCREENSHOT_PREFIX      = "frame"
        SCREENSHOT_TOKEN_BYTES = 16
        SCREENSHOT_CROP_WIDTH  = 297
        SCREENSHOT_CROP_HEIGHT = 216
        SCREENSHOT_CROP_X      = 0
        SCREENSHOT_CROP_Y      = 0

        def initialize(display: X_DISPLAY_FALLBACK)
          @display = display
          FileUtils.mkdir_p(SCREENSHOT_DIR)
        end

        def capture(display: @display)
          destination = next_screenshot_path
          capture_x_server_screenshot(destination, display: display)
          Observation::FrameObservation.new(destination)
        end

        def stop; end

        private

        # xwd and convert run as a Unix pipeline — xwd streams directly into
        # convert's stdin, eliminating the intermediate .xwd temp file on disk.
        def capture_x_server_screenshot(destination, display:)
          xwd_cmd     = [XWD_BIN, XWD_SILENT_ARG, XWD_DISPLAY_ARG, display, XWD_ROOT_ARG]
          convert_cmd = [
            CONVERT_BIN, CONVERT_XWD_STDIN,
            CONVERT_TYPE_ARG, CONVERT_TYPE_TRUECOLOR,
            CONVERT_DEPTH_ARG, CONVERT_BIT_DEPTH,
            CONVERT_CROP_ARG, screenshot_crop_geometry,
            CONVERT_REPAGE_ARG,
            CONVERT_DEFINE_ARG, CONVERT_PNG_FILTER,
            CONVERT_DEFINE_ARG, CONVERT_PNG_COLOR_TYPE,
            "#{PNG_PREFIX}#{destination}"
          ]

          statuses = Open3.pipeline(xwd_cmd, convert_cmd)
          return if statuses.all?(&:success?)

          raise CaptureError,
            "Screenshot pipeline failed " \
            "(xwd=#{statuses[0]&.exitstatus} convert=#{statuses[1]&.exitstatus}): " \
            "#{xwd_cmd.join(' ')} | #{convert_cmd.join(' ')}"
        rescue Errno::ENOENT => e
          raise CaptureError,
            "Screenshot tool not found: #{e.message}. " \
            "Run `dip provision` to rebuild the container with x11-apps and ImageMagick."
        end

        def next_screenshot_path
          File.join(SCREENSHOT_DIR, "#{SCREENSHOT_PREFIX}_#{SecureRandom.hex(SCREENSHOT_TOKEN_BYTES)}#{PNG_EXTENSION}")
        end

        def screenshot_crop_geometry
          "#{SCREENSHOT_CROP_WIDTH}x#{SCREENSHOT_CROP_HEIGHT}+#{SCREENSHOT_CROP_X}+#{SCREENSHOT_CROP_Y}"
        end
      end
    end
  end
end
