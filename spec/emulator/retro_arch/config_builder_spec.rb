require "spec_helper"

RSpec.describe FightingAI::Emulator::RetroArch::ConfigBuilder do
  CORE_PATH = "/tmp/core.so"
  RAW_CORE_SCREENSHOT_SETTING = 'video_gpu_screenshot = "false"'

  describe ".config" do
    it "captures screenshots from the core framebuffer instead of the rendered window" do
      expect(described_class.config(CORE_PATH)).to include(RAW_CORE_SCREENSHOT_SETTING)
    end
  end
end
