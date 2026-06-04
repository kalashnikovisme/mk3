require "spec_helper"

RSpec.describe FightingAI::Emulator::RetroArch::ConfigBuilder do
  CORE_PATH = "/tmp/core.so"
  RETROARCH_SCREENSHOT_SETTING = "screenshot_directory"
  RETROARCH_SCREENSHOT_INPUT_SETTING = "input_screenshot"
  RETROARCH_GPU_SCREENSHOT_SETTING = "video_gpu_screenshot"
  WINDOWED_FULLSCREEN_SETTING = 'video_windowed_fullscreen = "false"'
  NATIVE_VIDEO_SCALE_SETTING = 'video_scale = "1.0"'
  INTEGER_SCALE_SETTING = 'video_scale_integer = "true"'
  WINDOW_DECORATION_SETTING = 'video_window_show_decorations = "false"'
  PIXEL_SMOOTHING_SETTING = 'video_smooth = "false"'

  describe ".config" do
    it "does not configure RetroArch screenshot capture" do
      config = described_class.config(CORE_PATH)

      expect(config).not_to include(RETROARCH_SCREENSHOT_SETTING)
      expect(config).not_to include(RETROARCH_SCREENSHOT_INPUT_SETTING)
      expect(config).not_to include(RETROARCH_GPU_SCREENSHOT_SETTING)
    end

    it "opens RetroArch at native game scale instead of filling the X server" do
      config = described_class.config(CORE_PATH)

      expect(config).to include(WINDOWED_FULLSCREEN_SETTING)
      expect(config).to include(NATIVE_VIDEO_SCALE_SETTING)
      expect(config).to include(INTEGER_SCALE_SETTING)
      expect(config).to include(WINDOW_DECORATION_SETTING)
      expect(config).to include(PIXEL_SMOOTHING_SETTING)
    end
  end
end
