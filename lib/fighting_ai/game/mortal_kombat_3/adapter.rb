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
require_relative "../../vision/async_vision_scanner"

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
          @async_scanner    = vision_detector ? Vision::AsyncVisionScanner.new(vision_detector) : nil
          @health_detector  = Vision::HealthBarDetector.new(
            bar1:       P1_HEALTH_BAR,
            bar2:       P2_HEALTH_BAR,
            max_health: MemoryMap::MAX_HEALTH
          )
          @vision_characters      = {}
          @latest_vision_actions  = {}
          @bootstrap_done         = false
          @cached_positions       = nil
          @cached_timer           = nil
        end

        def vision_enabled?
          @vision_detector&.available?
        end

        def latest_vision_actions
          @latest_vision_actions
        end

        def latest_vision_areas
          @latest_vision_areas
        end

        def configure_vision_characters(player1_character:, player2_character:)
          @vision_characters = {
            PLAYER_ONE => player1_character.to_sym,
            PLAYER_TWO => player2_character.to_sym
          }
          @latest_vision_actions = {}
          @latest_vision_areas = nil
          @cached_positions = nil
          @cached_timer = nil
          @bootstrap_done = false
        end

        def extract_game_state(frame_number, frame_observation: nil)
          health = frame_observation ? @health_detector.detect(frame_observation) : nil

          vision = nil
          if frame_observation && @async_scanner
            raw = if @bootstrap_done
              @async_scanner.submit(frame_observation)
              @async_scanner.latest_result
            else
              @bootstrap_done = true
              @vision_detector.detect(frame_observation)
            end
            vision = apply_vision_result(raw)
          end

          StateExtractor.extract(
            frame_number,
            vision_positions: vision&.fetch(:positions),
            vision_timer:     vision&.fetch(:timer),
            vision_health:    health
          )
        end

        def build_observation(game_state, player_index:)
          ObservationSpace.build(game_state, player_index: player_index)
        end

        def action_to_input_sequence(action, player_index:, game_state:)
          ActionSpace.to_input_sequence(action.name, player_index: player_index)
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

        def detect_timer(frame_observation)
          return nil unless vision_enabled? && frame_observation

          @async_scanner&.latest_result&.dig(:timer)
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

        def apply_vision_result(raw)
          @latest_vision_actions = {}
          if raw
            @latest_vision_areas = raw[:areas]
            player_detections = assign_vision_detections(
              raw[:detections],
              image_width:  raw[:image_width],
              image_height: raw[:image_height]
            )
            @latest_vision_actions = extract_vision_actions(player_detections)
            @cached_positions = (@cached_positions || {}).merge(scale_vision_positions(player_detections, raw[:image_width], raw[:image_height])) if player_detections
            @cached_timer = raw[:timer] unless raw[:timer].nil?
          end
          { positions: @cached_positions, timer: @cached_timer }
        end

        def extract_vision_actions(player_detections)
          return {} if player_detections.nil? || player_detections.empty?

          player_detections.each_with_object({}) do |(player_index, detection), actions|
            actions[player_index] = detection.action if detection
          end
        end

        def assign_vision_detections(detections, image_width:, image_height:)
          return nil if detections.empty?

          sub_zero_players = @vision_characters.select { |_, character| character == SUB_ZERO_CHARACTER }.keys
          player_detections = {}

          if sub_zero_players.size == PLAYER_TWO && detections.size >= PLAYER_TWO
            player_detections[PLAYER_ONE] = detections.first
            player_detections[PLAYER_TWO] = detections.last
          elsif sub_zero_players.size == PLAYER_ONE
            player_detections[sub_zero_players.first] = detections.max_by(&:confidence)
          elsif detections.size >= PLAYER_TWO
            player_detections[PLAYER_ONE] = detections.first
            player_detections[PLAYER_TWO] = detections.last
          else
            inferred_player = detections.first.center_x <= image_width / MIDPOINT_DIVISOR ? PLAYER_ONE : PLAYER_TWO
            player_detections[inferred_player] = detections.first
          end

          player_detections
        end

        def scale_vision_positions(player_detections, image_width, image_height)
          return nil if player_detections.nil? || player_detections.empty?

          player_detections.each_with_object({}) do |(player_index, detection), positions|
            positions[player_index] = scale_detection(detection, image_width, image_height) if detection
          end
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

      end
    end
  end
end
