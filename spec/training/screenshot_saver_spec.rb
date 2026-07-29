require "spec_helper"
require "tmpdir"

RSpec.describe FightingAI::Training::ScreenshotSaver do
  SAVER_WIDTH = 5
  SAVER_HEIGHT = 5
  SAVER_FRAME_NUMBER = 7
  SAVER_CHANNELS_PER_PIXEL = 3
  SAVER_PIXEL_COUNT = SAVER_WIDTH * SAVER_HEIGHT
  SAVER_BYTE_VALUES = (0...(SAVER_PIXEL_COUNT * SAVER_CHANNELS_PER_PIXEL)).to_a.freeze
  SAVER_RAW_BYTES = SAVER_BYTE_VALUES.pack("C*").freeze
  SAVER_FIGHTER1_AREA = { "x" => 0, "y" => 0, "width" => 2, "height" => 1 }.freeze
  SAVER_FIGHTER2_AREA = { "x" => 1, "y" => 1, "width" => 2, "height" => 1 }.freeze
  SAVER_DETECTION = Struct.new(:x, :y, :width, :height).new(1, 1, 3, 3).freeze
  SAVER_FRAME_FILENAME = "frame_00007.ppm"
  SAVER_FULL_FRAME_HEADER = "P6\n5 5\n255\n"
  SAVER_FIGHTER_HEADER = "P6\n2 1\n255\n"
  SAVER_RECONSTRUCTION_HEADER = "P6\n5 5\n255\n"
  SAVER_SOURCE_MARKER_OFFSET = (2 + (2 * SAVER_WIDTH)) * SAVER_CHANNELS_PER_PIXEL

    it "writes whole frames and fighter crops into separate episode subdirectories" do
      frame_observation = double(
        "FrameObservation",
        raw_bytes: SAVER_RAW_BYTES,
        width: SAVER_WIDTH,
        height: SAVER_HEIGHT
      )

    Dir.mktmpdir do |directory|
      saver = described_class.new(directory, width: SAVER_WIDTH, height: SAVER_HEIGHT)
      saver.save(
        frame_observation,
        SAVER_FRAME_NUMBER,
        areas: [SAVER_FIGHTER1_AREA, SAVER_FIGHTER2_AREA],
        vision_snapshot: { player_detections: { 1 => SAVER_DETECTION } }
      )
      saver.stop

      screen_path = File.join(directory, "screen", SAVER_FRAME_FILENAME)
      fighter1_path = File.join(directory, "fighter1", SAVER_FRAME_FILENAME)
      fighter2_path = File.join(directory, "fighter2", SAVER_FRAME_FILENAME)
      reconstruction_path = File.join(directory, "reconstruction", SAVER_FRAME_FILENAME)

      expect(File).to exist(screen_path)
      expect(File).to exist(fighter1_path)
      expect(File).to exist(fighter2_path)
      expect(File).to exist(reconstruction_path)
      expect(File.binread(screen_path)).to start_with(SAVER_FULL_FRAME_HEADER)
      expect(File.binread(fighter1_path)).to start_with(SAVER_FIGHTER_HEADER)
      expect(File.binread(fighter2_path)).to start_with(SAVER_FIGHTER_HEADER)
      expect(File.binread(reconstruction_path)).to start_with(SAVER_RECONSTRUCTION_HEADER)
      expect(reconstruction_pixel(reconstruction_path, 2, 2)).to eq([36, 37, 38])
    end
  end

  def reconstruction_pixel(path, x, y)
    bytes = File.binread(path)
    header_bytes = SAVER_RECONSTRUCTION_HEADER.bytesize
    offset = header_bytes + ((y * SAVER_WIDTH) + x) * SAVER_CHANNELS_PER_PIXEL
    bytes.byteslice(offset, SAVER_CHANNELS_PER_PIXEL).bytes
  end
end
