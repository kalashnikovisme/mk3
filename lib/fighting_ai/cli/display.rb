require "colorize"

module FightingAI
  module CLI
    class PPODisplay
      BAR_WIDTH  = 16
      MAX_HEALTH = 0xA6  # 166
      CLEAR_COLS = 200   # spaces used to wipe the status line before printing an event

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

      def update(game_state:, stage_name:)
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
          "│ P1 #{health_bar(f1.health).green} #{f1.health.to_s.rjust(3)} " +
          "│ P2 #{health_bar(f2.health).red} #{f2.health.to_s.rjust(3)} " +
          "│ [#{state_tag}] " +
          "│ buf #{buf}"

        @last_status = line
        $stdout.print "\r#{line}"
        $stdout.flush
      end

      def episode_done(episode:, winner:, p1_reward:, p2_reward:)
        winner_str = (winner ? "P#{winner} wins" : "Draw   ").green
        line =
          "✓ Ep #{episode.to_s.rjust(4)}".cyan +
          "  #{winner_str}" +
          "  P1 #{fmt_reward(p1_reward)}" +
          "  P2 #{fmt_reward(p2_reward)}"
        event(line)
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

      def event(line)
        $stdout.print "\r#{' ' * CLEAR_COLS}\r#{line}\n\r#{@last_status}"
        $stdout.flush
      end
    end
  end
end
