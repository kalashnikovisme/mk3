require "spec_helper"

RSpec.describe FightingAI::Emulator::RetroArch::NetworkCommands do
  FRAME_ADVANCE_COMMAND = "FRAMEADVANCE"
  TEST_HOST = "127.0.0.2"
  TEST_PORT = 55_356

  it "uses RetroArch's supported frame-advance command token" do
    allow(described_class).to receive(:send_command)

    described_class.frame_advance(host: TEST_HOST, port: TEST_PORT)

    expect(described_class).to have_received(:send_command).with(
      FRAME_ADVANCE_COMMAND,
      host: TEST_HOST,
      port: TEST_PORT
    )
  end
end
