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
          high_punch: "s",
          low_punch:  "x",
          low_kick:   "z",
          high_kick:  "a",
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
          high_punch: "n",
          low_punch:  "b",
          low_kick:   "v",
          high_kick:  "c",
          block:      "r",
          run:        "y",
          start:      "p",
          select:     "o"
        }.freeze
      }.freeze

      def initialize(verbose: true, display: ":1")
        @verbose   = verbose
        @display   = display
        @pid       = nil
        @window_id = nil
        @key_state = { 1 => {}, 2 => {} }
      end

      def start(pid: nil)
        @pid       = pid
        @window_id = find_window
        if @window_id
          xdotool("windowactivate --sync #{@window_id}")
          clear_stuck_modifiers
          if @verbose
            name = xdotool_output("getwindowname #{@window_id}")
            $stderr.puts "\e[34m[keys] focused window: #{name} (id=#{@window_id})\e[0m"
          end
        end
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
            xdotool("keydown #{key}")
            current[logical] = true
          elsif !pressed && was_pressed
            $stdout.puts "[keys] P#{player_index} ▲ #{logical}" if @verbose
            xdotool("keyup #{key}")
            current[logical] = false
          end
        end
      end

      def load_state
        @window_id ||= find_window
        return unless @window_id
        xdotool("key F4")
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
          xdotool("keyup #{key}")
        end

        @key_state[player_index] = {}
      end

      private

      def clear_stuck_modifiers
        %w[alt shift ctrl super].each { |mod| xdotool("keyup #{mod}") }
      end

      def xdotool(args)
        system("DISPLAY=#{@display} xdotool #{args} 2>/dev/null")
      end

      def find_window
        if @pid
          ids = xdotool_output("search --pid #{@pid}").split
          unless ids.empty?
            wid  = ids.first
            name = xdotool_output("getwindowname #{wid}")
            $stderr.puts "[keys] window found by PID #{@pid}: id=#{wid} title=#{name.inspect}"
            return wid
          end
        end

        ids = xdotool_output("search --name RetroArch").split
        if ids.empty?
          $stderr.puts "[keys] no RetroArch window found (DISPLAY=#{@display})"
          return nil
        end

        wid  = ids.first
        name = xdotool_output("getwindowname #{wid}")
        $stderr.puts "[keys] window found by name: id=#{wid} title=#{name.inspect}"
        wid
      end

      def xdotool_output(args)
        `DISPLAY=#{@display} xdotool #{args} 2>/dev/null`.strip
      end
    end
  end
end
