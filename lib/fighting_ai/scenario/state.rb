require "fileutils"

module FightingAI
  module Scenario
    STATES_EXPORT_DIR      = "/app/data/states"
    MEMORY_EXPORT_DIR      = "/app/data/memory"
    SAVE_STATE_SETTLE_WAIT = 0.5

    class << self
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

        FileUtils.mkdir_p(MEMORY_EXPORT_DIR)
        label = (name || Time.now.strftime("%Y%m%d_%H%M%S")).to_s
        dest  = File.join(MEMORY_EXPORT_DIR, label)
        File.write(dest, @emulator.wram_hex_dump)
        puts "[memory] Saved → #{dest}"
        dest
      end
    end
  end
end
