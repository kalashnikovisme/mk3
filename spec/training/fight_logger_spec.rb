require "spec_helper"
require "tmpdir"

RSpec.describe FightingAI::Training::FightLogger do
  FRAME_NUMBER = 12
  ROUND_TIMER = 91
  LOGGER_PLAYER_ONE_HEALTH = 166
  LOGGER_PLAYER_TWO_HEALTH = 82
  LOGGER_PLAYER_ONE_X = 47
  LOGGER_PLAYER_ONE_Y = 210
  LOGGER_PLAYER_TWO_X = 173
  LOGGER_PLAYER_TWO_Y = 209
  SNAPSHOT_MS = 17
  CAPTURE_MS = 3
  DETECT_MS = 5
  AGENTS_MS = 211
  RUNTIME_MS = 218
  WORK_MS = 243

  it "writes component and end-to-end frame timings" do
    fighter1 = double(
      "Fighter1",
      health: LOGGER_PLAYER_ONE_HEALTH,
      x: LOGGER_PLAYER_ONE_X,
      y: LOGGER_PLAYER_ONE_Y
    )
    fighter2 = double(
      "Fighter2",
      health: LOGGER_PLAYER_TWO_HEALTH,
      x: LOGGER_PLAYER_TWO_X,
      y: LOGGER_PLAYER_TWO_Y
    )
    game_state = double(
      "GameState",
      frame_number: FRAME_NUMBER,
      round_time_remaining: ROUND_TIMER,
      fighter1: fighter1,
      fighter2: fighter2
    )

    Dir.mktmpdir do |directory|
      path = File.join(directory, "fight.log")
      logger = described_class.new(path)
      logger.log_frame(
        game_state,
        snapshot_ms: SNAPSHOT_MS,
        capture_ms: CAPTURE_MS,
        detect_ms: DETECT_MS,
        agents_ms: AGENTS_MS,
        runtime_ms: RUNTIME_MS,
        work_ms: WORK_MS
      )
      logger.close
      output = File.read(path)

      expect(output).to include("  snapshot_ms: #{SNAPSHOT_MS}\n")
      expect(output).to include("  capture_ms: #{CAPTURE_MS}\n")
      expect(output).to include("  detect_ms: #{DETECT_MS}\n")
      expect(output).to include("  agents_ms: #{AGENTS_MS}\n")
      expect(output).to include("  runtime_ms: #{RUNTIME_MS}\n")
      expect(output).to match(/  fight_log_ms: \d+\n/)
      expect(output).to match(/  total_ms: \d+\n/)
    end
  end
end
