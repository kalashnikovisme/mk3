module FightingAI
  module Scenario
    BASE_FRAME = 1.0 / 60.0  # one SNES frame at 60 fps

    SPEED_PRESETS = {
      normal:  1.0,
      fast:    2.0,
      turbo:   10.0,
      slow:    0.5,
      slow_mo: 0.25
    }.freeze

    class << self
      def frame_duration
        @frame_duration ||= BASE_FRAME
      end

      # Set speed by preset symbol or numeric multiplier.
      # speed(:fast) or speed(2.0) both mean "twice normal speed".
      def set_speed(preset_or_multiplier)
        multiplier = case preset_or_multiplier
                     when Symbol  then SPEED_PRESETS.fetch(preset_or_multiplier) { raise ArgumentError, "Unknown speed preset: #{preset_or_multiplier}. Use: #{SPEED_PRESETS.keys.join(', ')}" }
                     when Numeric then preset_or_multiplier.to_f
                     else raise ArgumentError, "speed expects a Symbol or Numeric"
                     end
        @frame_duration = multiplier.zero? ? 0 : BASE_FRAME / multiplier
      end
    end
  end
end
