require_relative "device"

module FightingAI
  module Input
    # Stub for future uinput virtual gamepad support.
    # uinput allows creating a kernel-level virtual input device that
    # RetroArch sees as a real gamepad — no window focus dependency.
    class UinputDevice < Device
      def start
        raise NotImplementedError, "UinputDevice is not yet implemented"
      end

      def stop
        raise NotImplementedError, "UinputDevice is not yet implemented"
      end

      def send_input(player_index, buttons)
        raise NotImplementedError, "UinputDevice is not yet implemented"
      end

      def release_all(player_index)
        raise NotImplementedError, "UinputDevice is not yet implemented"
      end
    end
  end
end
