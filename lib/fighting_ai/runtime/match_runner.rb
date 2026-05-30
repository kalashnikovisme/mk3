require "fileutils"
require_relative "../core/match"
require_relative "../core/round"

module FightingAI
  module Runtime
    # Drives a single match to completion.
    # Coordinates the emulator adapter, game adapter, agents, and recorder.
    # Does not know which game is being played or which emulator is used.
    class MatchRunner
      WRAM_DUMP_DIR = File.expand_path("../../../data/memory", __dir__).freeze

      def initialize(emulator_adapter:, game_adapter:, agents:, recorder: nil, logger: nil, ui: nil, wram_dump: false, max_rounds: nil)
        @emulator        = emulator_adapter
        @game            = game_adapter
        @agents          = agents   # Hash { 1 => Agent, 2 => Agent }
        @recorder        = recorder
        @logger          = logger || method(:default_log)
        @ui              = ui
        @wram_dump       = wram_dump
        @wram_dump_index = 0
        @max_rounds      = max_rounds
        FileUtils.mkdir_p(WRAM_DUMP_DIR) if @wram_dump
      end

      # Run a full match and return the completed Core::Match.
      def run(player1_character:, player2_character:)
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

        loop do
          snapshot   = @emulator.next_frame_snapshot
          game_state = @game.extract_game_state(snapshot)

          if @ui
            @ui.update(game_state: game_state, stage_name: @game.snapshot_stage_name(snapshot))
          elsif Time.now - last_status_at >= 1.0
            state = if game_state.fight_active?  then "fight"
                    elsif game_state.round_over? then "round_over"
                    else                              "idle"
                    end
            log "#{@game.describe_snapshot(snapshot)}  [#{state}]"
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
            step_agents(game_state, prev_game_state, match.id)
          end

          if fight_seen && (@game.fight_finished?(game_state) || game_state.round_over?)
            # Deliver terminal reward (includes round_win / round_loss) before closing the episode.
            notify_agents_terminal_reward(game_state, prev_game_state) if prev_game_state
            winner = determine_round_winner(game_state)
            round.finish!(winner: winner)
            log "Round #{round.number} finished. Winner: #{winner}"
            break
          end

          prev_game_state = game_state
        end
      end

      def step_agents(game_state, prev_game_state, match_id)
        button_log = {}

        @agents.each do |player_index, agent|
          reward = if prev_game_state
            @game.calculate_reward(prev_game_state, game_state, player_index: player_index)
          else
            Core::Reward::ZERO
          end

          # Deliver reward for the previous step before the agent decides its next action.
          # This lets RL agents store (obs_t, action_t, reward_{t→t+1}) in the correct order.
          agent.observe_reward(reward)

          observation = @game.build_observation(game_state, player_index: player_index)
          action      = agent.act(observation)

          @recorder&.record(
            frame_number: game_state.frame_number,
            observation:  observation,
            action:       action,
            reward:       reward
          )

          input_seq = @game.action_to_input_sequence(action, player_index: player_index, game_state: game_state)
          buttons   = @game.input_sequence_to_buttons(input_seq, player_index: player_index)
          @emulator.send_input(player_index, buttons)

          if @ui.nil?
            pressed = buttons.select { |_, v| v }.keys
            button_log[player_index] = "P#{player_index}:#{pressed.empty? ? ' —' : " [#{pressed.join(', ')}]"}"
          end
        end

        log button_log.values.join("   ") unless @ui
      end

      def notify_agents_terminal_reward(game_state, prev_game_state)
        @agents.each do |player_index, agent|
          reward = @game.calculate_reward(prev_game_state, game_state, player_index: player_index)
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
