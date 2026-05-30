module FightingAI
  module Game
    # Abstract base for all game adapters.
    # Subclasses encode all game-specific knowledge:
    # memory maps, input maps, action spaces, reward functions,
    # and the full match lifecycle contract.
    class Adapter
      attr_reader :emulator_adapter, :game_definition

      def initialize(emulator_adapter:, game_definition:)
        @emulator_adapter = emulator_adapter
        @game_definition  = game_definition
      end

      # -------------------------------------------------------------------------
      # State extraction
      # -------------------------------------------------------------------------

      # One-line human-readable description of a raw snapshot (stage, health, timer).
      # Used for terminal status output; default falls back to raw screen value.
      def describe_snapshot(raw_snapshot)
        "screen=0x#{raw_snapshot['screen'].to_i.to_s(16).rjust(2, '0')}"
      end

      def snapshot_stage_name(raw_snapshot)
        "screen=0x#{raw_snapshot['screen'].to_i.to_s(16).rjust(2, '0')}"
      end

      # Parse a raw frame snapshot Hash from the emulator into a Core::GameState.
      def extract_game_state(raw_snapshot)
        raise NotImplementedError, "#{self.class}#extract_game_state not implemented"
      end

      # Build a Core::Observation from a Core::GameState for the given player.
      def build_observation(game_state, player_index:)
        raise NotImplementedError, "#{self.class}#build_observation not implemented"
      end

      # -------------------------------------------------------------------------
      # Action translation
      # -------------------------------------------------------------------------

      # Translate a Core::Action into a Core::InputSequence.
      def action_to_input_sequence(action, player_index:, game_state:)
        raise NotImplementedError, "#{self.class}#action_to_input_sequence not implemented"
      end

      # Translate an InputSequence into a raw buttons Hash for the emulator.
      def input_sequence_to_buttons(input_sequence, frame_offset: 0)
        raise NotImplementedError, "#{self.class}#input_sequence_to_buttons not implemented"
      end

      # -------------------------------------------------------------------------
      # Reward
      # -------------------------------------------------------------------------

      def calculate_reward(prev_game_state, next_game_state, player_index:)
        raise NotImplementedError, "#{self.class}#calculate_reward not implemented"
      end

      # -------------------------------------------------------------------------
      # Match lifecycle contract (all must be implemented by subclasses)
      # -------------------------------------------------------------------------

      def start_game
        raise NotImplementedError, "#{self.class}#start_game not implemented"
      end

      def open_player_vs_player_mode
        raise NotImplementedError, "#{self.class}#open_player_vs_player_mode not implemented"
      end

      def select_characters(player1_character:, player2_character:)
        raise NotImplementedError, "#{self.class}#select_characters not implemented"
      end

      def wait_for_fight_start(timeout: 30)
        raise NotImplementedError, "#{self.class}#wait_for_fight_start not implemented"
      end

      def fight_active?(game_state)
        raise NotImplementedError, "#{self.class}#fight_active? not implemented"
      end

      def fight_finished?(game_state)
        raise NotImplementedError, "#{self.class}#fight_finished? not implemented"
      end

      def collect_match_result(match)
        raise NotImplementedError, "#{self.class}#collect_match_result not implemented"
      end

      def reset_for_next_match(strategy: :load_save_state)
        raise NotImplementedError, "#{self.class}#reset_for_next_match not implemented"
      end

      # -------------------------------------------------------------------------
      # Character registry
      # -------------------------------------------------------------------------

      def characters
        raise NotImplementedError, "#{self.class}#characters not implemented"
      end

      def character_pools
        {}
      end
    end
  end
end
