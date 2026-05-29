module FightingAI
  module Observation
    class Provider
      def capture
        raise NotImplementedError, "#{self.class}#capture not implemented"
      end
    end
  end
end
