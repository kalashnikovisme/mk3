require "fileutils"

module FightingAI
  module Scenario
    STATES_EXPORT_DIR      = "/app/data/states"
    MEMORY_EXPORT_DIR      = "/app/data/memory"
    SCREENSHOT_EXPORT_DIR  = "/app/data/screenshots"
    SAVE_STATE_SETTLE_WAIT = 0.5
    TIMESTAMP_FORMAT       = "%Y%m%d_%H%M%S"
    TIMER_POLL_FRAMES      = 5
    GAME_SECOND_TIMEOUT    = 2.0  # seconds; bail if timer is frozen (round end, transition screens)

    class << self
      attr_writer :emulator, :initial_state_path, :game

      def watch(address, label: nil)
        @watches ||= []
        @watches << { address: address, label: label || format("0x%04X", address) }
      end

      def watches
        @watches || []
      end

      def wait_game_second
        raise "No emulator attached to Scenario" unless @emulator

        current  = vision_timer
        deadline = Time.now + GAME_SECOND_TIMEOUT
        loop do
          sleep(BASE_FRAME * TIMER_POLL_FRAMES)
          detected = vision_timer
          break if !detected.nil? && detected != current
          break if Time.now >= deadline
        end
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

        frame = @emulator.capture_frame
        label = timestamped_label(name)
        dest  = File.join(SCREENSHOT_EXPORT_DIR, "#{label}.png")
        FileUtils.mkdir_p(File.dirname(dest))
        FileUtils.cp(frame.path, dest)
        puts "[screenshot] Saved → #{dest}"
        dest
      end

      private

      def vision_timer
        return nil unless @game && @emulator

        frame = @emulator.capture_frame
        @game.detect_timer(frame)
      rescue StandardError
        nil
      end

      def timestamped_label(name)
        (name || Time.now.strftime(TIMESTAMP_FORMAT)).to_s
      end
    end
  end
end
