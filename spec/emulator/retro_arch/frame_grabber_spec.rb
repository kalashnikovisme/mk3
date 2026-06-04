require "spec_helper"
require "tmpdir"

RSpec.describe FightingAI::Emulator::RetroArch::FrameGrabber do
  FRAME_GRABBER_X_DISPLAY = ":123"
  FRAME_GRABBER_SCREENSHOT_BYTES = "png-data"
  FRAME_GRABBER_COMMAND_STDOUT = ""
  FRAME_GRABBER_COMMAND_STDERR = ""

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  it "captures a cropped X server screenshot as a frame observation" do
    success_status = instance_double(Process::Status, success?: true)

    stub_const("#{described_class}::SCREENSHOT_DIR", @dir)
    allow(Open3).to receive(:capture3) do |*command|
      if command.first == described_class::CONVERT_BIN
        png_path = command.last.delete_prefix(described_class::PNG_PREFIX)
        File.binwrite(png_path, FRAME_GRABBER_SCREENSHOT_BYTES)
      end
      [FRAME_GRABBER_COMMAND_STDOUT, FRAME_GRABBER_COMMAND_STDERR, success_status]
    end

    frame = described_class.new.capture(display: FRAME_GRABBER_X_DISPLAY)

    expect(File.binread(frame.path)).to eq(FRAME_GRABBER_SCREENSHOT_BYTES)
    expect(Open3).to have_received(:capture3).with(
      described_class::XWD_BIN,
      described_class::XWD_SILENT_ARG,
      described_class::XWD_DISPLAY_ARG,
      FRAME_GRABBER_X_DISPLAY,
      described_class::XWD_ROOT_ARG,
      described_class::XWD_OUT_ARG,
      kind_of(String)
    )
    expect(Open3).to have_received(:capture3).with(
      described_class::CONVERT_BIN,
      kind_of(String),
      described_class::CONVERT_CROP_ARG,
      frame_grabber_screenshot_crop_geometry,
      described_class::CONVERT_REPAGE_ARG,
      "#{described_class::PNG_PREFIX}#{frame.path}"
    )
  end

  it "raises an actionable capture error when xwd is missing from the container" do
    stub_const("#{described_class}::SCREENSHOT_DIR", @dir)
    allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT)

    expect { described_class.new.capture(display: FRAME_GRABBER_X_DISPLAY) }
      .to raise_error(described_class::CaptureError, /Run `dip provision`/)
  end

  def frame_grabber_screenshot_crop_geometry
    "#{described_class::SCREENSHOT_CROP_WIDTH}x#{described_class::SCREENSHOT_CROP_HEIGHT}+" \
      "#{described_class::SCREENSHOT_CROP_X}+#{described_class::SCREENSHOT_CROP_Y}"
  end
end
