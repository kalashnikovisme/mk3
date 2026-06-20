require "spec_helper"

RSpec.describe FightingAI::Emulator::RetroArch::NetworkCommands do
  FRAME_ADVANCE_COMMAND = "FRAMEADVANCE"
  LOAD_STATE_COMMAND = "LOAD_STATE_SLOT 0"
  PAUSE_COMMAND = "PAUSE_TOGGLE"
  TEST_STATE_SLOT = 0
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

  it "orders load-state before pause on the same command socket" do
    allow(described_class).to receive(:send_commands)

    described_class.load_state_and_pause(slot: TEST_STATE_SLOT, host: TEST_HOST, port: TEST_PORT)

    expect(described_class).to have_received(:send_commands).with(
      [LOAD_STATE_COMMAND, PAUSE_COMMAND],
      host: TEST_HOST,
      port: TEST_PORT
    )
  end
end
