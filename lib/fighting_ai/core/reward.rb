module FightingAI
  module Core
    class Reward < Data.define(:value, :components)
      ZERO = new(value: 0.0, components: {}).freeze

      def self.compose(**components)
        total = components.sum { |_, v| v }
        new(value: total.to_f, components: components)
      end

      def positive? = value > 0
      def negative? = value < 0
      def zero?     = value == 0.0

      def +(other)
        merged = components.merge(other.components) { |_, a, b| a + b }
        Reward.new(value: value + other.value, components: merged)
      end

      def to_f = value
      def to_s = value.to_s
    end
  end
end
