require_relative "../../fighting_ai"

module FightingAI
  module CLI
    BANNER = <<~TEXT
      ┌─────────────────────────────────────────┐
      │         FightingAI Framework            │
      │   Mortal Kombat 3  ·  RetroArch         │
      └─────────────────────────────────────────┘
    TEXT

    def self.start_retro_arch(rom_path:, core_path:, display: ":1", extra_watch_dirs: [])
      config_path       = Emulator::RetroArch::ConfigBuilder.build(core_path: core_path)
      keyboard          = Input::KeyboardInput.new
      frame_grabber     = Emulator::RetroArch::FrameGrabber.new
      save_state_reader = Emulator::RetroArch::SaveStateReader.new(
        watch_dirs:   ([
          Emulator::RetroArch::ConfigBuilder.states_dir,
          File.dirname(File.expand_path(rom_path)),
          File.expand_path("~/.config/retroarch/states")
        ] + extra_watch_dirs).uniq,
        rom_basename: File.basename(rom_path, ".*")
      )

      adapter = Emulator::RetroArch::Adapter.new(
        rom_path:          rom_path,
        core_path:         core_path,
        config_path:       config_path,
        keyboard:          keyboard,
        frame_grabber:     frame_grabber,
        save_state_reader: save_state_reader,
        display:           display
      )

      puts "Starting RetroArch..."
      adapter.start
      puts "RetroArch started (PID #{adapter.pid}). Scanning for game memory..."
      adapter.wait_for_wram(timeout: 30)
      puts "Game memory found. Ready.\n\n"
      adapter
    end

    def self.logger(prefix)
      ->(msg) { puts "[#{prefix}] #{msg}" }
    end

    def self.print_result(match, result)
      winner = result[:winner] ? "Player #{result[:winner]}" : "Draw"
      puts "  Winner:  #{winner}"
      puts "  Rounds:  P1 #{result[:player1_rounds_won]} – #{result[:player2_rounds_won]} P2"
      puts "  Frames:  #{match.total_frames}"
      puts "  HP left: P1=#{result[:final_health_p1]} P2=#{result[:final_health_p2]}"
    end

    def self.trap_sigint(cleanup: nil)
      Signal.trap("INT") do
        puts "\n\nStopped."
        cleanup&.call
        exit 0
      end
    end
  end
end
