# frozen_string_literal: true

require "spec_helper"
require "fighting_ai/emulator/retro_arch/xephyr_server"

RSpec.describe FightingAI::Emulator::RetroArch::XephyrServer do
  it "opens a wide enough watch desktop for RetroArch and the reconstructed scene" do
    expect(described_class::SCREEN).to eq(
      "#{FightingAI::Emulator::RetroArch::ConfigBuilder::WATCH_SCREEN_WIDTH}x" \
      "#{FightingAI::Emulator::RetroArch::ConfigBuilder::WATCH_SCREEN_HEIGHT}"
    )
  end
end
