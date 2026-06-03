require "fileutils"
require_relative "network_commands"
require_relative "../../observation/frame_observation"

module FightingAI
  module Emulator
    module RetroArch
      class FrameGrabber
        TimeoutError = Class.new(RuntimeError)

        SCREENSHOT_DIR    = ConfigBuilder::SCREENSHOT_DIR
        POLL_INTERVAL     = 0.05
        POLL_TIMEOUT      = 5.0
        EMPTY_FILE_SIZE   = 0

        def initialize(host: NetworkCommands::DEFAULT_HOST, port: NetworkCommands::DEFAULT_PORT)
          @host = host
          @port = port
          FileUtils.mkdir_p(SCREENSHOT_DIR)
        end

        def capture
          before_mtimes = current_png_mtimes
          NetworkCommands.screenshot(host: @host, port: @port)

          deadline = Time.now + POLL_TIMEOUT
          loop do
            after = current_png_mtimes
            new_files = after.keys - before_mtimes.keys
            changed   = after.select { |f, t| before_mtimes[f] && t > before_mtimes[f] }.keys

            candidate = (new_files + changed).first
            return Observation::FrameObservation.new(wait_for_complete_png(candidate, deadline)) if candidate

            raise_timeout if Time.now > deadline
            sleep POLL_INTERVAL
          end
        end

        private

        def raise_timeout
          raise TimeoutError, "Screenshot timeout after #{POLL_TIMEOUT}s"
        end

        def wait_for_complete_png(path, deadline)
          previous_size = nil

          loop do
            raise_timeout if Time.now > deadline

            current_size = File.exist?(path) ? File.size(path) : EMPTY_FILE_SIZE
            return path if current_size > EMPTY_FILE_SIZE && current_size == previous_size

            previous_size = current_size
            sleep POLL_INTERVAL
          end
        end

        def current_png_mtimes
          Dir.glob(File.join(SCREENSHOT_DIR, "*.png")).each_with_object({}) do |f, h|
            h[f] = File.mtime(f)
          end
        end
      end
    end
  end
end
