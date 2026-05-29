require_relative "../adapter"
require_relative "bridge_server"

module FightingAI
  module Emulator
    module BizHawk
      class Adapter < FightingAI::Emulator::Adapter
        attr_reader :bridge

        def initialize(host: BridgeServer::DEFAULT_HOST, port: BridgeServer::DEFAULT_PORT)
          @bridge     = BridgeServer.new(host: host, port: port)
          @recording  = false
        end

        def connect(timeout: 30)
          @bridge.start
          @bridge.accept_connection(timeout: timeout)
        end

        def disconnect
          @bridge.stop
        end

        def connected?
          @bridge.connected?
        end

        def next_frame_snapshot
          @bridge.receive_frame
        end

        def send_input(player_index, buttons)
          @bridge.queue_input(player_index, buttons)
          @bridge.send_response
        end

        def send_noop
          @bridge.send_noop
        end

        def load_save_state(slot)
          @bridge.send_load_state(slot)
        end

        def save_state(slot)
          @bridge.send_save_state(slot)
        end

        # Memory reads go through the Lua bridge (Lua sends them in frame snapshots).
        # Direct memory reads are not available without a separate Lua RPC call,
        # so this raises unless the subclass overrides it.
        def read_memory(address, byte_count: 1)
          raise NotImplementedError, "Direct memory reads must be requested via the Lua frame snapshot"
        end

        def start_recording(path)
          @recording_path = path
          @recording      = true
        end

        def stop_recording
          @recording      = false
          @recording_path = nil
        end

        def recording?
          @recording
        end
      end
    end
  end
end
