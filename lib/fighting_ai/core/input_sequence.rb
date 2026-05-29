module FightingAI
  module Core
    # A timed sequence of controller button states to be injected over N frames.
    # Emulator adapters consume InputSequence; agents produce Actions.
    # Game adapters translate Actions into InputSequences.
    class InputSequence
      Entry = Data.define(:buttons, :hold_frames)

      attr_reader :entries

      def initialize
        @entries = []
      end

      def press(buttons, hold_frames: 1)
        @entries << Entry.new(buttons: Array(buttons).map(&:to_sym), hold_frames: hold_frames)
        self
      end

      def self.single(*buttons)
        new.press(buttons)
      end

      def self.empty
        new
      end

      def total_frames
        @entries.sum(&:hold_frames)
      end

      def to_button_frames
        @entries.flat_map do |entry|
          Array.new(entry.hold_frames) { entry.buttons }
        end
      end
    end
  end
end
