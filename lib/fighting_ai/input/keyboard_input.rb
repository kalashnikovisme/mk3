require_relative "device"

module FightingAI
  module Input
    class KeyboardInput < Device
      PLAYER_KEYS = {
        1 => {
          up:         "Up",
          down:       "Down",
          left:       "Left",
          right:      "Right",
          low_punch:  "s",
          high_punch: "a",
          low_kick:   "x",
          high_kick:  "z",
          block:      "q",
          run:        "w",
          start:      "Return",
          select:     "shift"
        }.freeze,
        2 => {
          up:         "t",
          down:       "g",
          left:       "f",
          right:      "h",
          low_punch:  "n",
          high_punch: "c",
          low_kick:   "b",
          high_kick:  "v",
          block:      "r",
          run:        "y",
          start:      "p",
          select:     "o"
        }.freeze
      }.freeze

      def initialize
        @window_id  = nil
        @key_state  = { 1 => {}, 2 => {} }
      end

      def start
        @window_id = find_window
      end

      def stop
        [1, 2].each { |p| release_all(p) }
        @window_id = nil
      end

      def send_input(player_index, buttons)
        return unless @window_id

        key_map = PLAYER_KEYS.fetch(player_index)
        current = @key_state[player_index]

        buttons.each do |logical, pressed|
          key = key_map[logical]
          next unless key

          was_pressed = current[logical]

          if pressed && !was_pressed
            system("xdotool keydown --window #{@window_id} #{key}")
            current[logical] = true
          elsif !pressed && was_pressed
            system("xdotool keyup --window #{@window_id} #{key}")
            current[logical] = false
          end
        end
      end

      def release_all(player_index)
        return unless @window_id

        key_map = PLAYER_KEYS.fetch(player_index)
        current = @key_state[player_index]

        current.each do |logical, pressed|
          next unless pressed
          key = key_map[logical]
          next unless key
          system("xdotool keyup --window #{@window_id} #{key}")
        end

        @key_state[player_index] = {}
      end

      private

      def find_window
        output = `xdotool search --name "RetroArch" 2>/dev/null`.strip
        return nil if output.empty?
        output.lines.last.strip
      end
    end
  end
end
