module FightingAI
  module Emulator
    module RetroArch
      class Process
        attr_reader :pid

        def initialize(rom_path:, core_path:, config_path:, display: ":1")
          @rom_path    = rom_path
          @core_path   = core_path
          @config_path = config_path
          @display     = display
          @pid         = nil
        end

        def start
          env  = { "DISPLAY" => @display }
          args = [
            "retroarch",
            "-L", @core_path,
            @rom_path,
            "--config", @config_path,
            "--no-stdin"
          ]
          @pid = ::Process.spawn(env, *args, pgroup: 0, [:out, :err] => "/dev/null")
        end

        def stop
          return unless running?
          ::Process.kill("-TERM", ::Process.getpgid(@pid)) rescue nil
          ::Process.waitpid(@pid) rescue nil
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
