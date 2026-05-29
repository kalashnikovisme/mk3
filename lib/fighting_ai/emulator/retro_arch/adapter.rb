require "securerandom"
require_relative "../adapter"
require_relative "process"
require_relative "network_commands"
require_relative "config_builder"
require_relative "frame_grabber"
require_relative "wram_reader"

module FightingAI
  module Emulator
    module RetroArch
      class Adapter < FightingAI::Emulator::Adapter
        # 6 SNES frames at 60 fps ≈ 100 ms per agent decision step.
        STEP_DURATION     = 1.0 / 60.0 * 6
        STARTUP_WAIT      = 3.0
        WRAM_SCAN_INTERVAL = 0.5

        attr_reader :pid

        def initialize(rom_path:, core_path:, config_path:, keyboard:, frame_grabber:, wram_reader:, display: ":1")
          @process       = Process.new(
            rom_path:    rom_path,
            core_path:   core_path,
            config_path: config_path,
            display:     display
          )
          @keyboard      = keyboard
          @frame_grabber = frame_grabber
          @wram_reader   = wram_reader
          @frame_counter = 0
          @started       = false
        end

        def start
          @process.start
          @started = true
          @keyboard.start
          sleep(STARTUP_WAIT)
          @wram_reader.attach(@process.pid)
        end

        def stop
          [1, 2].each { |p| @keyboard.release_all(p) rescue nil }
          @keyboard.stop rescue nil
          @wram_reader.detach
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
          until @wram_reader.wram_found?
            raise "WRAM not found within #{timeout}s" if Time.now > deadline
            @wram_reader.scan_for_wram
            sleep(WRAM_SCAN_INTERVAL) unless @wram_reader.wram_found?
          end
        end

        def next_frame_snapshot
          sleep(STEP_DURATION)
          @frame_counter += 1
          read_mk3_snapshot(@frame_counter)
        end

        def send_input(player_index, buttons)
          @keyboard.send_input(player_index, buttons)
        end

        def send_noop
          [1, 2].each { |p| @keyboard.release_all(p) }
          sleep(STEP_DURATION)
        end

        def capture_frame
          @frame_grabber.capture
        end

        def save_state(slot)
          NetworkCommands.save_state(slot)
        end

        def load_save_state(slot)
          NetworkCommands.load_state(slot)
        end

        def reset
          NetworkCommands.reset
        end

        def read_memory(address, byte_count: 1)
          if byte_count == 1
            @wram_reader.read_u8(address)
          elsif byte_count == 2
            @wram_reader.read_u16_le(address)
          else
            raise ArgumentError, "read_memory supports byte_count 1 or 2"
          end
        end

        private

        def read_mk3_snapshot(frame_num)
          w = @wram_reader
          {
            "type"       => "frame",
            "frame"      => frame_num,
            "game"       => "mortal_kombat_3",
            "game_state" => w.read_u8(0x0101),
            "round"      => w.read_u8(0x018A),
            "timer"      => w.read_u8(0x01A0),
            "match_over" => false,
            "players"    => {
              "1" => {
                "health"     => w.read_u8(0x011A),
                "max_health" => w.read_u8(0x011C),
                "x"          => w.read_u16_le(0x0120),
                "y"          => w.read_u16_le(0x0122),
                "facing"     => w.read_u8(0x0126),
                "anim"       => w.read_u8(0x012A),
                "anim_frame" => w.read_u8(0x012C),
                "state"      => w.read_u8(0x0130)
              },
              "2" => {
                "health"     => w.read_u8(0x014A),
                "max_health" => w.read_u8(0x014C),
                "x"          => w.read_u16_le(0x0150),
                "y"          => w.read_u16_le(0x0152),
                "facing"     => w.read_u8(0x0156),
                "anim"       => w.read_u8(0x015A),
                "anim_frame" => w.read_u8(0x015C),
                "state"      => w.read_u8(0x0160)
              }
            }
          }
        end
      end
    end
  end
end
