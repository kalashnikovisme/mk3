# frozen_string_literal: true

require 'spec_helper'
require 'fighting_ai/cli/display'

module PPODisplaySpecConstants
  DISPLAY = FightingAI::CLI::PPODisplay
  TRACK_WIDTH = DISPLAY::SCREEN_TRACK_WIDTH
  TRACK_LEFT_BOUNDARY = DISPLAY::SCREEN_LEFT_BOUNDARY
  TRACK_RIGHT_BOUNDARY = DISPLAY::SCREEN_RIGHT_BOUNDARY
  TRACK_EMPTY_CELL = DISPLAY::SCREEN_EMPTY_CELL
  LEFT_CHARACTER_DOT = DISPLAY::SCREEN_LEFT_CHARACTER_DOT
  RIGHT_CHARACTER_DOT = DISPLAY::SCREEN_RIGHT_CHARACTER_DOT
  OVERLAP_DOT = DISPLAY::SCREEN_OVERLAP_DOT
  POSITION_MIN = DISPLAY::POSITION_MIN
  POSITION_MAX = DISPLAY::POSITION_MAX
  TRACK_LAST_INDEX = DISPLAY::TRACK_LAST_INDEX
  EDGE_DOT_COUNT = 2
  ANSI_ESCAPE_PATTERN = /\e\[[0-9;]*m/
  LEFT_CHARACTER_POSITION = POSITION_MIN
  RIGHT_CHARACTER_POSITION = POSITION_MAX
  BELOW_SCREEN_POSITION = POSITION_MIN - POSITION_MAX
  ABOVE_SCREEN_POSITION = POSITION_MAX + POSITION_MAX
end

RSpec.describe FightingAI::CLI::PPODisplay do
  subject(:display) { described_class.new }

  describe '#screen_track' do
    it 'draws a bounded screen line with player dots at their scaled positions' do
      track = plain(display.send(:screen_track, c::LEFT_CHARACTER_POSITION, c::RIGHT_CHARACTER_POSITION))

      expected_cells = "#{c::LEFT_CHARACTER_DOT}#{c::TRACK_EMPTY_CELL * (c::TRACK_WIDTH - c::EDGE_DOT_COUNT)}#{c::RIGHT_CHARACTER_DOT}"
      expect(track).to eq("#{c::TRACK_LEFT_BOUNDARY}#{expected_cells}#{c::TRACK_RIGHT_BOUNDARY}")
    end

    it 'draws the lower x position as the left character' do
      track = plain(display.send(:screen_track, c::RIGHT_CHARACTER_POSITION, c::LEFT_CHARACTER_POSITION))

      expected_cells = "#{c::LEFT_CHARACTER_DOT}#{c::TRACK_EMPTY_CELL * (c::TRACK_WIDTH - c::EDGE_DOT_COUNT)}#{c::RIGHT_CHARACTER_DOT}"
      expect(track).to eq("#{c::TRACK_LEFT_BOUNDARY}#{expected_cells}#{c::TRACK_RIGHT_BOUNDARY}")
    end

    it 'clamps positions outside the screen range' do
      track = plain(display.send(:screen_track, c::BELOW_SCREEN_POSITION, c::ABOVE_SCREEN_POSITION))

      expected_cells = "#{c::LEFT_CHARACTER_DOT}#{c::TRACK_EMPTY_CELL * (c::TRACK_WIDTH - c::EDGE_DOT_COUNT)}#{c::RIGHT_CHARACTER_DOT}"
      expect(track).to eq("#{c::TRACK_LEFT_BOUNDARY}#{expected_cells}#{c::TRACK_RIGHT_BOUNDARY}")
    end

    it 'marks overlapping positions with one dot' do
      track = plain(display.send(:screen_track, c::LEFT_CHARACTER_POSITION, c::LEFT_CHARACTER_POSITION))

      expected_cells = "#{c::OVERLAP_DOT}#{c::TRACK_EMPTY_CELL * c::TRACK_LAST_INDEX}"
      expect(track).to eq("#{c::TRACK_LEFT_BOUNDARY}#{expected_cells}#{c::TRACK_RIGHT_BOUNDARY}")
    end
  end

  def plain(text)
    text.gsub(c::ANSI_ESCAPE_PATTERN, '')
  end

  def c
    PPODisplaySpecConstants
  end
end
