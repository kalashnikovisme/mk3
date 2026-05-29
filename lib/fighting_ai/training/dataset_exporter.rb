require "json"

module FightingAI
  module Training
    # Reads JSONL recordings and exports structured datasets
    # suitable for imitation learning pipelines.
    class DatasetExporter
      def initialize(recordings_path:)
        @recordings_path = recordings_path
      end

      # Export all recordings in the path to a flat array of frames.
      def export_frames
        recording_files.flat_map { |file| parse_jsonl(file) }
      end

      # Export (observation_vector, action_name) pairs for supervised learning.
      def export_imitation_pairs
        export_frames.map do |frame|
          obs_vector   = frame.dig("observation", "vector")
          action_name  = frame.dig("action", "name")
          [obs_vector, action_name]
        end.reject { |v, a| v.nil? || a.nil? }
      end

      # Export frames as a hash keyed by match_id.
      def export_by_match
        export_frames.each_with_object(Hash.new { |h, k| h[k] = [] }) do |frame, acc|
          acc[frame["match_id"]] << frame
        end
      end

      def recording_count
        recording_files.size
      end

      private

      def recording_files
        Dir.glob(File.join(@recordings_path, "**", "*.jsonl")).sort
      end

      def parse_jsonl(path)
        File.readlines(path, chomp: true).filter_map do |line|
          next if line.strip.empty?
          JSON.parse(line)
        rescue JSON::ParserError
          nil
        end
      end
    end
  end
end
