module FightingAI
  module Vision
    # Detects each fighter's current health by measuring how much of their
    # on-screen health bar is filled with the "alive" colour (blue).
    #
    # The detector scans each pixel column of the bar from the fill side:
    #   Player 1 fills left → right.
    #   Player 2 fills right → left.
    # The count of contiguous filled columns is scaled to a health value.
    class HealthBarDetector
      BarConfig = Data.define(:x, :y, :width, :height, :direction)

      BLUE_DOMINANCE_THRESHOLD  = 50   # B must exceed both R and G by at least this
      BLUE_MIN_VALUE            = 100  # B absolute floor
      COLUMN_FILLED_MIN_PIXELS  = 5    # pixels in a column that must be blue to count as filled

      def initialize(bar1:, bar2:, max_health:)
        @bar1       = bar1
        @bar2       = bar2
        @max_health = max_health
      end

      def detect(frame_observation)
        {
          1 => measure(@bar1, frame_observation),
          2 => measure(@bar2, frame_observation)
        }
      end

      private

      def measure(bar, frame_observation)
        columns = (bar.x...(bar.x + bar.width)).to_a
        columns.reverse! if bar.direction == :right_to_left

        filled = 0
        columns.each do |x|
          blue_pixels = (bar.y...(bar.y + bar.height)).count do |y|
            r, g, b = frame_observation.pixel_rgb(x, y)
            b >= BLUE_MIN_VALUE &&
              b > r + BLUE_DOMINANCE_THRESHOLD &&
              b > g + BLUE_DOMINANCE_THRESHOLD
          end
          break if blue_pixels < COLUMN_FILLED_MIN_PIXELS
          filled += 1
        end

        (@max_health * filled.to_f / bar.width).round
      end
    end
  end
end
