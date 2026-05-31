require "colorize"

module FightingAI
  module CLI
    class PPODisplay
      BAR_WIDTH  = 16
      MAX_HEALTH = 0xA6  # 166

      COMPONENT_LABELS = {
        damage_dealt: "dmg",
        damage_taken: "tkn",
        distance:     "dst",
        round_win:    "win",
        round_loss:   "loss",
        round_draw:   "draw",
        stale:        "stl"
      }.freeze

      def initialize
        @episode       = 0
        @training_step = 0
        @buffer_size   = 0
        @buffer_cap    = 512
        @last_status   = ""
      end

      def set_context(episode:, training_step:, buffer_size:, buffer_capacity:)
        @episode       = episode
        @training_step = training_step
        @buffer_size   = buffer_size
        @buffer_cap    = buffer_capacity
      end

      def update(game_state:, stage_name:, watches: [])
        f1    = game_state.fighter1
        f2    = game_state.fighter2
        timer = game_state.round_time_remaining

        state_tag =
          if game_state.fight_active? then "fight".green
          elsif game_state.round_over? then "over".yellow
          else "idle".light_black
          end

        buf_str = "#{@buffer_size}/#{@buffer_cap}"
        buf     = @buffer_size >= @buffer_cap ? buf_str.green : buf_str.yellow

        line =
          "Ep #{@episode.to_s.rjust(4)} ".cyan +
          "│ #{stage_name} ".light_black +
          "│ t:#{timer.to_s.rjust(2)} ".white +
          "│ P1 #{health_bar(f1.health).green} #{f1.health.to_s.rjust(3)} x:#{f1.x.to_s.rjust(3)} " +
          "│ P2 #{health_bar(f2.health).red} #{f2.health.to_s.rjust(3)} x:#{f2.x.to_s.rjust(3)} " +
          "│ [#{state_tag}] " +
          "│ buf #{buf}"

        unless watches.empty?
          watch_str = watches.map { |w| "#{w[:label]}:#{w[:value].to_s.rjust(3)}" }.join("  ")
          line += " │ #{watch_str}".yellow
        end

        @last_status = line
        $stdout.print "\r#{line}"
        $stdout.flush
      end

      def episode_done(episode:, winner:, stale: false, p1_reward:, p2_reward:, p1_components: {}, p2_components: {})
        out_plain = stale ? "Stale  " : (winner ? "P#{winner} wins" : "Draw   ")
        out_color = stale ? out_plain.red : (winner ? out_plain.green : out_plain.yellow)

        ep_plain = "✓ Ep #{episode.to_s.rjust(4)}"
        prefix   = "#{ep_plain}  #{out_plain}  "
        indent   = " " * prefix.length

        line1 = ep_plain.cyan + "  #{out_color}  " +
                "P1 #{fmt_reward(p1_reward)} #{fmt_components(p1_components)}"
        line2 = indent +
                "P2 #{fmt_reward(p2_reward)} #{fmt_components(p2_components)}"

        event(line1, line2)
      end

      def ppo_update(step:, stats:, n:)
        line =
          "⚡ PPO ##{step}".cyan +
          "  pol #{stats[:policy_loss].to_f.round(4)}".light_blue +
          "  val #{stats[:value_loss].to_f.round(4)}".light_blue +
          "  ent #{stats[:entropy].to_f.round(4)}".light_blue +
          "  n=#{n}".light_black
        event(line)
      end

      def checkpoint(path)
        event "💾 #{File.basename(path)}".yellow
      end

      private

      def health_bar(hp)
        filled = [(hp.to_f / MAX_HEALTH * BAR_WIDTH).round, BAR_WIDTH].min
        "█" * filled + "░" * (BAR_WIDTH - filled)
      end

      def fmt_reward(r)
        s = format("%+7.2f", r)
        r >= 0 ? s.green : s.red
      end

      def fmt_components(components)
        parts = COMPONENT_LABELS.filter_map do |key, label|
          val = components[key]
          next if val.nil? || val.zero?
          s = format("%+.0f", val)
          "#{label}:#{val >= 0 ? s.green : s.red}"
        end
        parts.empty? ? "" : "[#{parts.join(' ')}]"
      end

      def event(*lines)
        body = lines.map.with_index { |l, i| i.zero? ? "\r\e[2K#{l}" : "\n\e[2K#{l}" }.join
        $stdout.print "#{body}\n\r\e[2K#{@last_status}"
        $stdout.flush
      end
    end
  end
end
