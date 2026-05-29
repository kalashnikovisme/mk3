require "spec_helper"

RSpec.describe FightingAI::Game::MortalKombat3::StateExtractor do
  let(:snapshot) do
    {
      "type"       => "frame",
      "frame"      => 1234,
      "game"       => "mortal_kombat_3",
      "game_state" => 2,
      "round"      => 1,
      "timer"      => 90,
      "match_over" => false,
      "players"    => {
        "1" => {
          "health"     => 120,
          "max_health" => 144,
          "x"          => 100,
          "y"          => 40,
          "facing"     => 0,
          "anim"       => 5,
          "anim_frame" => 2,
          "state"      => 0
        },
        "2" => {
          "health"     => 80,
          "max_health" => 144,
          "x"          => 200,
          "y"          => 40,
          "facing"     => 1,
          "anim"       => 3,
          "anim_frame" => 0,
          "state"      => 1  # in_hitstun
        }
      }
    }
  end

  subject(:game_state) { described_class.extract(snapshot) }

  describe ".extract" do
    it "sets the correct frame number" do
      expect(game_state.frame_number).to eq(1234)
    end

    it "extracts player 1 health" do
      expect(game_state.fighter1.health).to eq(120)
    end

    it "extracts player 2 health" do
      expect(game_state.fighter2.health).to eq(80)
    end

    it "extracts player 1 facing right" do
      expect(game_state.fighter1.facing.right?).to be true
    end

    it "extracts player 2 facing left" do
      expect(game_state.fighter2.facing.left?).to be true
    end

    it "detects hitstun from state bitfield" do
      expect(game_state.fighter2.in_hitstun).to be true
    end

    it "marks the fight as active" do
      expect(game_state.fight_active?).to be true
    end

    it "sets round number" do
      expect(game_state.round_number).to eq(1)
    end

    it "sets round timer" do
      expect(game_state.round_time_remaining).to eq(90)
    end
  end
end
