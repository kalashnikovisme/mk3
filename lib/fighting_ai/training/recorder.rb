require "json"
require "fileutils"

module FightingAI
  module Training
    # Records gameplay sessions to JSONL files.
    # One line per frame: { frame, observation, action, reward }
    class Recorder
      attr_reader :path, :frame_count

      def initialize(path:)
        @path        = path
        @frame_count = 0
        @file        = nil
      end

      def start(match_id: nil)
        FileUtils.mkdir_p(File.dirname(@path))
        @file        = File.open(@path, "a")
        @frame_count = 0
        @match_id    = match_id
        @file.sync   = true
      end

      def record(frame_number:, observation:, action:, reward:)
        raise "Recorder not started" unless @file

        entry = {
          frame:       frame_number,
          match_id:    @match_id,
          observation: serialize_observation(observation),
          action:      serialize_action(action),
          reward:      reward.to_f
        }

        @file.puts(JSON.generate(entry))
        @frame_count += 1
      end

      def stop
        @file&.close
        @file = nil
      end

      def recording?
        !@file.nil?
      end

      private

      def serialize_observation(obs)
        {
          frame:               obs.frame_number,
          my_health_pct:       obs.my_health_pct,
          opponent_health_pct: obs.opponent_health_pct,
          my_x:                obs.my_x_normalized,
          my_y:                obs.my_y_normalized,
          opponent_x:          obs.opponent_x_normalized,
          opponent_y:          obs.opponent_y_normalized,
          round_time:          obs.round_time_normalized,
          vector:              obs.to_vector
        }
      end

      def serialize_action(action)
        { name: action.name, metadata: action.metadata }
      end
    end
  end
end
