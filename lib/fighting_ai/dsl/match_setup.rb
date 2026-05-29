module FightingAI
  module DSL
    RANDOM_CHARACTER = :__random__

    class CharacterPool
      attr_reader :name

      def initialize(name)
        @name = name
      end
    end

    def self.random_character
      RANDOM_CHARACTER
    end

    def self.sample_from_pool(pool_name)
      CharacterPool.new(pool_name)
    end

    class MatchSetup
      attr_reader :player1_selection, :player2_selection

      def initialize
        @player1_selection = nil
        @player2_selection = nil
      end

      def player1(character)
        @player1_selection = character
      end

      def player2(character)
        @player2_selection = character
      end

      def resolve_characters(game_adapter)
        [
          resolve_selection(@player1_selection, game_adapter),
          resolve_selection(@player2_selection, game_adapter)
        ]
      end

      private

      def resolve_selection(selection, game_adapter)
        case selection
        when RANDOM_CHARACTER
          game_adapter.characters.keys.sample
        when CharacterPool
          pool = game_adapter.character_pools[selection.name] || game_adapter.characters.keys
          pool.sample
        else
          selection.to_sym
        end
      end
    end
  end
end
