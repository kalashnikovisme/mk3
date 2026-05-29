require "socket"
require "json"

module FightingAI
  module Emulator
    module BizHawk
      # TCP server that the Lua script inside BizHawk connects to.
      # Protocol: newline-delimited JSON messages.
      #
      # Lua sends:  { "type": "frame", ... }
      # Ruby sends: { "type": "input", ... } or { "type": "noop" }
      class BridgeServer
        DEFAULT_HOST = "127.0.0.1"
        DEFAULT_PORT = 7878

        attr_reader :host, :port

        def initialize(host: DEFAULT_HOST, port: DEFAULT_PORT)
          @host         = host
          @port         = port
          @server       = nil
          @client       = nil
          @running      = false
          @pending_input = nil
          @mutex        = Mutex.new
        end

        def start
          @server  = TCPServer.new(@host, @port)
          @running = true
        end

        def accept_connection(timeout: 30)
          ready = IO.select([@server], nil, nil, timeout)
          raise "BizHawk did not connect within #{timeout}s" unless ready
          @client = @server.accept
        end

        def connected?
          !@client.nil? && !@client.closed?
        end

        def stop
          @running = false
          @client&.close rescue nil
          @server&.close rescue nil
          @client = nil
          @server = nil
        end

        # Block until a frame snapshot arrives. Returns parsed Hash.
        def receive_frame
          raise "Not connected" unless connected?
          line = @client.gets
          raise "BizHawk disconnected" if line.nil?
          JSON.parse(line.strip)
        end

        # Queue an input response for the next send_response call.
        def queue_input(player_index, buttons)
          @mutex.synchronize do
            @pending_input = {
              type:    "input",
              player:  player_index,
              buttons: buttons
            }
          end
        end

        def send_noop
          send_message(type: "noop")
        end

        def send_response
          payload = @mutex.synchronize { @pending_input&.dup }
          if payload
            send_message(payload)
            @mutex.synchronize { @pending_input = nil }
          else
            send_noop
          end
        end

        def send_load_state(slot)
          send_message(type: "load_state", slot: slot)
        end

        def send_save_state(slot)
          send_message(type: "save_state", slot: slot)
        end

        private

        def send_message(payload)
          raise "Not connected" unless connected?
          @client.puts(JSON.generate(payload))
        end
      end
    end
  end
end
