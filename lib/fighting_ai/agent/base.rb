module FightingAI
  module Agent
    # Abstract base for all agents.
    # An agent receives an Observation and returns an Action.
    # Agents must not know about emulator internals, Lua, memory addresses,
    # or menu systems.
    class Base
      attr_reader :player_index

      def initialize(player_index:)
        @player_index = player_index
      end

      # Returns a Core::Action given a Core::Observation.
      def act(observation)
        raise NotImplementedError, "#{self.class}#act not implemented"
      end

      # Called once before a match begins.
      def on_match_start(match); end

      # Called once after a match ends.
      def on_match_end(match, result); end

      # Called once before each round.
      def on_round_start(round); end

      # Called once after each round ends.
      def on_round_end(round); end

      def to_s
        "#{self.class.name}(player: #{player_index})"
      end
    end
  end
end
