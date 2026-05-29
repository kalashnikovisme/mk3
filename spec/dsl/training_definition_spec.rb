require "spec_helper"

RSpec.describe FightingAI::DSL::TrainingDefinition do
  subject(:definition) do
    FightingAI.training(:mk3_test) do
      game :mortal_kombat_3
      mode :imitation_learning

      dataset do
        recordings_path "data/recordings/mk3"
      end

      reward do
        plus  :damage_dealt, weight: 1.0
        minus :damage_taken, weight: 1.0
        plus  :round_win,    weight: 10.0
        minus :round_loss,   weight: 10.0
      end
    end
  end

  it "stores the training id" do
    expect(definition.training_id).to eq(:mk3_test)
  end

  it "stores the game id" do
    expect(definition.game_id).to eq(:mortal_kombat_3)
  end

  it "stores the mode" do
    expect(definition.mode).to eq(:imitation_learning)
  end

  it "stores the dataset recordings path" do
    expect(definition.dataset_definition.recordings_path).to eq("data/recordings/mk3")
  end

  it "stores reward components" do
    components = definition.reward_definition.components
    signs  = components.map { |c| c[:sign] }
    signals = components.map { |c| c[:signal] }

    expect(signals).to include(:damage_dealt, :damage_taken, :round_win, :round_loss)
    expect(signs).to include(:plus, :minus)
  end
end
