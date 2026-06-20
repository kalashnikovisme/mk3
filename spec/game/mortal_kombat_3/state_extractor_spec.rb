require "spec_helper"

RSpec.describe FightingAI::Game::MortalKombat3::StateExtractor do
  PLAYER_ONE    = 1
  PLAYER_TWO    = 2
  VISION_P1_X   = 42
  VISION_P1_Y   = 91
  VISION_P2_X   = 210
  VISION_P2_Y   = 88
  VISION_P1_HP  = 120
  VISION_P2_HP  = 80

  let(:snapshot) { { "type" => "frame", "frame" => 1234, "game" => "mortal_kombat_3" } }

  subject(:game_state) do
    described_class.extract(
      snapshot,
      vision_health: { PLAYER_ONE => VISION_P1_HP, PLAYER_TWO => VISION_P2_HP }
    )
  end

  describe ".extract" do
    it "sets the correct frame number" do
      expect(game_state.frame_number).to eq(1234)
    end

    it "extracts player 1 health from vision" do
      expect(game_state.fighter1.health).to eq(VISION_P1_HP)
    end

    it "extracts player 2 health from vision" do
      expect(game_state.fighter2.health).to eq(VISION_P2_HP)
    end

    it "marks the fight as active when both fighters have health" do
      expect(game_state.fight_active?).to be true
    end

    it "sets round timer from vision" do
      state = described_class.extract(snapshot, vision_timer: 90)
      expect(state.round_time_remaining).to eq(90)
    end

    it "returns nil timer when vision provides no reading" do
      state = described_class.extract(snapshot)
      expect(state.round_time_remaining).to be_nil
    end

    it "defaults health to MAX_HEALTH when vision provides no reading" do
      state = described_class.extract(snapshot)
      expect(state.fighter1.health).to eq(FightingAI::Game::MortalKombat3::MemoryMap::MAX_HEALTH)
    end

    it "uses vision positions when provided" do
      state = described_class.extract(
        snapshot,
        vision_positions: {
          PLAYER_ONE => { x: VISION_P1_X, y: VISION_P1_Y },
          PLAYER_TWO => { x: VISION_P2_X, y: VISION_P2_Y }
        }
      )

      expect(state.fighter1.x).to eq(VISION_P1_X)
      expect(state.fighter1.y).to eq(VISION_P1_Y)
      expect(state.fighter2.x).to eq(VISION_P2_X)
      expect(state.fighter2.y).to eq(VISION_P2_Y)
    end

    it "detects round over when a fighter's health is 0" do
      state = described_class.extract(
        snapshot,
        vision_health: { PLAYER_ONE => 50, PLAYER_TWO => 0 }
      )
      expect(state.round_over?).to be true
      expect(state.fight_active?).to be false
    end
  end
end
