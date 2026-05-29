require "spec_helper"
require "tmpdir"
require "json"

RSpec.describe FightingAI::Training::Recorder do
  let(:tmpdir) { Dir.mktmpdir }
  let(:path)   { File.join(tmpdir, "session.jsonl") }

  after { FileUtils.rm_rf(tmpdir) }

  let(:obs_attrs) do
    {
      frame_number:           1,
      my_health_pct:          0.8,
      opponent_health_pct:    0.6,
      my_x_normalized:        0.2,
      my_y_normalized:        0.0,
      opponent_x_normalized:  0.5,
      opponent_y_normalized:  0.0,
      distance_normalized:    0.3,
      my_facing:              :right,
      opponent_facing:        :left,
      my_in_hitstun:          false,
      my_in_blockstun:        false,
      my_knocked_down:        false,
      my_airborne:            false,
      opponent_in_hitstun:    false,
      opponent_in_blockstun:  false,
      opponent_knocked_down:  false,
      opponent_airborne:      false,
      round_time_normalized:  0.9,
      round_number:           1,
      raw:                    nil
    }
  end

  let(:observation) { FightingAI::Core::Observation.new(**obs_attrs) }
  let(:action)      { FightingAI::Core::Action.named(:walk_forward) }
  let(:reward)      { FightingAI::Core::Reward.compose(damage_dealt: 5.0) }

  subject(:recorder) { described_class.new(path: path) }

  describe "recording a session" do
    it "writes JSONL entries to the file" do
      recorder.start
      recorder.record(frame_number: 1, observation: observation, action: action, reward: reward)
      recorder.stop

      lines = File.readlines(path, chomp: true)
      expect(lines.size).to eq(1)

      entry = JSON.parse(lines.first)
      expect(entry["frame"]).to eq(1)
      expect(entry["action"]["name"]).to eq("walk_forward")
      expect(entry["reward"]).to eq(5.0)
    end

    it "tracks frame count" do
      recorder.start
      3.times { |i| recorder.record(frame_number: i, observation: observation, action: action, reward: reward) }
      recorder.stop

      expect(recorder.frame_count).to eq(3)
    end

    it "is not recording? after stop" do
      recorder.start
      recorder.stop
      expect(recorder.recording?).to be false
    end
  end
end
