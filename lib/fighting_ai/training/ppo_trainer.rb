module FightingAI
  module Training
    # Drives self-play PPO training indefinitely.
    #
    # Loop:
    #   1. Install the match save state.
    #   2. Run a full match with two PPOAgents sharing one Policy.
    #   3. Both agents push transitions into the shared TrajectoryBuffer.
    #   4. Every UPDATE_EVERY_EPISODES episodes, if the buffer has enough data,
    #      run a PPO update and log the losses.
    #   5. Every CHECKPOINT_EVERY_UPDATES policy updates, save a checkpoint.
    #   6. Repeat until Ctrl+C.
    class PPOTrainer
      UPDATE_EVERY_EPISODES    = 5
      CHECKPOINT_EVERY_UPDATES = 10

      def initialize(
        emulator:,
        game:,
        policy:,
        buffer:,
        checkpoint_manager:,
        agents:,
        match_state:,
        logger: nil,
        wram_dump: false,
        max_rounds: nil
      )
        @emulator           = emulator
        @game               = game
        @policy             = policy
        @buffer             = buffer
        @checkpoint_manager = checkpoint_manager
        @agents             = agents
        @match_state        = match_state
        @logger             = logger || method(:default_log)
        @wram_dump          = wram_dump
        @max_rounds         = max_rounds
        @episode            = 0
        @training_step      = 0
      end

      def train
        resume_from_checkpoint

        log "Starting PPO self-play training. Press Ctrl+C to stop."

        loop do
          @episode += 1
          run_episode

          next unless (@episode % UPDATE_EVERY_EPISODES).zero?
          next unless @buffer.ready?

          update_policy
        end
      end

      def stop
        @policy.stop
      end

      private

      def resume_from_checkpoint
        return unless @checkpoint_manager.exists?

        @checkpoint_manager.load_latest(policy: @policy)
        log "Resumed from checkpoint: #{@checkpoint_manager.latest_path}"
      end

      def run_episode
        @emulator.install_match_state(@match_state[:path])

        runner = Runtime::MatchRunner.new(
          emulator_adapter: @emulator,
          game_adapter:     @game,
          agents:           @agents,
          logger:           @logger,
          wram_dump:        @wram_dump,
          max_rounds:       @max_rounds
        )

        match  = runner.run(
          player1_character: @match_state[:p1],
          player2_character: @match_state[:p2]
        )
        result = @game.collect_match_result(match)

        log_episode(result)
      end

      def update_policy
        @training_step += 1
        transitions = @buffer.flush
        stats       = @policy.update(transitions)

        log format(
          "PPO Update #%d | n=%d | policy_loss=%.4f | value_loss=%.4f | entropy=%.4f",
          @training_step, transitions.size,
          stats[:policy_loss].to_f, stats[:value_loss].to_f, stats[:entropy].to_f
        )

        if (@training_step % CHECKPOINT_EVERY_UPDATES).zero?
          path = @checkpoint_manager.save(episode: @episode, policy: @policy)
          log "Checkpoint saved → #{File.basename(path)}"
        end
      end

      def log_episode(result)
        winner    = result[:winner] ? "Player #{result[:winner]}" : "Draw"
        p1_reward = @agents[1].episode_reward
        p2_reward = @agents[2].episode_reward
        log format(
          "Episode %4d | Winner: %-8s | Reward P1: %+7.2f | Reward P2: %+7.2f",
          @episode, winner, p1_reward, p2_reward
        )
      end

      def log(msg)
        @logger.call("[PPOTrainer] #{msg}")
      end

      def default_log(msg)
        $stdout.puts msg
      end
    end
  end
end
