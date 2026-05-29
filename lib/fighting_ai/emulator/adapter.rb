module FightingAI
  module Emulator
    # Abstract base for all emulator adapters.
    # Subclasses handle communication with a specific emulator binary.
    # No game-specific knowledge belongs here.
    class Adapter
      def connect
        raise NotImplementedError, "#{self.class}#connect not implemented"
      end

      def disconnect
        raise NotImplementedError, "#{self.class}#disconnect not implemented"
      end

      def connected?
        raise NotImplementedError, "#{self.class}#connected? not implemented"
      end

      # Block until the next frame snapshot arrives; returns raw Hash
      def next_frame_snapshot
        raise NotImplementedError, "#{self.class}#next_frame_snapshot not implemented"
      end

      # Send controller input for a single frame.
      # buttons: Hash { button_name => bool }
      def send_input(player_index, buttons)
        raise NotImplementedError, "#{self.class}#send_input not implemented"
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

      def start_recording(path)
        raise NotImplementedError, "#{self.class}#start_recording not implemented"
      end

      def stop_recording
        raise NotImplementedError, "#{self.class}#stop_recording not implemented"
      end
    end
  end
end
