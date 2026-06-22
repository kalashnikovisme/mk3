module FightingAI
  module Emulator
    class Adapter
      def start
        raise NotImplementedError, "#{self.class}#start not implemented"
      end

      def stop
        raise NotImplementedError, "#{self.class}#stop not implemented"
      end

      def started?
        raise NotImplementedError, "#{self.class}#started? not implemented"
      end

      def connected?
        raise NotImplementedError, "#{self.class}#connected? not implemented"
      end

      def advance_frame
        raise NotImplementedError, "#{self.class}#advance_frame not implemented"
      end

      # buttons: Hash of { logical_symbol => bool }
      # e.g. { up: true, low_punch: false, high_kick: true }
      def send_input(player_index, buttons)
        raise NotImplementedError, "#{self.class}#send_input not implemented"
      end

      # Send a sequence of button-state hashes one game frame apart.
      def send_input_sequence(player_index, frame_buttons_array)
        raise NotImplementedError, "#{self.class}#send_input_sequence not implemented"
      end

      def send_noop
        raise NotImplementedError, "#{self.class}#send_noop not implemented"
      end

      def capture_frame
        raise NotImplementedError, "#{self.class}#capture_frame not implemented"
      end

      def load_save_state(slot)
        raise NotImplementedError, "#{self.class}#load_save_state not implemented"
      end

      def save_state(slot)
        raise NotImplementedError, "#{self.class}#save_state not implemented"
      end

      def read_memory(address, byte_count: 1)
        raise NotImplementedError, "#{self.class}#read_memory not implemented"
      end

      def wram_binary_dump
        raise NotImplementedError, "#{self.class}#wram_binary_dump not implemented"
      end

      def wram_source_info
        raise NotImplementedError, "#{self.class}#wram_source_info not implemented"
      end
    end
  end
end
