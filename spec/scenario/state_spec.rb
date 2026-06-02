require "spec_helper"
require "tmpdir"
require "fighting_ai/scenario/state"

RSpec.describe FightingAI::Scenario do
  Frame = Struct.new(:path)

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  ensure
    described_class.emulator = nil
  end

  describe ".screenshot" do
    it "captures and copies a screenshot into the screenshots export directory" do
      source_dir = File.join(@dir, "source")
      export_dir = File.join(@dir, "screenshots")
      FileUtils.mkdir_p(source_dir)
      source_path = File.join(source_dir, "retroarch.png")
      File.binwrite(source_path, "png-data")

      stub_const("#{described_class}::SCREENSHOT_EXPORT_DIR", export_dir)
      described_class.emulator = instance_double("Emulator", capture_frame: Frame.new(source_path))

      saved_path = described_class.screenshot("vision/idle")

      expect(saved_path).to eq(File.join(export_dir, "vision", "idle.png"))
      expect(File.binread(saved_path)).to eq("png-data")
    end
  end
end
