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
      UPDATE_EVERY_EPISODES = 5

      def initialize(
        emulator:,
        game:,
        policy:,
        buffer:,
        checkpoint_manager:,
        agents:,
        match_state:,
        logger: nil,
        ui: nil,
        wram_dump: false,
        max_rounds: nil,
        initial_checkpoint: nil
      )
        @emulator           = emulator
        @game               = game
        @policy             = policy
        @buffer             = buffer
        @checkpoint_manager = checkpoint_manager
        @agents             = agents
        @match_state        = match_state
        @logger             = logger || method(:default_log)
        @ui                 = ui
        @wram_dump           = wram_dump
        @max_rounds          = max_rounds
        @initial_checkpoint  = initial_checkpoint
        @episode             = 0
        @training_step       = 0
      end

      def train
        resume_from_checkpoint

        log "Starting PPO self-play training. Press Ctrl+C to stop."

        loop do
          @episode += 1

          @ui&.set_context(
            episode:          @episode,
            training_step:    @training_step,
            buffer_size:      @buffer.size,
            buffer_capacity:  @buffer.min_size
          )

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
        if @initial_checkpoint
          @checkpoint_manager.load(path: @initial_checkpoint, policy: @policy)
          log "Loaded checkpoint: #{@initial_checkpoint}"
        elsif @checkpoint_manager.exists?
          @checkpoint_manager.load_latest(policy: @policy)
          log "Resumed from checkpoint: #{@checkpoint_manager.latest_path}"
        end
      end

      def run_episode
        @emulator.install_match_state(@match_state[:path])

        runner = Runtime::MatchRunner.new(
          emulator_adapter: @emulator,
          game_adapter:     @game,
          agents:           @agents,
          logger:           @logger,
          ui:               @ui,
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

        if @ui
          @ui.ppo_update(step: @training_step, stats: stats, n: transitions.size)
        else
          log format(
            "PPO Update #%d | n=%d | policy_loss=%.4f | value_loss=%.4f | entropy=%.4f",
            @training_step, transitions.size,
            stats[:policy_loss].to_f, stats[:value_loss].to_f, stats[:entropy].to_f
          )
        end

        path = @checkpoint_manager.save(step: @training_step, policy: @policy)
        if @ui
          @ui.checkpoint(path)
        else
          log "PPO ##{@training_step} saved → #{File.basename(path)}"
        end
      end

      def log_episode(result)
        stale     = result[:stale_rounds].to_i > 0
        p1_reward = @agents[1].episode_reward
        p2_reward = @agents[2].episode_reward

        if @ui
          @ui.episode_done(
            episode:   @episode,
            winner:    result[:winner],
            stale:     stale,
            p1_reward: p1_reward,
            p2_reward: p2_reward
          )
        else
          label = if stale then "Stale"
                  elsif result[:winner] then "Player #{result[:winner]}"
                  else "Draw"
                  end
          log format(
            "Episode %4d | %-8s | Reward P1: %+7.2f | Reward P2: %+7.2f",
            @episode, label, p1_reward, p2_reward
          )
        end
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
