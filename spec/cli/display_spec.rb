# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'tempfile'
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
  FIT_TEST_TERMINAL_WIDTH = 24
  FIT_TEST_VISIBLE_WIDTH = FIT_TEST_TERMINAL_WIDTH - DISPLAY::TERMINAL_WIDTH_PADDING
  UPDATE_TEST_TERMINAL_WIDTH = 80
  UPDATE_TEST_TERMINAL_HEIGHT = 24
  UPDATE_TEST_TIMER = 91
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

  describe '#fit_to_terminal_width' do
    it 'truncates long colored lines to the visible terminal width' do
      allow(display).to receive(:terminal_width).and_return(c::FIT_TEST_TERMINAL_WIDTH)

      fitted = display.send(:fit_to_terminal_width, 'abcdefghijklmnopqrstuvwxyz'.green)

      expect(plain(fitted).length).to eq(c::FIT_TEST_VISIBLE_WIDTH)
    end
  end

  describe '#update' do
    it 'renders the status block as separate status and chart lines' do
      fake_stdout = FakeStdout.new(width: c::UPDATE_TEST_TERMINAL_WIDTH, height: c::UPDATE_TEST_TERMINAL_HEIGHT)
      original_stdout = $stdout
      $stdout = fake_stdout

      display.update(game_state: game_state, stage_name: 'The Rooftop')

      plain_output = plain(fake_stdout.string)
      expect(plain_output.lines.size).to eq(2)
      expect(plain_output.lines[0]).to include("Ep")
      expect(plain_output.lines[0]).not_to include("screen")
      expect(plain_output.lines[1]).to include("screen |")
    ensure
      $stdout = original_stdout
    end

    it 'writes the position graphic to the log file in real time' do
      fake_stdout = FakeStdout.new(width: c::UPDATE_TEST_TERMINAL_WIDTH, height: c::UPDATE_TEST_TERMINAL_HEIGHT)
      original_stdout = $stdout
      $stdout = fake_stdout
      temp_log = Tempfile.new("ppo_display")
      display.log_file = temp_log

      display.update(game_state: game_state, stage_name: 'The Rooftop')

      temp_log.rewind
      logged_line = temp_log.read.force_encoding("UTF-8")

      expect(logged_line).to include("screen |")
      expect(logged_line).to include("●")
      expect(logged_line).to include("P1")
      expect(logged_line).to include("P2")
      expect(logged_line.lines.count).to eq(2)
    ensure
      temp_log&.close
      temp_log&.unlink
      $stdout = original_stdout
    end
  end

  def plain(text)
    text.gsub(c::ANSI_ESCAPE_PATTERN, '')
  end

  def game_state
    instance_double(
      FightingAI::Core::GameState,
      fighter1: fighter(c::LEFT_CHARACTER_POSITION),
      fighter2: fighter(c::RIGHT_CHARACTER_POSITION),
      round_time_remaining: c::UPDATE_TEST_TIMER,
      fight_active?: true,
      round_over?: false
    )
  end

  def fighter(position_x)
    instance_double(
      FightingAI::Core::FighterState,
      health: FightingAI::CLI::PPODisplay::MAX_HEALTH,
      x: position_x
    )
  end

  def c
    PPODisplaySpecConstants
  end

  class FakeStdout
    attr_reader :string

    def initialize(width:, height:)
      @width = width
      @height = height
      @string = +''
    end

    def print(value)
      @string << value
    end

    def write(value)
      @string << value
      value.length
    end

    def flush; end

    def winsize
      [@height, @width]
    end
  end
end
