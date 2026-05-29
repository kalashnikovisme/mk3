module FightingAI
  module Emulator
    module RetroArch
      class WramReader
        # SNES WRAM starts at bus address 0x7E0000. The snes9x core maps it
        # into a contiguous host region; we scan for it by matching MK3's
        # invariant bytes rather than relying on a fixed offset.
        WRAM_BUS_OFFSET = 0x7E0000

        MIN_REGION_SIZE = 512

        def initialize
          @pid       = nil
          @mem_file  = nil
          @wram_base = nil
        end

        def attach(pid)
          @pid      = pid
          @mem_file = File.open("/proc/#{pid}/mem", "rb")
        end

        def detach
          @mem_file&.close rescue nil
          @mem_file  = nil
          @wram_base = nil
        end

        def scan_for_wram
          maps = File.read("/proc/#{@pid}/maps")
          maps.each_line do |line|
            next unless line.include?("rw-p")

            range_str = line.split(" ").first
            start_addr, end_addr = range_str.split("-").map { |h| h.to_i(16) }
            size = end_addr - start_addr
            next if size < MIN_REGION_SIZE

            begin
              @mem_file.seek(start_addr)
              data = @mem_file.read([size, 0x10000].min)
              next unless data && data.bytesize >= MIN_REGION_SIZE

              if mk3_wram?(data)
                @wram_base = start_addr
                return true
              end
            rescue Errno::EIO, Errno::ESRCH, Errno::EPERM
              next
            end
          end

          false
        end

        def wram_found?
          !@wram_base.nil?
        end

        def read_u8(wram_addr)
          host_addr = @wram_base + wram_addr
          @mem_file.seek(host_addr)
          @mem_file.read(1).unpack1("C")
        rescue Errno::EIO, Errno::ESRCH
          0
        end

        def read_u16_le(wram_addr)
          host_addr = @wram_base + wram_addr
          @mem_file.seek(host_addr)
          @mem_file.read(2).unpack1("v")
        rescue Errno::EIO, Errno::ESRCH
          0
        end

        private

        def mk3_wram?(data)
          return false if data.bytesize < 0x200

          b = data.bytes
          b[0x011C] == 160 &&
            b[0x014C] == 160 &&
            (0..3).include?(b[0x0101]) &&
            (1..5).include?(b[0x018A]) &&
            (0..160).include?(b[0x011A]) &&
            (0..160).include?(b[0x014A])
        end
      end
    end
  end
end
