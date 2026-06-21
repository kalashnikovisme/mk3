require "fileutils"
require_relative "../core/match"
require_relative "../core/round"

module FightingAI
  module Runtime
    # Drives a single match to completion.
    # Coordinates the emulator adapter, game adapter, agents, and recorder.
    # Does not know which game is being played or which emulator is used.
    class MatchRunner
      WRAM_DUMP_DIR  = File.expand_path("../../../data/memory", __dir__).freeze
      MS_PER_SECOND    = 1000
      UI_UPDATE_INTERVAL = 1.0 / 10

      def initialize(emulator_adapter:, game_adapter:, agents:, recorder: nil, logger: nil, ui: nil, wram_dump: false, max_rounds: nil, fight_logger: nil)
        @emulator        = emulator_adapter
        @game            = game_adapter
        @agents          = agents   # Hash { 1 => Agent, 2 => Agent }
        @recorder        = recorder
        @logger          = logger || method(:default_log)
        @ui              = ui
        @wram_dump       = wram_dump
        @wram_dump_index = 0
        @max_rounds      = max_rounds
        @fight_logger    = fight_logger
        @vision_capture_warning_logged = false
        FileUtils.mkdir_p(WRAM_DUMP_DIR) if @wram_dump
      end

      # Run a full match and return the completed Core::Match.
      def run(player1_character:, player2_character:)
        @game.configure_vision_characters(
          player1_character: player1_character,
          player2_character: player2_character
        ) if @game.respond_to?(:configure_vision_characters)

        match = Core::Match.new(
          game_id:            @game.class::GAME_ID,
          player1_character:  player1_character,
          player2_character:  player2_character
        )

        notify_agents(:on_match_start, match)
        @recorder&.start(match_id: match.id)

        round_number = 1

        until match.finished?
          round = match.start_round(round_number)
          notify_agents(:on_round_start, round)

          run_round(match, round)

          notify_agents(:on_round_end, round)
          round_number += 1

          break if @max_rounds && round_number > @max_rounds
          break if match_should_end?(match)
        end

        match.finish!
        result = @game.collect_match_result(match)
        notify_agents(:on_match_end, match, result)
        @recorder&.stop

        log "Match finished. Winner: #{match.winner}. " \
            "Rounds: P1=#{match.player1_rounds_won} P2=#{match.player2_rounds_won}"

        match
      end

      private

      def run_round(match, round)
        prev_game_state = nil
        fight_seen      = false
        last_status_at  = Time.now - 1
        last_ui_at      = Time.now - UI_UPDATE_INTERVAL
        stall_hp        = nil
        stall_since     = nil
        loop do
          iteration_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          snapshot = @emulator.next_frame_snapshot
          snapshot_finished_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          frame_observation = capture_frame_observation
          capture_finished_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          game_state = @game.extract_game_state(snapshot, frame_observation: frame_observation)
          detection_finished_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          agents_ms = 0
          log_frame = lambda do
            work_finished_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            @fight_logger&.log_frame(
              game_state,
              snapshot_ms: milliseconds_between(iteration_started_at, snapshot_finished_at),
              capture_ms: milliseconds_between(snapshot_finished_at, capture_finished_at),
              detect_ms: milliseconds_between(capture_finished_at, detection_finished_at),
              agents_ms: agents_ms,
              runtime_ms: milliseconds_between(detection_finished_at, work_finished_at),
              work_ms: milliseconds_between(iteration_started_at, work_finished_at)
            )
          end

          if @ui && Time.now - last_ui_at >= UI_UPDATE_INTERVAL
            @ui.update(game_state: game_state)
            last_ui_at = Time.now
          elsif Time.now - last_status_at >= 1.0
            state = if game_state.fight_active?  then "fight"
                    elsif game_state.round_over? then "round_over"
                    else                              "idle"
                    end
            log "[#{state}]"
            if @wram_dump
              @wram_dump_index += 1
              filename = File.join(WRAM_DUMP_DIR, "%03d" % @wram_dump_index)
              File.write(filename, @emulator.wram_hex_dump)
              log "Saved WRAM dump → #{filename}"
            end
            last_status_at = Time.now
          end

          frame = Core::Frame.from_snapshot(
            number:     game_state.frame_number,
            game_id:    @game.class::GAME_ID,
            game_state: game_state,
            raw_data:   snapshot
          )
          round.record_frame(frame)

          fight_seen ||= game_state.fight_active?

          if game_state.fight_active?
            current_hp = [game_state.fighter1.health, game_state.fighter2.health]
            if current_hp != stall_hp
              stall_hp    = current_hp
              stall_since = Time.now
            elsif stall_since && Time.now - stall_since >= FightingAI.config.stale_timeout
              log "Round #{round.number} stalled (HP unchanged for #{FightingAI.config.stale_timeout}s). Restarting."
              notify_agents_terminal_reward(game_state, prev_game_state, stale: true) if prev_game_state
              round.finish!(winner: nil, stale: true)
              log_frame.call
              break
            end

            agents_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            step_agents(game_state, prev_game_state, match.id)
            agents_ms = milliseconds_since(agents_started_at)
          end

          if fight_seen && !game_state.fight_active?
            notify_agents_terminal_reward(game_state, prev_game_state, round_over: true) if prev_game_state
            winner = determine_round_winner(game_state)
            round.finish!(winner: winner)
            log "Round #{round.number} finished. Winner: #{winner}"
            log_frame.call
            break
          end

          prev_game_state = game_state
          log_frame.call
        end
      end

      def milliseconds_since(started_at)
        milliseconds_between(started_at, Process.clock_gettime(Process::CLOCK_MONOTONIC))
      end

      def milliseconds_between(started_at, finished_at)
        ((finished_at - started_at) * MS_PER_SECOND).round
      end

      def capture_frame_observation
        return nil unless @game.respond_to?(:vision_enabled?) && @game.vision_enabled?

        @emulator.capture_frame
      rescue Emulator::RetroArch::FrameGrabber::CaptureError => e
        log_vision_capture_warning(e)
        nil
      end

      def log_vision_capture_warning(error)
        return if @vision_capture_warning_logged

        message = "Vision screenshot capture failed (#{error.message}); positions will use last known values."
        @ui&.log(message)
        log(message) unless @ui
        @vision_capture_warning_logged = true
      end

      def step_agents(game_state, prev_game_state, match_id)
        button_log = {}

        @agents.each do |player_index, agent|
          reward = if prev_game_state
            @game.calculate_reward(prev_game_state, game_state, player_index: player_index)
          else
            Core::Reward::ZERO
          end

          agent.observe_reward(reward)

          observation = @game.build_observation(game_state, player_index: player_index)
          action      = agent.act(observation)

          @recorder&.record(
            frame_number: game_state.frame_number,
            observation:  observation,
            action:       action,
            reward:       reward
          )

          input_seq  = @game.action_to_input_sequence(action, player_index: player_index, game_state: game_state)
          all_frames = @game.all_button_frames(input_seq, player_index: player_index)
          @emulator.send_input_sequence(player_index, all_frames)

          if @ui.nil?
            pressed = all_frames.first&.select { |_, v| v }&.keys || []
            button_log[player_index] = "P#{player_index}:#{pressed.empty? ? ' —' : " [#{pressed.join(', ')}]"}"
          end
        end

        log button_log.values.join("   ") unless @ui
      end

      def notify_agents_terminal_reward(game_state, prev_game_state, stale: false, round_over: false)
        @agents.each do |player_index, agent|
          reward = @game.calculate_reward(prev_game_state, game_state, player_index: player_index, stale: stale, round_over: round_over)
          agent.observe_reward(reward, done: true)
        end
      end

      def determine_round_winner(game_state)
        h1 = game_state.fighter1.health
        h2 = game_state.fighter2.health
        return 1 if h1 > h2
        return 2 if h2 > h1
        nil
      end

      def match_should_end?(match)
        # Best of 3 rounds
        match.player1_rounds_won >= 2 || match.player2_rounds_won >= 2
      end

      def notify_agents(method_name, *args)
        @agents.each_value { |agent| agent.public_send(method_name, *args) }
      end

      def log(msg)
        @logger.call("[MatchRunner] #{msg}")
      end

      def default_log(msg)
        $stdout.puts msg
      end
    end
  end
end
