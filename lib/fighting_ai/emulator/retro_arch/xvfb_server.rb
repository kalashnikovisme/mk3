module FightingAI
  module Emulator
    module RetroArch
      class XvfbServer
        DISPLAY = ":99"
        SCREEN  = "1024x768x24"

        attr_reader :display

        def initialize
          @display = DISPLAY
          @pid     = nil
        end

        def start
          @pid = ::Process.spawn(
            "Xvfb", @display, "-screen", "0", SCREEN,
            [:out, :err] => "/dev/null"
          )
          sleep(0.5)
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
