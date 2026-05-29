module FightingAI
  module Input
    class Device
      def start
        raise NotImplementedError, "#{self.class}#start not implemented"
      end

      def stop
        raise NotImplementedError, "#{self.class}#stop not implemented"
      end

      def send_input(player_index, buttons)
        raise NotImplementedError, "#{self.class}#send_input not implemented"
      end

      def release_all(player_index)
        raise NotImplementedError, "#{self.class}#release_all not implemented"
      end
    end
  end
end
