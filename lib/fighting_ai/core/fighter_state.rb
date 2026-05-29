module FightingAI
  module Core
    class FacingDirection < Data.define(:value)
      LEFT  = new(value: :left).freeze
      RIGHT = new(value: :right).freeze

      def left?    = value == :left
      def right?   = value == :right
      def opposite = left? ? RIGHT : LEFT
    end

    AnimationState = Data.define(:name, :frame_index, :total_frames)

    FighterState = Data.define(
      :player_index,
      :health,
      :max_health,
      :x,
      :y,
      :facing,
      :animation_state,
      :in_hitstun,
      :in_blockstun,
      :knocked_down,
      :airborne
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
