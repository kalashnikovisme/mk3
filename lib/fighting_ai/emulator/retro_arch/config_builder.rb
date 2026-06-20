require "tmpdir"
require "fileutils"

module FightingAI
  module Emulator
    module RetroArch
      module ConfigBuilder
        SCREENSHOT_DIR  = "/tmp/fighting_ai/screenshots"
        STATES_DIR      = "/tmp/fighting_ai/states"
        NATIVE_VIDEO_SCALE = 1.0
        AUDIO_DRIVER       = "pulse"

        def self.build(core_path:)
          FileUtils.mkdir_p(SCREENSHOT_DIR)
          FileUtils.mkdir_p(STATES_DIR)
          path = File.join(Dir.tmpdir, "fighting_ai_retroarch_#{SecureRandom.hex(4)}.cfg")
          File.write(path, config(core_path))
          path
        end

        def self.config(core_path)
          <<~CFG
            network_cmd_enable = "true"
            network_cmd_port = "55355"
            video_driver = "gl"
            input_driver = "x11"
            video_fullscreen = "false"
            video_windowed_fullscreen = "false"
            video_scale = "#{format('%.1f', NATIVE_VIDEO_SCALE)}"
            video_scale_integer = "true"
            video_window_show_decorations = "false"
            video_smooth = "false"
            audio_driver = "#{AUDIO_DRIVER}"
            audio_sync = "true"
            libretro_path = "#{core_path}"
            savestate_auto_load = "false"
            savestate_auto_save = "false"
            savestate_directory = "#{STATES_DIR}"
            sort_savestates_enable = "false"
            sort_savestates_by_content_enable = "false"
            input_enable_hotkey = "nul"
            input_load_state = "f4"
            input_toggle_fullscreen = "nul"
            input_reset = "nul"
            input_pause_toggle = "nul"
            input_rewind = "nul"
            input_hold_fast_forward = "nul"
            input_toggle_fast_forward = "nul"
            input_game_focus_toggle = "nul"
            input_player1_a = "z"
            input_player1_b = "x"
            input_player1_x = "a"
            input_player1_y = "s"
            input_player1_l = "q"
            input_player1_r = "w"
            input_player1_up = "up"
            input_player1_down = "down"
            input_player1_left = "left"
            input_player1_right = "right"
            input_player1_start = "enter"
            input_player1_select = "rshift"
            input_player2_a = "v"
            input_player2_b = "b"
            input_player2_x = "c"
            input_player2_y = "n"
            input_player2_l = "r"
            input_player2_r = "y"
            input_player2_up = "t"
            input_player2_down = "g"
            input_player2_left = "f"
            input_player2_right = "h"
            input_player2_start = "p"
            input_player2_select = "o"
          CFG
        end

        def self.states_dir
          STATES_DIR
        end
      end
    end
  end
end
