require "spec_helper"

RSpec.describe FightingAI::DSL::GameDefinition do
  subject(:definition) do
    FightingAI.configure_game(:test_fighter) do
      emulator :bizhawk

      inputs do
        button :up
        button :down
        button :low_punch
      end

      actions do
        action :idle
        action :walk_forward
        action :low_punch
      end
    end
  end

  it "stores the game id" do
    expect(definition.game_id).to eq(:test_fighter)
  end

  it "stores the emulator id" do
    expect(definition.emulator_id).to eq(:bizhawk)
  end

  it "records declared buttons" do
    expect(definition.available_buttons).to include(:up, :down, :low_punch)
  end

  it "records declared actions" do
    expect(definition.available_actions).to include(:idle, :walk_forward, :low_punch)
  end
end
