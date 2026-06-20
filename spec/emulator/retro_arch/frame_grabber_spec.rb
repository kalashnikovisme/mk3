require "spec_helper"
require "tmpdir"

RSpec.describe FightingAI::Emulator::RetroArch::FrameGrabber do
  FRAME_GRABBER_X_DISPLAY        = ":123"
  FRAME_GRABBER_SCREENSHOT_BYTES = "png-data"

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  it "captures a cropped X server screenshot as a frame observation" do
    success_status = instance_double(Process::Status, success?: true)

    stub_const("#{described_class}::SCREENSHOT_DIR", @dir)
    allow(Open3).to receive(:pipeline) do |_xwd_cmd, convert_cmd|
      png_path = convert_cmd.last.delete_prefix(described_class::PNG_PREFIX)
      File.binwrite(png_path, FRAME_GRABBER_SCREENSHOT_BYTES)
      [success_status, success_status]
    end

    frame = described_class.new.capture(display: FRAME_GRABBER_X_DISPLAY)

    expect(File.binread(frame.path)).to eq(FRAME_GRABBER_SCREENSHOT_BYTES)
    expect(Open3).to have_received(:pipeline).with(
      [described_class::XWD_BIN, described_class::XWD_SILENT_ARG,
       described_class::XWD_DISPLAY_ARG, FRAME_GRABBER_X_DISPLAY,
       described_class::XWD_ROOT_ARG],
      [described_class::CONVERT_BIN, described_class::CONVERT_STDIN,
       described_class::CONVERT_CROP_ARG, frame_grabber_screenshot_crop_geometry,
       described_class::CONVERT_REPAGE_ARG, "#{described_class::PNG_PREFIX}#{frame.path}"]
    )
  end

  it "raises an actionable capture error when xwd is missing from the container" do
    stub_const("#{described_class}::SCREENSHOT_DIR", @dir)
    allow(Open3).to receive(:pipeline).and_raise(Errno::ENOENT)

    expect { described_class.new.capture(display: FRAME_GRABBER_X_DISPLAY) }
      .to raise_error(described_class::CaptureError, /Run `dip provision`/)
  end

  def frame_grabber_screenshot_crop_geometry
    "#{described_class::SCREENSHOT_CROP_WIDTH}x#{described_class::SCREENSHOT_CROP_HEIGHT}+" \
      "#{described_class::SCREENSHOT_CROP_X}+#{described_class::SCREENSHOT_CROP_Y}"
  end
end
