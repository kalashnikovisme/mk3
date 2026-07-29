# frozen_string_literal: true

require 'spec_helper'
require 'fighting_ai/cli/reconstructed_scene_window'

RSpec.describe FightingAI::CLI::ReconstructedSceneWindow do
  PIXEL_BYTES = FightingAI::Observation::FrameObservation::RGB_CHANNELS
  IMAGE_WIDTH = 5
  IMAGE_HEIGHT = 5
  TOTAL_PIXELS = IMAGE_WIDTH * IMAGE_HEIGHT
  BLACK = [0, 0, 0].freeze
  RED = [255, 0, 0].freeze
  GREEN = [0, 255, 0].freeze
  BLUE = [0, 0, 255].freeze
  WHITE = [255, 255, 255].freeze
  CYAN = [0, 255, 255].freeze
  MAGENTA = [255, 0, 255].freeze
  YELLOW = [255, 255, 0].freeze
  SOURCE_MARKER = [12, 34, 56].freeze
  DETECTION_X = 1
  DETECTION_Y = 1
  DETECTION_WIDTH = 3
  DETECTION_HEIGHT = 3
  BORDER_COLOR = [0, 200, 255].freeze
  TEXT_FRAME_WIDTH = 20
  TEXT_FRAME_HEIGHT = 20
  TEXT_LEFT_MARGIN = 8
  TEXT_TOP_MARGIN = 8

  subject(:window) do
    described_class.new(
      width: IMAGE_WIDTH,
      height: IMAGE_HEIGHT
    )
  end

  describe '#compose_frame' do
    it 'copies only detected sprite pixels into the same coordinates on a blank canvas' do
      source_pixels = Array.new(TOTAL_PIXELS, BLACK)
      source_pixels[index_for(2, 2)] = SOURCE_MARKER
      source = frame_bytes(*source_pixels)
      frame_observation = FightingAI::Observation::FrameObservation.from_raw_rgb(
        source,
        width: IMAGE_WIDTH,
        height: IMAGE_HEIGHT
      )
      detection = FightingAI::Vision::Detection.new(
        template_name: 'idle_fighting_stance/01_left',
        x: DETECTION_X,
        y: DETECTION_Y,
        width: DETECTION_WIDTH,
        height: DETECTION_HEIGHT,
        center_x: 0,
        bottom_y: 0,
        confidence: 0.99
      )
      vision_snapshot = { player_detections: { 1 => detection } }

      composed = window.send(:compose_frame, frame_observation, vision_snapshot)

      expect(pixel_at(composed, 0, 0)).to eq([255, 255, 255])
      expect(pixel_at(composed, 1, 1)).to eq(BORDER_COLOR)
      expect(pixel_at(composed, 2, 2)).to eq(SOURCE_MARKER)
      expect(pixel_at(composed, 3, 3)).to eq(BORDER_COLOR)
      expect(pixel_at(composed, 4, 4)).to eq([255, 255, 255])
    end
  end

  describe '#ffplay_command' do
    it 'passes the raw video input size to ffplay' do
      command = window.send(:ffplay_command)

      expect(command).to include(
        described_class::FFPLAY_VIDEO_SIZE_ARG,
        "#{IMAGE_WIDTH}x#{IMAGE_HEIGHT}"
      )
    end
  end

  describe '#compose_frame' do
    it 'renders the TEST label in white' do
      frame_observation = FightingAI::Observation::FrameObservation.from_raw_rgb(
        ("\x00" * (TEXT_FRAME_WIDTH * TEXT_FRAME_HEIGHT * PIXEL_BYTES)).b,
        width: TEXT_FRAME_WIDTH,
        height: TEXT_FRAME_HEIGHT
      )

      composed = window.send(:compose_frame, frame_observation, { player_detections: {} })

      expect(pixel_at(composed, TEXT_LEFT_MARGIN, TEXT_TOP_MARGIN, frame_width: TEXT_FRAME_WIDTH)).to eq(WHITE)
    end
  end

  def frame_bytes(*pixels)
    pixels.flatten.pack('C*')
  end

  def pixel_at(bytes, x, y, frame_width: IMAGE_WIDTH)
    offset = (y * frame_width + x) * PIXEL_BYTES
    bytes.byteslice(offset, PIXEL_BYTES).bytes
  end

  def index_for(x, y)
    (y * IMAGE_WIDTH) + x
  end
end
