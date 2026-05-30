require "fileutils"

module FightingAI
  module Training
    # Saves and loads numbered PPO model checkpoints.
    # Maintains a `latest` symlink so training can resume automatically.
    class CheckpointManager
      LATEST_LINK = "latest"

      def initialize(dir:)
        @dir = File.expand_path(dir)
        FileUtils.mkdir_p(@dir)
      end

      def save(episode:, policy:)
        path = checkpoint_path(episode)
        FileUtils.mkdir_p(path)
        policy.save(path)
        update_latest_link(path)
        path
      end

      def load_latest(policy:)
        path = latest_path
        return false unless path

        policy.load(path)
        true
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

      def checkpoint_path(episode)
        File.join(@dir, format("checkpoint_%06d", episode))
      end

      def update_latest_link(path)
        link = File.join(@dir, LATEST_LINK)
        File.unlink(link) if File.symlink?(link)
        File.symlink(path, link)
      end
    end
  end
end
