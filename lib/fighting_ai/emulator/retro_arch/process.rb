require "fileutils"

module FightingAI
  module Emulator
    module RetroArch
      class Process
        LOG_PATH = "/tmp/fighting_ai/retroarch.log"

        attr_reader :pid

        def initialize(rom_path:, core_path:, config_path:, display: ":1")
          @rom_path    = rom_path
          @core_path   = core_path
          @config_path = config_path
          @display     = display
          @pid         = nil
          @log_io      = nil
          @tail_thread = nil
        end

        def start
          FileUtils.mkdir_p(File.dirname(LOG_PATH))
          @log_io = File.open(LOG_PATH, "w")

          env  = { "DISPLAY" => @display, "LIBGL_ALWAYS_SOFTWARE" => "1" }
          args = [
            "retroarch",
            "--verbose",
            "-L", @core_path,
            @rom_path,
            "--appendconfig", @config_path
          ]
          @pid = ::Process.spawn(env, *args, pgroup: 0, [:out, :err] => @log_io)

          @tail_thread = Thread.new do
            File.open(LOG_PATH, "r") do |f|
              loop do
                line = f.gets
                if line
                  $stdout.print("[retroarch] #{line}")
                  $stdout.flush
                else
                  break unless running?
                  sleep(0.05)
                end
              end
            end
          end
        end

        def stop
          return unless running?
          ::Process.kill("-TERM", ::Process.getpgid(@pid)) rescue nil
          ::Process.waitpid(@pid) rescue nil
          @pid = nil
          @log_io&.close
          @log_io = nil
          @tail_thread&.join(1)
          @tail_thread = nil
        end

        def running?
          return false if @pid.nil?
          ::Process.kill(0, @pid)
          true
        rescue Errno::ESRCH, Errno::EPERM
          false
        end

        def last_log_lines(n = 30)
          File.exist?(LOG_PATH) ? File.readlines(LOG_PATH).last(n).join : "(no log)"
        end
      end
    end
  end
end
