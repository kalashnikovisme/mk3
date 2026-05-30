module FightingAI
  module Emulator
    module RetroArch
      class XephyrServer
        DISPLAY = ":99"
        SCREEN  = "1024x768"

        attr_reader :display

        def initialize(host_display: ENV.fetch("DISPLAY_HOST", ":0"))
          @display      = DISPLAY
          @host_display = host_display
          @pid          = nil
        end

        def start
          @pid = ::Process.spawn(
            { "DISPLAY" => @host_display },
            "Xephyr", @display, "-screen", SCREEN, "-ac",
            [:out, :err] => "/dev/null"
          )
          sleep(1.0)
        end

        def stop
          return unless @pid
          ::Process.kill("TERM", @pid) rescue nil
          ::Process.waitpid(@pid)      rescue nil
          @pid = nil
        end

        def running?
          return false if @pid.nil?
          ::Process.kill(0, @pid)
          true
        rescue Errno::ESRCH, Errno::EPERM
          false
        end
      end
    end
  end
end
