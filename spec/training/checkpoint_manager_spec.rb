require "spec_helper"
require "tmpdir"

RSpec.describe FightingAI::Training::CheckpointManager do
  INCOMPATIBLE_ERROR = "incompatible checkpoint"
  DUMMY_CHECKPOINT = "ppo_1"
  CHECKPOINT_FILE_NAME = "policy.pt"

  let(:policy) do
    instance_double(
      FightingAI::Training::Policy,
      load: { "ok" => false, "error" => INCOMPATIBLE_ERROR }
    )
  end

  describe "#load_latest" do
    it "skips an incompatible latest checkpoint without raising" do
      Dir.mktmpdir do |directory|
        manager = described_class.new(dir: directory)
        checkpoint_path = File.join(directory, DUMMY_CHECKPOINT)
        FileUtils.mkdir_p(checkpoint_path)
        File.symlink(checkpoint_path, File.join(directory, described_class::LATEST_LINK))

        expect(manager.load_latest(policy: policy)).to be false
      end
    end
  end

  describe "#load" do
    it "raises when an explicit checkpoint is incompatible" do
      Dir.mktmpdir do |directory|
        manager = described_class.new(dir: directory)
        checkpoint_path = File.join(directory, DUMMY_CHECKPOINT)
        FileUtils.mkdir_p(checkpoint_path)

        expect do
          manager.load(path: checkpoint_path, policy: policy)
        end.to raise_error(RuntimeError, /#{INCOMPATIBLE_ERROR}/)
      end
    end

    it "accepts a direct policy.pt path by loading its parent checkpoint directory" do
      Dir.mktmpdir do |directory|
        manager = described_class.new(dir: directory)
        checkpoint_path = File.join(directory, DUMMY_CHECKPOINT)
        policy_file_path = File.join(checkpoint_path, CHECKPOINT_FILE_NAME)
        success_policy = instance_double(FightingAI::Training::Policy, load: { "ok" => true })
        FileUtils.mkdir_p(checkpoint_path)
        File.write(policy_file_path, "")

        expect(success_policy).to receive(:load).with(checkpoint_path).and_return({ "ok" => true })

        expect(manager.load(path: policy_file_path, policy: success_policy)).to be true
      end
    end
  end
end
