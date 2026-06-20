require "securerandom"
require_relative "../adapter"
require_relative "process"
require_relative "network_commands"
require_relative "config_builder"
require_relative "frame_grabber"
require_relative "save_state_reader"
require_relative "xvfb_server"
require_relative "xephyr_server"

module FightingAI
  module Emulator
    module RetroArch
      class Adapter < FightingAI::Emulator::Adapter
        FRAMES_PER_SECOND = 60
        FRAME_DURATION    = 1.0 / FRAMES_PER_SECOND
        STEP_DURATION     = FRAME_DURATION * AdapterConfig.new.step_frames
        STARTUP_WAIT    = 6.0
        LOAD_STATE_WAIT = 1.0
        MATCH_STATE_SLOT = 0

        PULSEAUDIO_NULL_SINK_NAME = "retro_null"
        PULSEAUDIO_START_CMD      = ["pulseaudio", "--start", "--exit-idle-time=-1"].freeze
        PULSEAUDIO_LOAD_NULL_CMD  = ["pactl", "load-module", "module-null-sink",
                                     "sink_name=#{PULSEAUDIO_NULL_SINK_NAME}"].freeze
        PULSEAUDIO_SET_DEFAULT_CMD = ["pactl", "set-default-sink",
                                      PULSEAUDIO_NULL_SINK_NAME].freeze
        PULSEAUDIO_STARTUP_WAIT   = 0.5

        attr_reader :pid, :display

        def initialize(rom_path:, core_path:, config_path:, keyboard:, frame_grabber:, save_state_reader:, display: ":1", display_server: nil, verbose: true)
          @display_server    = display_server
          @process           = Process.new(
            rom_path:    rom_path,
            core_path:   core_path,
            config_path: config_path,
            display:     display,
            verbose:     verbose
          )
          @rom_basename      = File.basename(rom_path, ".*")
          @keyboard          = keyboard
          @frame_grabber     = frame_grabber
          @save_state_reader = save_state_reader
          @display           = display
          @verbose           = verbose
          @frame_counter     = 0
          @started           = false
        end

        DIR_PERMISSION_CHECK = [
          "/tmp/fighting_ai/states",
          "/app",
          "/root/.config/retroarch/states",
          "/app/data/matches"
        ].freeze

        def start
          start_null_audio
          @display_server&.start
          @process.start
          @started = true
          if @verbose
            puts "Directory permissions:"
            DIR_PERMISSION_CHECK.each do |dir|
              if Dir.exist?(dir)
                mode = format("%o", File.stat(dir).mode & 0o777)
                puts "  #{mode}  #{dir}"
              else
                puts "  ------  #{dir} (does not exist)"
              end
            end
          end
          sleep(STARTUP_WAIT)
          @keyboard.start(pid: @process.pid)
        end

        def stop
          [1, 2].each { |p| @keyboard.release_all(p) rescue nil }
          @keyboard.stop rescue nil
          NetworkCommands.quit rescue nil
          sleep(0.5)
          @process.stop
          @frame_grabber.stop
          @display_server&.stop
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

        def next_frame_snapshot
          sleep(STEP_DURATION)
          @frame_counter += 1
          build_mk3_snapshot(@frame_counter)
        end

        def send_input(player_index, buttons)
          @keyboard.send_input(player_index, buttons)
        end

        def send_input_sequence(player_index, frame_buttons_array)
          frame_buttons_array.each do |buttons|
            @keyboard.send_input(player_index, buttons)
            sleep(FRAME_DURATION)
          end
        end

        def send_noop
          [1, 2].each { |p| @keyboard.release_all(p) }
          sleep(FRAME_DURATION)
        end

        def capture_frame
          @frame_grabber.capture(display: @display)
        end

        def pause
          NetworkCommands.pause
          sleep(FRAME_DURATION)
        end

        def unpause
          NetworkCommands.unpause
          sleep(FRAME_DURATION)
        end

        def frame_advance
          NetworkCommands.frame_advance
          sleep(FRAME_DURATION)
        end

        def save_state(slot = nil)
          NetworkCommands.save_state(slot: slot)
        end

        def load_save_state(slot = nil)
          NetworkCommands.load_state(slot: slot)
        end

        def install_match_state(src_path, wait: true)
          dest = slot0_state_path
          FileUtils.mkdir_p(File.dirname(dest))
          FileUtils.cp(src_path, dest)
          NetworkCommands.load_state(slot: MATCH_STATE_SLOT)
          sleep(LOAD_STATE_WAIT) if wait
        end

        def install_match_state_paused(src_path)
          dest = slot0_state_path
          FileUtils.mkdir_p(File.dirname(dest))
          FileUtils.cp(src_path, dest)
          NetworkCommands.load_state_and_pause(slot: MATCH_STATE_SLOT)
          sleep(LOAD_STATE_WAIT)
        end

        def slot0_state_path
          File.join(ConfigBuilder::STATES_DIR, "#{@rom_basename}.state")
        end

        def reset
          NetworkCommands.reset
        end

        def wram_binary_dump
          capture_state_snapshot.raw_wram
        end

        def wram_source_info
          @save_state_reader.wram_source_info
        end

        def wram_dump(from: 0x0000, to: 0x1FFF)
          snapshot = capture_state_snapshot
          (from..to).map { |addr| snapshot.read_u8(addr) }
        end

        def wram_hex_dump
          snapshot = capture_state_snapshot
          lines = []
          (0x0000..0x1FFFF).step(16) do |base|
            row = (0..15).map { |i| snapshot.read_u8(base + i) }
            next if row.all?(&:zero?)
            values = row.map { |b| "%02X" % b }.join(" ")
            lines << "%04X: %s" % [base, values]
          end
          lines.join("\n")
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

        def start_null_audio
          system(*PULSEAUDIO_START_CMD, out: File::NULL, err: File::NULL)
          sleep(PULSEAUDIO_STARTUP_WAIT)
          system(*PULSEAUDIO_LOAD_NULL_CMD, out: File::NULL, err: File::NULL)
          system(*PULSEAUDIO_SET_DEFAULT_CMD, out: File::NULL, err: File::NULL)
        end

        def capture_state_snapshot
          before = @save_state_reader.current_state_snapshot
          NetworkCommands.save_state(slot: WRAM_READ_SLOT)
          @save_state_reader.read_after_update(before)
        rescue RuntimeError
          @save_state_reader.read_current
        end

        def build_mk3_snapshot(frame_num)
          {
            "type"  => "frame",
            "frame" => frame_num,
            "game"  => "mortal_kombat_3"
          }
        end
      end
    end
  end
end
