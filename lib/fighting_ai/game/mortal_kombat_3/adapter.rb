require_relative "../adapter"
require_relative "memory_map"
require_relative "input_map"
require_relative "action_space"
require_relative "observation_space"
require_relative "reward_function"
require_relative "state_extractor"
require_relative "menu_navigator"
require_relative "characters"

module FightingAI
  module Game
    module MortalKombat3
      class Adapter < FightingAI::Game::Adapter
        GAME_ID             = :mortal_kombat_3
        VERSUS_SAVE_STATE   = 1  # BizHawk save state slot with versus mode ready
        FIGHT_START_TIMEOUT = 600 # frames

        def initialize(emulator_adapter:, game_definition:, reward_weights: {})
          super(emulator_adapter: emulator_adapter, game_definition: game_definition)
          @reward_function = RewardFunction.new(weights: reward_weights)
          @navigator       = MenuNavigator.new(emulator_adapter)
        end

        # -----------------------------------------------------------------------
        # State extraction
        # -----------------------------------------------------------------------

        def extract_game_state(raw_snapshot)
          StateExtractor.extract(raw_snapshot)
        end

        def build_observation(game_state, player_index:)
          ObservationSpace.build(game_state, player_index: player_index)
        end

        # -----------------------------------------------------------------------
        # Action translation
        # -----------------------------------------------------------------------

        def action_to_input_sequence(action, player_index:, game_state:)
          seq = ActionSpace.to_input_sequence(action.name, player_index: player_index)

          # Flip left/right when player is facing left so "walk_forward" always
          # means "toward the opponent" regardless of screen side.
          if action.name.to_s.start_with?("walk_") || action.name == :jump_forward
            fighter = game_state.fighter_for(player_index)
            seq = flip_direction(seq) if fighter.facing.left?
          end

          seq
        end

        def input_sequence_to_buttons(input_sequence, player_index:, frame_offset: 0)
          frame_buttons = input_sequence.to_button_frames
          logical = frame_buttons[frame_offset] || []
          return InputMap.all_released(player_index: player_index) if logical.empty?
          InputMap.to_bizhawk(logical, player_index: player_index)
        end

        # -----------------------------------------------------------------------
        # Reward
        # -----------------------------------------------------------------------

        def calculate_reward(prev_game_state, next_game_state, player_index:)
          @reward_function.call(prev_game_state, next_game_state, player_index: player_index)
        end

        # -----------------------------------------------------------------------
        # Match lifecycle
        # -----------------------------------------------------------------------

        def start_game
          # Game is assumed to already be running in BizHawk.
          # Load the main menu save state if provided.
          @navigator.wait(60)
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
            # Requires the emulator adapter to support process restart — not implemented here.
            raise NotImplementedError, "Game restart strategy not yet implemented"
          else
            raise ArgumentError, "Unknown reset strategy: #{strategy}"
          end
        end

        # -----------------------------------------------------------------------
        # Character registry
        # -----------------------------------------------------------------------

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
