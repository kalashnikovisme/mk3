require "spec_helper"
require "tmpdir"
require "fighting_ai/scenario/state"

RSpec.describe FightingAI::Scenario do
  X_DISPLAY = ":123"
  SCREENSHOT_BYTES = "png-data"
  COMMAND_STDOUT = ""
  COMMAND_STDERR = ""
  SCREENSHOT_CROP_GEOMETRY = "297x216+0+0"

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  ensure
    described_class.emulator = nil
  end

  describe ".screenshot" do
    it "captures an X server screenshot into the screenshots export directory" do
      export_dir = File.join(@dir, "screenshots")
      success_status = instance_double(Process::Status, success?: true)

      stub_const("#{described_class}::SCREENSHOT_EXPORT_DIR", export_dir)
      described_class.emulator = instance_double("Emulator", display: X_DISPLAY)

      allow(Open3).to receive(:capture3) do |*command|
        if command.first == described_class::CONVERT_BIN
          png_path = command.last.delete_prefix(described_class::PNG_PREFIX)
          File.binwrite(png_path, SCREENSHOT_BYTES)
        end
        [COMMAND_STDOUT, COMMAND_STDERR, success_status]
      end

      saved_path = described_class.screenshot("vision/idle")

      expect(saved_path).to eq(File.join(export_dir, "vision", "idle.png"))
      expect(File.binread(saved_path)).to eq(SCREENSHOT_BYTES)
      expect(Open3).to have_received(:capture3).with(
        described_class::XWD_BIN,
        described_class::XWD_SILENT_ARG,
        described_class::XWD_DISPLAY_ARG,
        X_DISPLAY,
        described_class::XWD_ROOT_ARG,
        described_class::XWD_OUT_ARG,
        kind_of(String)
      )
      expect(Open3).to have_received(:capture3).with(
        described_class::CONVERT_BIN,
        kind_of(String),
        described_class::CONVERT_CROP_ARG,
        SCREENSHOT_CROP_GEOMETRY,
        described_class::CONVERT_REPAGE_ARG,
        "#{described_class::PNG_PREFIX}#{saved_path}"
      )
    end

    it "raises an actionable error when xwd is missing from the container" do
      export_dir = File.join(@dir, "screenshots")

      stub_const("#{described_class}::SCREENSHOT_EXPORT_DIR", export_dir)
      described_class.emulator = instance_double("Emulator", display: X_DISPLAY)
      allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT)

      expect { described_class.screenshot("vision/idle") }
        .to raise_error(RuntimeError, /Run `dip provision`/)
    end
  end
end
