require "spec_helper"
require "socket"
require "json"

RSpec.describe FightingAI::Emulator::BizHawk::BridgeServer do
  let(:port) { 17878 }

  subject(:server) { described_class.new(host: "127.0.0.1", port: port) }

  after { server.stop rescue nil }

  describe "#start and connection" do
    it "starts a TCP server and accepts a client" do
      server.start

      client = TCPSocket.new("127.0.0.1", port)
      server.accept_connection(timeout: 2)

      expect(server.connected?).to be true
      client.close
    end
  end

  describe "frame receive and input send" do
    let(:frame_payload) do
      {
        "type"       => "frame",
        "frame"      => 42,
        "game"       => "mortal_kombat_3",
        "game_state" => 2,
        "round"      => 1,
        "timer"      => 90,
        "match_over" => false,
        "players"    => {
          "1" => { "health" => 100, "max_health" => 144, "x" => 100, "y" => 40, "facing" => 0, "anim" => 0, "anim_frame" => 0, "state" => 0 },
          "2" => { "health" => 80,  "max_health" => 144, "x" => 200, "y" => 40, "facing" => 1, "anim" => 0, "anim_frame" => 0, "state" => 0 }
        }
      }
    end

    it "receives a frame snapshot" do
      server.start
      client = TCPSocket.new("127.0.0.1", port)
      server.accept_connection(timeout: 2)

      client.puts(JSON.generate(frame_payload))
      snapshot = server.receive_frame

      expect(snapshot["frame"]).to eq(42)
      expect(snapshot["players"]["1"]["health"]).to eq(100)
      client.close
    end

    it "sends an input response" do
      server.start
      client = TCPSocket.new("127.0.0.1", port)
      server.accept_connection(timeout: 2)

      server.queue_input(2, { "Right" => true, "A" => true })
      server.send_response

      line = client.gets
      response = JSON.parse(line)
      expect(response["type"]).to eq("input")
      expect(response["player"]).to eq(2)
      expect(response["buttons"]["Right"]).to be true

      client.close
    end

    it "sends noop when no input is queued" do
      server.start
      client = TCPSocket.new("127.0.0.1", port)
      server.accept_connection(timeout: 2)

      server.send_noop

      line = client.gets
      response = JSON.parse(line)
      expect(response["type"]).to eq("noop")

      client.close
    end
  end
end
