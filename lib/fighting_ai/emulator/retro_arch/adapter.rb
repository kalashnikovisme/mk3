require "securerandom"
require_relative "../adapter"
require_relative "process"
require_relative "network_commands"
require_relative "config_builder"
require_relative "frame_grabber"
require_relative "save_state_reader"

module FightingAI
  module Emulator
    module RetroArch
      class Adapter < FightingAI::Emulator::Adapter
        # 6 SNES frames at 60 fps ≈ 100 ms per agent decision step.
        STEP_DURATION   = 1.0 / 60.0 * 6
        FRAME_DURATION  = 1.0 / 60.0
        STARTUP_WAIT    = 6.0
        WRAM_RETRY_WAIT = 1.0

        attr_reader :pid

        def initialize(rom_path:, core_path:, config_path:, keyboard:, frame_grabber:, save_state_reader:, display: ":1")
          @process           = Process.new(
            rom_path:    rom_path,
            core_path:   core_path,
            config_path: config_path,
            display:     display
          )
          @rom_basename      = File.basename(rom_path, ".*")
          @keyboard          = keyboard
          @frame_grabber     = frame_grabber
          @save_state_reader = save_state_reader
          @frame_counter     = 0
          @started           = false
        end

        def start
          @process.start
          @started = true
          sleep(STARTUP_WAIT)
          @keyboard.start(pid: @process.pid)
        end

        def stop
          [1, 2].each { |p| @keyboard.release_all(p) rescue nil }
          @keyboard.stop rescue nil
          NetworkCommands.quit rescue nil
          sleep(0.5)
          @process.stop
          @started = false
        end

        def started?
          @started && @process.running?
        end

        def connected?
          started?
        end

        def pid
          @process.pid
        end

        def wait_for_wram(timeout: 30)
          deadline = Time.now + timeout
          until @save_state_reader.wram_located?
            unless @process.running?
              puts
              raise "RetroArch exited unexpectedly.\n\n" \
                    "RetroArch log (#{RetroArch::Process::LOG_PATH}):\n" \
                    "#{@process.last_log_lines(40)}"
            end
            if Time.now > deadline
              puts
              raise "Could not locate MK3 WRAM within #{timeout}s.\n\n" \
                    "RetroArch log (#{RetroArch::Process::LOG_PATH}):\n" \
                    "#{@process.last_log_lines(40)}"
            end
            NetworkCommands.save_state
            sleep(WRAM_RETRY_WAIT)
            @save_state_reader.try_locate_any
            print "." unless @save_state_reader.wram_located?
            $stdout.flush
          end
          puts
        end

        def next_frame_snapshot
          sleep(STEP_DURATION)
          @frame_counter += 1
          wram = capture_state_snapshot
          build_mk3_snapshot(@frame_counter, wram)
        end

        def send_input(player_index, buttons)
          @keyboard.send_input(player_index, buttons)
        end

        def send_noop
          [1, 2].each { |p| @keyboard.release_all(p) }
          sleep(FRAME_DURATION)
        end

        def capture_frame
          @frame_grabber.capture
        end

        def save_state(slot = nil)
          NetworkCommands.save_state(slot: slot)
        end

        def load_save_state(slot = nil)
          NetworkCommands.load_state(slot: slot)
        end

        def install_match_state(src_path)
          dest = slot0_state_path
          FileUtils.mkdir_p(File.dirname(dest))
          FileUtils.cp(src_path, dest)
          NetworkCommands.load_state(slot: 0)
          sleep(0.5)
        end

        def slot0_state_path
          # RetroArch organises saves under a core-named subdirectory (e.g. Snes9x/).
          # Find the most recently modified mk3.state anywhere under STATES_DIR.
          candidates = Dir.glob(File.join(ConfigBuilder::STATES_DIR, "**", "#{@rom_basename}.state"))
          candidates.max_by { |f| File.mtime(f) rescue Time.at(0) } ||
            File.join(ConfigBuilder::STATES_DIR, "#{@rom_basename}.state")
        end

        def reset
          NetworkCommands.reset
        end

        def wram_dump(from: 0x0000, to: 0x1FFF)
          snapshot = capture_state_snapshot
          (from..to).map { |addr| snapshot.read_u8(addr) }
        end

        def read_memory(address, byte_count: 1)
          wram = capture_state_snapshot
          if byte_count == 1
            wram.read_u8(address)
          elsif byte_count == 2
            wram.read_u16_le(address)
          else
            raise ArgumentError, "read_memory supports byte_count 1 or 2"
          end
        end

        private

        def capture_state_snapshot
          before = @save_state_reader.current_state_snapshot
          NetworkCommands.save_state
          @save_state_reader.read_next(before: before)
        end

        def build_mk3_snapshot(frame_num, wram)
          {
            "type"    => "frame",
            "frame"   => frame_num,
            "game"    => "mortal_kombat_3",
            "screen"  => wram.read_u8(0x3A7E),
            "timer"   => wram.read_u8(0x3BD4),
            "players" => {
              "1" => {
                "health"     => wram.read_u8(0x36D4),
                "max_health" => 0xA6,
                "rounds_won" => wram.read_u8(0x36E0),
                "x"          => 0,
                "y"          => 0,
                "facing"     => 0,
                "anim"       => 0,
                "anim_frame" => 0,
                "state"      => 0
              },
              "2" => {
                "health"     => wram.read_u8(0x3898),
                "max_health" => 0xA6,
                "rounds_won" => wram.read_u8(0x38A4),
                "x"          => 0,
                "y"          => 0,
                "facing"     => 0,
                "anim"       => 0,
                "anim_frame" => 0,
                "state"      => 0
              }
            }
          }
        end
      end
    end
  end
end
