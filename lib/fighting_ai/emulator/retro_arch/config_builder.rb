require "tmpdir"
require "fileutils"

module FightingAI
  module Emulator
    module RetroArch
      module ConfigBuilder
        SCREENSHOT_DIR  = "/tmp/fighting_ai/screenshots"
        STATES_DIR      = "/tmp/fighting_ai/states"

        CONFIG_TEMPLATE = <<~CFG
          network_cmd_enable = "true"
          network_cmd_port = "55355"
          video_fullscreen = "false"
          savestate_auto_load = "true"
          savestate_auto_save = "false"
          screenshot_directory = "#{SCREENSHOT_DIR}"
          savestate_directory = "#{STATES_DIR}"
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

        def self.build
          FileUtils.mkdir_p(SCREENSHOT_DIR)
          FileUtils.mkdir_p(STATES_DIR)
          path = File.join(Dir.tmpdir, "fighting_ai_retroarch_#{SecureRandom.hex(4)}.cfg")
          File.write(path, CONFIG_TEMPLATE)
          path
        end

        def self.states_dir
          STATES_DIR
        end
      end
    end
  end
end
