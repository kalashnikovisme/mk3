require "fileutils"
require "open3"
require "tempfile"

module FightingAI
  module Scenario
    STATES_EXPORT_DIR      = "/app/data/states"
    MEMORY_EXPORT_DIR      = "/app/data/memory"
    SCREENSHOT_EXPORT_DIR  = "/app/data/screenshots"
    SAVE_STATE_SETTLE_WAIT = 0.5
    TIMESTAMP_FORMAT       = "%Y%m%d_%H%M%S"
    X_DISPLAY_FALLBACK     = ":99"
    XWD_BIN                = "xwd"
    XWD_SILENT_ARG         = "-silent"
    XWD_DISPLAY_ARG        = "-display"
    XWD_ROOT_ARG           = "-root"
    XWD_OUT_ARG            = "-out"
    XWD_EXTENSION          = ".xwd"
    CONVERT_BIN            = "convert"
    CONVERT_CROP_ARG       = "-crop"
    CONVERT_REPAGE_ARG     = "+repage"
    PNG_PREFIX             = "png:"
    SCREENSHOT_TEMP_PREFIX = "fighting-ai-scenario-screenshot"
    SCREENSHOT_CROP_WIDTH  = 297
    SCREENSHOT_CROP_HEIGHT = 216
    SCREENSHOT_CROP_X      = 0
    SCREENSHOT_CROP_Y      = 0

    class << self
      attr_writer :emulator, :initial_state_path

      def watch(address, label: nil)
        @watches ||= []
        @watches << { address: address, label: label || format("0x%04X", address) }
      end

      def watches
        @watches || []
      end

      def reload_state
        raise "No emulator attached to Scenario" unless @emulator
        raise "initial_state_path not set"        unless @initial_state_path
        @emulator.install_match_state(@initial_state_path)
      end

      def save_state(name = nil)
        raise "No emulator attached to Scenario" unless @emulator

        Emulator::RetroArch::NetworkCommands.save_state
        sleep(SAVE_STATE_SETTLE_WAIT)

        src = @emulator.slot0_state_path
        raise "State file not found after save: #{src}" unless File.exist?(src)

        FileUtils.mkdir_p(STATES_EXPORT_DIR)
        label = timestamped_label(name)
        dest  = File.join(STATES_EXPORT_DIR, "#{label}.state")
        FileUtils.cp(src, dest)
        puts "[state] Saved → #{dest}"
        dest
      end

      def save_memory(name = nil)
        raise "No emulator attached to Scenario" unless @emulator

        unless @wram_info_printed
          info = @emulator.wram_source_info
          puts "memory source: #{info[:source]}"
          puts "base address:  0x%06X (SNES bus)" % info[:base_address]
          puts "size:          #{info[:size]} bytes"
          puts
          @wram_info_printed = true
        end

        label = timestamped_label(name)
        dest  = File.join(MEMORY_EXPORT_DIR, "#{label}.bin")
        FileUtils.mkdir_p(File.dirname(dest))
        data  = @emulator.wram_binary_dump
        File.binwrite(dest, data)
        puts "[memory] Saved → #{File.basename(dest)} (#{data.bytesize} bytes)"
        dest
      end

      def screenshot(name = nil)
        raise "No emulator attached to Scenario" unless @emulator

        label = timestamped_label(name)
        dest  = File.join(SCREENSHOT_EXPORT_DIR, "#{label}.png")
        FileUtils.mkdir_p(File.dirname(dest))
        capture_x_server_screenshot(dest)
        puts "[screenshot] Saved → #{dest}"
        dest
      end

      private

      def capture_x_server_screenshot(dest)
        Tempfile.create([SCREENSHOT_TEMP_PREFIX, XWD_EXTENSION]) do |xwd_file|
          xwd_file.close
          run_command!(
            [
              XWD_BIN,
              XWD_SILENT_ARG,
              XWD_DISPLAY_ARG,
              x_screenshot_display,
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
              "#{PNG_PREFIX}#{dest}"
            ],
            "X server screenshot PNG conversion failed"
          )
        end
      end

      def screenshot_crop_geometry
        "#{SCREENSHOT_CROP_WIDTH}x#{SCREENSHOT_CROP_HEIGHT}+#{SCREENSHOT_CROP_X}+#{SCREENSHOT_CROP_Y}"
      end

      def x_screenshot_display
        return @emulator.display if @emulator.respond_to?(:display)

        X_DISPLAY_FALLBACK
      end

      def run_command!(command, error_prefix)
        _stdout, stderr, status = Open3.capture3(*command)
        return if status.success?

        raise "#{error_prefix}: #{command.join(' ')}\n#{stderr}"
      rescue Errno::ENOENT
        raise missing_screenshot_tool_error(command.first)
      end

      def missing_screenshot_tool_error(command_name)
        "X server screenshot tool not found: #{command_name}. " \
          "Run `dip provision` to rebuild the container with x11-apps and ImageMagick."
      end

      def timestamped_label(name)
        (name || Time.now.strftime(TIMESTAMP_FORMAT)).to_s
      end
    end
  end
end
