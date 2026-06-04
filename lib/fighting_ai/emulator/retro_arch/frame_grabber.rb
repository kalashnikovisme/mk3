require "fileutils"
require "open3"
require "securerandom"
require "tempfile"
require_relative "../../observation/frame_observation"

module FightingAI
  module Emulator
    module RetroArch
      class FrameGrabber
        CaptureError = Class.new(RuntimeError)

        SCREENSHOT_DIR = ConfigBuilder::SCREENSHOT_DIR
        X_DISPLAY_FALLBACK = ":99"
        XWD_BIN = "xwd"
        XWD_SILENT_ARG = "-silent"
        XWD_DISPLAY_ARG = "-display"
        XWD_ROOT_ARG = "-root"
        XWD_OUT_ARG = "-out"
        XWD_EXTENSION = ".xwd"
        CONVERT_BIN = "convert"
        CONVERT_CROP_ARG = "-crop"
        CONVERT_REPAGE_ARG = "+repage"
        PNG_PREFIX = "png:"
        PNG_EXTENSION = ".png"
        SCREENSHOT_PREFIX = "frame"
        SCREENSHOT_TEMP_PREFIX = "fighting-ai-frame-screenshot"
        SCREENSHOT_TOKEN_BYTES = 16
        SCREENSHOT_CROP_WIDTH = 297
        SCREENSHOT_CROP_HEIGHT = 216
        SCREENSHOT_CROP_X = 0
        SCREENSHOT_CROP_Y = 0

        def initialize(display: X_DISPLAY_FALLBACK)
          @display = display
          FileUtils.mkdir_p(SCREENSHOT_DIR)
        end

        def capture(display: @display)
          destination = next_screenshot_path
          capture_x_server_screenshot(destination, display: display)
          Observation::FrameObservation.new(destination)
        end

        private

        def capture_x_server_screenshot(destination, display:)
          Tempfile.create([SCREENSHOT_TEMP_PREFIX, XWD_EXTENSION]) do |xwd_file|
            xwd_file.close
            run_command!(
              [
                XWD_BIN,
                XWD_SILENT_ARG,
                XWD_DISPLAY_ARG,
                display,
                XWD_ROOT_ARG,
                XWD_OUT_ARG,
                xwd_file.path
              ],
              "X server screenshot capture failed"
            )
            run_command!(
              [
                CONVERT_BIN,
                xwd_file.path,
                CONVERT_CROP_ARG,
                screenshot_crop_geometry,
                CONVERT_REPAGE_ARG,
                "#{PNG_PREFIX}#{destination}"
              ],
              "X server screenshot PNG conversion failed"
            )
          end
        end

        def next_screenshot_path
          File.join(SCREENSHOT_DIR, "#{SCREENSHOT_PREFIX}_#{SecureRandom.hex(SCREENSHOT_TOKEN_BYTES)}#{PNG_EXTENSION}")
        end

        def screenshot_crop_geometry
          "#{SCREENSHOT_CROP_WIDTH}x#{SCREENSHOT_CROP_HEIGHT}+#{SCREENSHOT_CROP_X}+#{SCREENSHOT_CROP_Y}"
        end

        def run_command!(command, error_prefix)
          _stdout, stderr, status = Open3.capture3(*command)
          return if status.success?

          raise CaptureError, "#{error_prefix}: #{command.join(' ')}\n#{stderr}"
        rescue Errno::ENOENT
          raise CaptureError, missing_screenshot_tool_error(command.first)
        end

        def missing_screenshot_tool_error(command_name)
          "X server screenshot tool not found: #{command_name}. " \
            "Run `dip provision` to rebuild the container with x11-apps and ImageMagick."
        end
      end
    end
  end
end
