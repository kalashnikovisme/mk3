require_relative "device"

module FightingAI
  module Input
    class VirtualInput < Device
      def start; end
      def stop; end
      def send_input(player_index, buttons); end
      def release_all(player_index); end
    end
  end
end
