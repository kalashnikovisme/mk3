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
require_relative "../../vision/character_position_detector"
require_relative "../../vision/health_bar_detector"

module FightingAI
  module Game
    module MortalKombat3
      class Adapter < FightingAI::Game::Adapter
        GAME_ID             = :mortal_kombat_3
        VERSUS_SAVE_STATE   = 1
        FIGHT_START_TIMEOUT = 600
        PLAYER_ONE          = 1
        PLAYER_TWO          = 2
        MIDPOINT_DIVISOR    = 2
        SUB_ZERO_CHARACTER  = :sub_zero

        P1_HEALTH_BAR = Vision::HealthBarDetector::BarConfig.new(
          x: 19, y: 19, width: 112, height: 10, direction: :left_to_right
        ).freeze
        P2_HEALTH_BAR = Vision::HealthBarDetector::BarConfig.new(
          x: 168, y: 19, width: 112, height: 10, direction: :right_to_left
        ).freeze

        def initialize(emulator_adapter:, game_definition:, reward_weights: {}, vision_detector: nil)
          super(emulator_adapter: emulator_adapter, game_definition: game_definition)
          @reward_function  = RewardFunction.new(weights: reward_weights)
          @navigator        = MenuNavigator.new(emulator_adapter)
          @vision_detector  = vision_detector
          @health_detector  = Vision::HealthBarDetector.new(
            bar1:       P1_HEALTH_BAR,
            bar2:       P2_HEALTH_BAR,
            max_health: MemoryMap::MAX_HEALTH
          )
          @vision_characters = {}
        end

        def describe_snapshot(raw_snapshot)
          MemoryMap.stage_name(raw_snapshot["screen"].to_i)
        end

        def snapshot_stage_name(raw_snapshot)
          MemoryMap.stage_name(raw_snapshot["screen"].to_i)
        end

        def vision_enabled?
          @vision_detector&.available?
        end

        def configure_vision_characters(player1_character:, player2_character:)
          @vision_characters = {
            PLAYER_ONE => player1_character.to_sym,
            PLAYER_TWO => player2_character.to_sym
          }
        end

        def extract_game_state(raw_snapshot, frame_observation: nil)
          vision = vision_detect(frame_observation)
          health = frame_observation ? @health_detector.detect(frame_observation) : nil
          StateExtractor.extract(
            raw_snapshot,
            vision_positions: vision&.fetch(:positions),
            vision_timer:     vision&.fetch(:timer),
            vision_health:    health
          )
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

        def all_button_frames(input_sequence, player_index:)
          input_sequence.to_button_frames.map do |logical|
            logical.empty? ? InputMap.all_released : InputMap.to_logical(logical, player_index: player_index)
          end
        end


        def calculate_reward(prev_game_state, next_game_state, player_index:, stale: false, round_over: false)
          @reward_function.call(prev_game_state, next_game_state, player_index: player_index, stale: stale, round_over: round_over)
        end

        def read_memory_debug
          mm = MemoryMap
          {
            screen:    emulator_adapter.read_memory(mm::SCREEN_ADDR),
            p1_rounds: emulator_adapter.read_memory(mm::P1_ROUNDS_WON),
            p2_rounds: emulator_adapter.read_memory(mm::P2_ROUNDS_WON)
          }
        end

        def detect_timer(frame_observation)
          return nil unless vision_enabled? && frame_observation

          @vision_detector.detect(frame_observation)[:timer]
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

        def vision_detect(frame_observation)
          return nil unless vision_enabled? && frame_observation

          result       = @vision_detector.detect(frame_observation)
          image_width  = result.fetch(:image_width)
          image_height = result.fetch(:image_height)
          positions    = assign_vision_positions(result[:detections], image_width: image_width, image_height: image_height)
          { positions: positions, timer: result[:timer] }
        end

        def assign_vision_positions(detections, image_width:, image_height:)
          return nil if detections.empty?

          sub_zero_players = @vision_characters.select { |_, character| character == SUB_ZERO_CHARACTER }.keys
          player_positions = {}

          if sub_zero_players.size == PLAYER_TWO && detections.size >= PLAYER_TWO
            player_positions[PLAYER_ONE] = scale_detection(detections.first, image_width, image_height)
            player_positions[PLAYER_TWO] = scale_detection(detections.last, image_width, image_height)
          elsif sub_zero_players.size == PLAYER_ONE
            player_positions[sub_zero_players.first] = scale_detection(detections.max_by(&:confidence), image_width, image_height)
          elsif detections.size >= PLAYER_TWO
            player_positions[PLAYER_ONE] = scale_detection(detections.first, image_width, image_height)
            player_positions[PLAYER_TWO] = scale_detection(detections.last, image_width, image_height)
          else
            inferred_player = detections.first.center_x <= image_width / MIDPOINT_DIVISOR ? PLAYER_ONE : PLAYER_TWO
            player_positions[inferred_player] = scale_detection(detections.first, image_width, image_height)
          end

          player_positions
        end

        def scale_detection(detection, image_width, image_height)
          Vision::CharacterPositionDetector.scale_position(
            detection,
            image_width: image_width,
            image_height: image_height,
            x_max: MemoryMap::X_MAX,
            y_max: MemoryMap::Y_MAX
          )
        end

        def flip_direction(input_sequence)
          flipped = Core::InputSequence.new
          input_sequence.entries.each do |entry|
            flipped_buttons = entry.buttons.map do |btn|
              case btn
              when :left    then :right
              when :right   then :left
              when :forward then :back
              when :back    then :forward
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
