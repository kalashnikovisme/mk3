require_relative "input_map"
require_relative "characters"
require_relative "memory_map"

module FightingAI
  module Game
    module MortalKombat3
      # Drives BizHawk through MK3 menus autonomously.
      # All navigation is implemented as timed button press sequences.
      class MenuNavigator
        FRAME_DELAY = 6  # frames to hold each navigation button

        # Number of columns in the character select grid
        GRID_COLS = 5

        def initialize(emulator_adapter)
          @emulator = emulator_adapter
        end

        # Press a button for hold_frames then release.
        def press(player_index, *buttons, hold_frames: FRAME_DELAY)
          bizhawk_buttons = InputMap.to_bizhawk(buttons, player_index: player_index)
          hold_frames.times { @emulator.send_input(player_index, bizhawk_buttons) }
          @emulator.send_input(player_index, InputMap.all_released(player_index: player_index))
        end

        # Wait N frames sending no input.
        def wait(frames)
          frames.times { @emulator.send_noop }
        end

        # Navigate main menu to Player vs Player mode.
        # MK3 SNES: from main menu, select "2 Player" then confirm.
        def navigate_to_versus_mode
          wait(30)
          press(1, :down)          # highlight "2 Player"
          wait(10)
          press(1, :low_punch)     # confirm
          wait(30)
        end

        # Select a character on the selection screen.
        # Moves cursor from position 0 to target cursor_index.
        def select_character(player_index, character_name, from_index: 0)
          target = Characters.cursor_index_for(character_name)
          navigate_cursor(player_index, from: from_index, to: target)
          wait(10)
          press(player_index, :low_punch)  # confirm selection
          wait(10)
        end

        # Wait until the fight has actually started (game_state flag changes).
        # Yields each raw snapshot; returns when fight_active? is true.
        def wait_for_fight_start(game_adapter, timeout_frames: 600)
          timeout_frames.times do
            snapshot = @emulator.next_frame_snapshot
            game_state = game_adapter.extract_game_state(snapshot)
            return true if game_adapter.fight_active?(game_state)
            @emulator.send_noop
          end
          raise "Fight did not start within #{timeout_frames} frames"
        end

        private

        def navigate_cursor(player_index, from:, to:)
          from_row, from_col = from.divmod(GRID_COLS)
          to_row,   to_col   = to.divmod(GRID_COLS)

          row_delta = to_row - from_row
          col_delta = to_col - from_col

          row_delta.abs.times do
            press(player_index, row_delta.positive? ? :down : :up)
          end

          col_delta.abs.times do
            press(player_index, col_delta.positive? ? :right : :left)
          end
        end
      end
    end
  end
end
