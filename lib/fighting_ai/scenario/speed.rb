module FightingAI
  module Scenario
    BASE_FRAME = 1.0 / 60.0

    SPEED_PRESETS = {
      normal:  1.0,
      fast:    2.0,
      turbo:   10.0,
      slow:    0.5,
      slow_mo: 0.25
    }.freeze

    # Maps each preset to the RetroArch mode it requires.
    RETROARCH_MODES = {
      normal:  :normal,
      fast:    :fast,
      turbo:   :fast,
      slow:    :slow,
      slow_mo: :slow
    }.freeze

    class << self
      # Set by bin/scenario before loading the scenario file.
      attr_writer :emulator

      def frame_duration
        @frame_duration ||= BASE_FRAME
      end

      def set_speed(preset_or_multiplier)
        multiplier, ra_mode = resolve(preset_or_multiplier)
        apply_retroarch_mode(ra_mode)
        @frame_duration = multiplier.zero? ? 0 : BASE_FRAME / multiplier
      end

      private

      def resolve(value)
        case value
        when Symbol
          multiplier = SPEED_PRESETS.fetch(value) do
            raise ArgumentError, "Unknown speed preset: #{value}. Valid: #{SPEED_PRESETS.keys.join(', ')}"
          end
          [multiplier, RETROARCH_MODES.fetch(value, :normal)]
        when Numeric
          m = value.to_f
          ra_mode = if m > 1.0 then :fast elsif m < 1.0 then :slow else :normal end
          [m, ra_mode]
        else
          raise ArgumentError, "speed expects a Symbol or Numeric, got #{value.class}"
        end
      end

      # FAST_FORWARD and SLOWMOTION are toggles in RetroArch.
      # We track the current mode so we only send a toggle when the mode actually changes.
      def apply_retroarch_mode(target)
        return unless @emulator

        current = @retroarch_mode || :normal
        return if current == target

        # Disable whatever is currently active
        case current
        when :fast then Emulator::RetroArch::NetworkCommands.fast_forward
        when :slow then Emulator::RetroArch::NetworkCommands.slowmotion
        end

        # Enable the new mode
        case target
        when :fast then Emulator::RetroArch::NetworkCommands.fast_forward
        when :slow then Emulator::RetroArch::NetworkCommands.slowmotion
        end

        @retroarch_mode = target
      end
    end
  end
end
