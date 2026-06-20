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
      round_time_normalized:  0.9,
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
      obs = make_obs(my_x_normalized: 0.1, opponent_x_normalized: 0.7)
      expect(agent.act(obs).name).to eq(:walk_forward)
    end

    it "attacks when close to the opponent" do
      obs = make_obs(my_x_normalized: 0.3, opponent_x_normalized: 0.35)
      action = agent.act(obs)
      expect(%i[high_punch low_kick high_kick low_punch]).to include(action.name)
    end

    it "blocks when health is low and opponent is close" do
      obs = make_obs(my_health_pct: 0.2, my_x_normalized: 0.3, opponent_x_normalized: 0.35)
      expect(agent.act(obs).name).to eq(:block)
    end
  end
end
