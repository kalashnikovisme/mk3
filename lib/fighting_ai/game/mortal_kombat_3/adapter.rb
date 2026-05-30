require_relative "../adapter"
require_relative "memory_map"
require_relative "input_map"
require_relative "action_space"
require_relative "observation_space"
require_relative "reward_function"
require_relative "state_extractor"
require_relative "menu_navigator"
require_relative "characters"
require_relative "characters/sub_zero"

module FightingAI
  module Game
    module MortalKombat3
      class Adapter < FightingAI::Game::Adapter
        GAME_ID             = :mortal_kombat_3
        VERSUS_SAVE_STATE   = 1
        FIGHT_START_TIMEOUT = 600

        def initialize(emulator_adapter:, game_definition:, reward_weights: {})
          super(emulator_adapter: emulator_adapter, game_definition: game_definition)
          @reward_function = RewardFunction.new(weights: reward_weights)
          @navigator       = MenuNavigator.new(emulator_adapter)
        end

        def describe_snapshot(raw_snapshot)
          screen = raw_snapshot["screen"].to_i
          timer  = raw_snapshot["timer"].to_i
          hp1    = raw_snapshot.dig("players", "1", "health").to_i
          hp2    = raw_snapshot.dig("players", "2", "health").to_i
          "#{MemoryMap.stage_name(screen)}  timer=#{timer}  hp1=#{hp1} hp2=#{hp2}"
        end

        def snapshot_stage_name(raw_snapshot)
          MemoryMap.stage_name(raw_snapshot["screen"].to_i)
        end

        def extract_game_state(raw_snapshot)
          StateExtractor.extract(raw_snapshot)
        end

        def build_observation(game_state, player_index:)
          ObservationSpace.build(game_state, player_index: player_index)
        end

        DIRECTION_SENSITIVE_ACTIONS = (
          %i[walk_forward walk_back jump_forward] + SubZero::DIRECTION_SENSITIVE_MOVES
        ).freeze

        def action_to_input_sequence(action, player_index:, game_state:)
          seq = ActionSpace.to_input_sequence(action.name, player_index: player_index)

          if DIRECTION_SENSITIVE_ACTIONS.include?(action.name)
            fighter = game_state.fighter_for(player_index)
            seq = flip_direction(seq) if fighter.facing.left?
          end

          seq
        end

        def input_sequence_to_buttons(input_sequence, player_index:, frame_offset: 0)
          frame_buttons = input_sequence.to_button_frames
          logical = frame_buttons[frame_offset] || []
          return InputMap.all_released if logical.empty?
          InputMap.to_logical(logical, player_index: player_index)
        end

        def calculate_reward(prev_game_state, next_game_state, player_index:, stale: false)
          @reward_function.call(prev_game_state, next_game_state, player_index: player_index, stale: stale)
        end

        def read_memory_debug
          mm = MemoryMap
          {
            screen:     emulator_adapter.read_memory(mm::SCREEN_ADDR),
            timer:      emulator_adapter.read_memory(mm::LEVEL_TIMER_ADDR),
            p1_health:  emulator_adapter.read_memory(mm::P1_HEALTH_ADDR),
            p2_health:  emulator_adapter.read_memory(mm::P2_HEALTH_ADDR),
            p1_rounds:  emulator_adapter.read_memory(mm::P1_ROUNDS_WON),
            p2_rounds:  emulator_adapter.read_memory(mm::P2_ROUNDS_WON)
          }
        end

        def start_game
          # No-op: bin/learn loads match states directly via emulator.install_match_state
        end

        def open_player_vs_player_mode
          @navigator.navigate_to_versus_mode
        end

        def select_characters(player1_character:, player2_character:)
          @navigator.select_character(1, player1_character)
          @navigator.select_character(2, player2_character)
          @navigator.wait(60)
        end

        def wait_for_fight_start(timeout: FIGHT_START_TIMEOUT)
          @navigator.wait_for_fight_start(self, timeout_frames: timeout)
        end

        def fight_active?(game_state)
          game_state.fight_active?
        end

        def fight_finished?(game_state)
          game_state.match_over?
        end

        def collect_match_result(match)
          last_state = match.current_round&.last_game_state
          return {} if last_state.nil?

          {
            winner:             match.winner,
            player1_rounds_won: match.player1_rounds_won,
            player2_rounds_won: match.player2_rounds_won,
            stale_rounds:       match.stale_rounds,
            total_frames:       match.total_frames,
            final_health_p1:    last_state.fighter1.health,
            final_health_p2:    last_state.fighter2.health
          }
        end

        def reset_for_next_match(strategy: :load_save_state)
          case strategy
          when :load_save_state
            emulator_adapter.load_save_state(VERSUS_SAVE_STATE)
            @navigator.wait(30)
          when :restart_game
            raise NotImplementedError, "Game restart strategy not yet implemented"
          else
            raise ArgumentError, "Unknown reset strategy: #{strategy}"
          end
        end

        def characters
          Characters.all
        end

        def character_pools
          Characters::POOLS
        end

        private

        def flip_direction(input_sequence)
          flipped = Core::InputSequence.new
          input_sequence.entries.each do |entry|
            flipped_buttons = entry.buttons.map do |btn|
              case btn
              when :left  then :right
              when :right then :left
              else btn
              end
            end
            flipped.press(flipped_buttons, hold_frames: entry.hold_frames)
          end
          flipped
        end
      end
    end
  end
end
