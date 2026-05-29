require_relative "provider"

module FightingAI
  module Observation
    # Stub for future WRAM-based structured observation.
    # Will expose named fields from a WramReader snapshot
    # rather than raw pixel data.
    class MemoryObservation
      attr_reader :snapshot

      def initialize(snapshot)
        @snapshot = snapshot
      end
    end
  end
end
