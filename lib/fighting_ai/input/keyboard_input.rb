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

      def initialize(verbose: true)
        @verbose   = verbose
        @pid       = nil
        @window_id = nil
        @key_state = { 1 => {}, 2 => {} }
      end

      # Call after the RetroArch process has started and its window is visible.
      def start(pid: nil)
        @pid       = pid
        @window_id = find_window
      end

      def stop
        [1, 2].each { |p| release_all(p) }
        @window_id = nil
      end

      def send_input(player_index, buttons)
        @window_id ||= find_window
        return unless @window_id

        key_map = PLAYER_KEYS.fetch(player_index)
        current = @key_state[player_index]

        buttons.each do |logical, pressed|
          key = key_map[logical]
          next unless key

          was_pressed = current[logical]

          if pressed && !was_pressed
            $stdout.puts "[keys] P#{player_index} ▼ #{logical}" if @verbose
            system("xdotool keydown --window #{@window_id} #{key} 2>/dev/null")
            current[logical] = true
          elsif !pressed && was_pressed
            $stdout.puts "[keys] P#{player_index} ▲ #{logical}" if @verbose
            system("xdotool keyup --window #{@window_id} #{key} 2>/dev/null")
            current[logical] = false
          end
        end
      end

      def load_state
        @window_id ||= find_window
        return unless @window_id
        system("xdotool key --window #{@window_id} F4 2>/dev/null")
      end

      def release_all(player_index)
        @window_id ||= find_window
        return unless @window_id

        key_map = PLAYER_KEYS.fetch(player_index)
        current = @key_state[player_index]

        current.each do |logical, pressed|
          next unless pressed
          key = key_map[logical]
          next unless key
          system("xdotool keyup --window #{@window_id} #{key} 2>/dev/null")
        end

        @key_state[player_index] = {}
      end

      private

      def find_window
        if @pid
          ids = `xdotool search --pid #{@pid} --onlyvisible 2>/dev/null`.strip.split
          unless ids.empty?
            wid = ids.first
            name = `xdotool getwindowname #{wid} 2>/dev/null`.strip
            $stderr.puts "[keys] window found by PID #{@pid}: id=#{wid} title=#{name.inspect}"
            return wid
          end
        end
        ids = `xdotool search --onlyvisible --name "RetroArch" 2>/dev/null`.strip.split
        if ids.empty?
          $stderr.puts "[keys] no RetroArch window found"
          return nil
        end
        wid = ids.first
        name = `xdotool getwindowname #{wid} 2>/dev/null`.strip
        $stderr.puts "[keys] window found by name: id=#{wid} title=#{name.inspect}"
        wid
      end
    end
  end
end
