require "spec_helper"

RSpec.describe FightingAI::Agent::RuleBased do
  let(:base_obs_attrs) do
    {
      frame_number:           100,
      my_health_pct:          0.8,
      opponent_health_pct:    0.8,
      my_x_normalized:        0.3,
      my_y_normalized:        0.0,
      opponent_x_normalized:  0.5,
      opponent_y_normalized:  0.0,
      distance_normalized:    0.3,
      my_facing:              :right,
      opponent_facing:        :left,
      my_in_hitstun:          false,
      my_in_blockstun:        false,
      my_knocked_down:        false,
      my_airborne:            false,
      opponent_in_hitstun:    false,
      opponent_in_blockstun:  false,
      opponent_knocked_down:  false,
      opponent_airborne:      false,
      round_time_normalized:  0.9,
      round_number:           1,
      raw:                    nil
    }
  end

  def make_obs(**overrides)
    FightingAI::Core::Observation.new(**base_obs_attrs.merge(overrides))
  end

  subject(:agent) { described_class.new(player_index: 2) }

  describe "#act" do
    it "returns a Core::Action" do
      obs = make_obs
      expect(agent.act(obs)).to be_a(FightingAI::Core::Action)
    end

    it "walks forward when far from opponent" do
      obs = make_obs(distance_normalized: 0.6)
      expect(agent.act(obs).name).to eq(:walk_forward)
    end

    it "attacks when the opponent is stunned" do
      obs = make_obs(distance_normalized: 0.05, opponent_in_hitstun: true)
      action = agent.act(obs)
      expect(action.name).not_to eq(:idle)
    end

    it "blocks when health is low and opponent is close" do
      obs = make_obs(my_health_pct: 0.2, distance_normalized: 0.05)
      expect(agent.act(obs).name).to eq(:block)
    end

    it "returns idle when in hitstun" do
      obs = make_obs(my_in_hitstun: true)
      expect(agent.act(obs).name).to eq(:idle)
    end
  end
end
