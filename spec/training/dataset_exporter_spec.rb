require "spec_helper"
require "tmpdir"
require "json"

RSpec.describe FightingAI::Training::DatasetExporter do
  let(:tmpdir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(tmpdir) }

  def write_recording(filename, entries)
    File.open(File.join(tmpdir, filename), "w") do |f|
      entries.each { |e| f.puts(JSON.generate(e)) }
    end
  end

  let(:sample_entry) do
    {
      frame:    1,
      match_id: "abc-123",
      observation: { vector: [0.8, 0.6, 0.2, 0.0], frame: 1 },
      action:   { name: "low_punch", metadata: {} },
      reward:   5.0
    }
  end

  before { write_recording("match1.jsonl", [sample_entry, sample_entry]) }

  subject(:exporter) { described_class.new(recordings_path: tmpdir) }

  describe "#export_frames" do
    it "returns all frames from all recordings" do
      expect(exporter.export_frames.size).to eq(2)
    end
  end

  describe "#export_imitation_pairs" do
    it "returns [vector, action_name] pairs" do
      pairs = exporter.export_imitation_pairs
      expect(pairs.size).to eq(2)
      expect(pairs.first).to eq([[0.8, 0.6, 0.2, 0.0], "low_punch"])
    end
  end

  describe "#export_by_match" do
    it "groups frames by match_id" do
      by_match = exporter.export_by_match
      expect(by_match["abc-123"].size).to eq(2)
    end
  end

  describe "#recording_count" do
    it "counts JSONL files" do
      expect(exporter.recording_count).to eq(1)
    end
  end
end
