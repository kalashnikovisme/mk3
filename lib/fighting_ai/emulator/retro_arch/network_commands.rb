require "socket"

module FightingAI
  module Emulator
    module RetroArch
      module NetworkCommands
        DEFAULT_HOST = "127.0.0.1"
        DEFAULT_PORT = 55355

        def self.pause(host: DEFAULT_HOST, port: DEFAULT_PORT)
          send_command("PAUSE_TOGGLE", host: host, port: port)
        end

        def self.unpause(host: DEFAULT_HOST, port: DEFAULT_PORT)
          send_command("PAUSE_TOGGLE", host: host, port: port)
        end

        def self.reset(host: DEFAULT_HOST, port: DEFAULT_PORT)
          send_command("RESET", host: host, port: port)
        end

        def self.quit(host: DEFAULT_HOST, port: DEFAULT_PORT)
          send_command("QUIT", host: host, port: port)
        end

        def self.save_state(slot: nil, host: DEFAULT_HOST, port: DEFAULT_PORT)
          send_command("STATE_SLOT #{slot}", host: host, port: port) if slot
          send_command("SAVE_STATE", host: host, port: port)
        end

        def self.load_state(slot: nil, host: DEFAULT_HOST, port: DEFAULT_PORT)
          send_command("STATE_SLOT #{slot}", host: host, port: port) if slot
          send_command("LOAD_STATE", host: host, port: port)
        end

        def self.screenshot(host: DEFAULT_HOST, port: DEFAULT_PORT)
          send_command("SCREENSHOT", host: host, port: port)
        end

        def self.send_command(cmd, host:, port:)
          socket = UDPSocket.new
          socket.send("#{cmd}\n", 0, host, port)
        ensure
          socket&.close
        end
      end
    end
  end
end
