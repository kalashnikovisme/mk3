module FightingAI
  module Core
    FighterState = Data.define(
      :player_index,
      :health,
      :max_health,
      :x,
      :y
    ) do
      def health_pct
        return 0.0 if max_health.zero?
        health.to_f / max_health
      end

      def alive? = health > 0

      def position = [x, y]

      def distance_to(other)
        (x - other.x).abs
      end
    end
  end
end
