require "fileutils"

module FightingAI
  module Scenario
    STATES_EXPORT_DIR      = "/app/data/states"
    MEMORY_EXPORT_DIR      = "/app/data/memory"
    SAVE_STATE_SETTLE_WAIT = 0.5

    class << self
      attr_writer :initial_state_path

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
        label = (name || Time.now.strftime("%Y%m%d_%H%M%S")).to_s
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

        label = (name || Time.now.strftime("%Y%m%d_%H%M%S")).to_s
        dest  = File.join(MEMORY_EXPORT_DIR, "#{label}.bin")
        FileUtils.mkdir_p(File.dirname(dest))
        data  = @emulator.wram_binary_dump
        File.binwrite(dest, data)
        puts "[memory] Saved → #{File.basename(dest)} (#{data.bytesize} bytes)"
        dest
      end
    end
  end
end
