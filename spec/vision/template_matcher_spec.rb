require "spec_helper"
require "fileutils"
require "tmpdir"
require "zlib"

RSpec.describe FightingAI::Vision::TemplateMatcher do
  PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b.freeze
  COLOR_GRAYSCALE = 0
  COLOR_RGB = 2
  BIT_DEPTH = 8
  COMPRESSION_METHOD = 0
  FILTER_METHOD = 0
  INTERLACE_METHOD = 0
  FILTER_NONE = 0
  MASK_WHITE = 255
  BACKGROUND = [0, 0, 0].freeze
  SPRITE_PIXEL = [20, 100, 200].freeze
  SCREEN_WIDTH = 8
  SCREEN_HEIGHT = 4
  TEMPLATE_WIDTH = 2
  TEMPLATE_HEIGHT = 2
  FIRST_SPRITE_X = 1
  SECOND_SPRITE_X = 5
  SPRITE_Y = 1
  TEMPLATE_CENTER_OFFSET = 1
  TEMPLATE_BOTTOM_OFFSET = 2
  MIN_CONFIDENCE = 0.99

  Frame = Struct.new(:path)

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  it "detects two non-overlapping instances of the same grayscale masked template" do
    template_dir = File.join(@dir, "templates")
    FileUtils.mkdir_p(template_dir)
    write_grayscale_png(File.join(template_dir, "idle_left_gray.png"), TEMPLATE_WIDTH, TEMPLATE_HEIGHT, Array.new(TEMPLATE_WIDTH * TEMPLATE_HEIGHT, luminance(*SPRITE_PIXEL)))
    write_grayscale_png(File.join(template_dir, "idle_left_mask.png"), TEMPLATE_WIDTH, TEMPLATE_HEIGHT, Array.new(TEMPLATE_WIDTH * TEMPLATE_HEIGHT, MASK_WHITE))

    screen_path = File.join(@dir, "screen.png")
    write_rgb_png(screen_path, SCREEN_WIDTH, SCREEN_HEIGHT) do |x, y|
      in_first = x.between?(FIRST_SPRITE_X, FIRST_SPRITE_X + TEMPLATE_CENTER_OFFSET) && y.between?(SPRITE_Y, SPRITE_Y + TEMPLATE_CENTER_OFFSET)
      in_second = x.between?(SECOND_SPRITE_X, SECOND_SPRITE_X + TEMPLATE_CENTER_OFFSET) && y.between?(SPRITE_Y, SPRITE_Y + TEMPLATE_CENTER_OFFSET)
      in_first || in_second ? SPRITE_PIXEL : BACKGROUND
    end

    matcher = described_class.new(template_dir: template_dir, min_confidence: MIN_CONFIDENCE)
    detections = matcher.detect(Frame.new(screen_path))

    expect(detections.map(&:center_x)).to eq([FIRST_SPRITE_X + TEMPLATE_CENTER_OFFSET, SECOND_SPRITE_X + TEMPLATE_CENTER_OFFSET])
    expect(detections.map(&:bottom_y)).to eq([SPRITE_Y + TEMPLATE_BOTTOM_OFFSET, SPRITE_Y + TEMPLATE_BOTTOM_OFFSET])
  end

  def write_rgb_png(path, width, height)
    rows = height.times.map do |y|
      row = width.times.flat_map { |x| yield(x, y) }
      [FILTER_NONE, *row].pack("C*")
    end
    write_png(path, width, height, COLOR_RGB, rows.join)
  end

  def write_grayscale_png(path, width, height, pixels)
    rows = pixels.each_slice(width).map { |row| [FILTER_NONE, *row].pack("C*") }
    write_png(path, width, height, COLOR_GRAYSCALE, rows.join)
  end

  def write_png(path, width, height, color_type, raw_pixels)
    ihdr = [width, height, BIT_DEPTH, color_type, COMPRESSION_METHOD, FILTER_METHOD, INTERLACE_METHOD].pack("NNCCCCC")
    File.binwrite(path, PNG_SIGNATURE + chunk("IHDR", ihdr) + chunk("IDAT", Zlib::Deflate.deflate(raw_pixels)) + chunk("IEND", ""))
  end

  def chunk(type, data)
    payload = type + data
    [data.bytesize].pack("N") + payload + [Zlib.crc32(payload)].pack("N")
  end

  def luminance(red, green, blue)
    ((red * FightingAI::Vision::PngImage::RED_LUMA_WEIGHT) +
      (green * FightingAI::Vision::PngImage::GREEN_LUMA_WEIGHT) +
      (blue * FightingAI::Vision::PngImage::BLUE_LUMA_WEIGHT)) / FightingAI::Vision::PngImage::LUMA_DIVISOR
  end
end
