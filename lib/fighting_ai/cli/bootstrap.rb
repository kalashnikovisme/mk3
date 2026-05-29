require_relative "../../fighting_ai"

module FightingAI
  module CLI
    BANNER = <<~TEXT
      ┌─────────────────────────────────────────┐
      │         FightingAI Framework            │
      │   Mortal Kombat 3  ·  BizHawk Bridge   │
      └─────────────────────────────────────────┘
    TEXT

    def self.connect(host: "127.0.0.1", port: 7878, timeout: 90)
      emulator = FightingAI.build_bizhawk_adapter(host: host, port: port)

      puts "Waiting for BizHawk on #{host}:#{port}  (timeout #{timeout}s)"
      puts "→ Open BizHawk, load the MK3 ROM, then run: Tools → Lua Console → lua/bizhawk_bridge.lua"
      print "  Listening"

      thread = Thread.new do
        loop do
          sleep 1
          print "."
          $stdout.flush
        end
      end

      begin
        emulator.connect(timeout: timeout)
      rescue => e
        thread.kill
        puts "\n\nConnection failed: #{e.message}"
        exit 1
      end

      thread.kill
      puts " connected.\n\n"
      emulator
    end

    def self.logger(prefix)
      ->(msg) { puts "[#{prefix}] #{msg}" }
    end

    def self.print_result(match, result)
      winner = result[:winner] ? "Player #{result[:winner]}" : "Draw"
      puts "  Winner:  #{winner}"
      puts "  Rounds:  P1 #{result[:player1_rounds_won]} – #{result[:player2_rounds_won]} P2"
      puts "  Frames:  #{match.total_frames}"
      puts "  HP left: P1=#{result[:final_health_p1]} P2=#{result[:final_health_p2]}"
    end

    def self.trap_sigint(cleanup: nil)
      Signal.trap("INT") do
        puts "\n\nStopped."
        cleanup&.call
        exit 0
      end
    end
  end
end
