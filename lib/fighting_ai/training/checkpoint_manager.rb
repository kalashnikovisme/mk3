require "fileutils"

module FightingAI
  module Training
    # Saves and loads numbered PPO model checkpoints.
    # Maintains a `latest` symlink so training can resume automatically.
    class CheckpointManager
      LATEST_LINK = "latest"
      CHECKPOINT_ERROR_PREFIX = "checkpoint load failed"
      CHECKPOINT_FILE_NAME = "policy.pt"

      def initialize(dir:)
        @dir = File.expand_path(dir)
        FileUtils.mkdir_p(@dir)
      end

      def save(step:, policy:)
        path = checkpoint_path(step)
        FileUtils.mkdir_p(path)
        policy.save(path)
        update_latest_link(path)
        path
      end

      def load_latest(policy:)
        path = latest_path
        return false unless path

        response = policy.load(path)
        return true if response.is_a?(Hash) && response["ok"]

        warn format("%s: skipping %s (%s)", CHECKPOINT_ERROR_PREFIX, path, checkpoint_error_message(response))
        false
      end

      def load(path:, policy:)
        expanded = File.expand_path(path)
        raise "Checkpoint not found: #{expanded}" unless File.exist?(expanded)

        normalized = normalize_checkpoint_path(expanded)
        response = policy.load(normalized)
        return true if response.is_a?(Hash) && response["ok"]

        raise format("%s: %s (%s)", CHECKPOINT_ERROR_PREFIX, expanded, checkpoint_error_message(response))
      end

      def latest_path
        link = File.join(@dir, LATEST_LINK)
        return nil unless File.symlink?(link)

        target = File.realpath(link)
        File.exist?(target) ? target : nil
      rescue Errno::ENOENT
        nil
      end

      def exists?
        !latest_path.nil?
      end

      private

      def checkpoint_path(step)
        File.join(@dir, "ppo_#{step}")
      end

      def update_latest_link(path)
        link = File.join(@dir, LATEST_LINK)
        File.unlink(link) if File.symlink?(link)
        File.symlink(path, link)
      end

      def checkpoint_error_message(response)
        return response.fetch("error", "unknown error") if response.is_a?(Hash)

        response.inspect
      end

      def normalize_checkpoint_path(path)
        return File.dirname(path) if File.file?(path) && File.basename(path) == CHECKPOINT_FILE_NAME

        path
      end
    end
  end
end
