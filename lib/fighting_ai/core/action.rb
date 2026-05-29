module FightingAI
  module Core
    # An Action represents a discrete decision made by an agent for a single frame.
    # The name is a symbolic label (e.g. :walk_forward, :low_punch).
    # The game adapter translates this into concrete controller buttons.
    class Action < Data.define(:name, :metadata)
      def self.named(name, **metadata)
        new(name: name.to_sym, metadata: metadata)
      end

      IDLE = named(:idle).freeze

      def idle? = name == :idle
      def to_s  = name.to_s
    end
  end
end
