require "fileutils"
require "zlib"

module FightingAI
  module Emulator
    module RetroArch
      class SaveStateReader
        FILE_TIMEOUT  = 5.0
        POLL_INTERVAL = 0.05

        # RetroArch 1.17+ wraps save states in RZIP compression.
        RZIP_MAGIC = "#RZIPv".b.freeze

        # RASTATE binary format (RetroArch + snes9x): sections tagged as
        # "RAM:SIZE:" where SIZE is decimal byte count. WRAM is 131072 bytes.
        RASTATE_RAM_MARKER = "RAM:131072:".b.freeze

        # Older snes9x text format fallback.
        TEXT_RAM_MARKERS = [":RAM\n".b, ":WRAM\n".b].freeze

        attr_reader :watch_dirs

        def initialize(watch_dirs:, rom_basename:)
          @watch_dirs   = Array(watch_dirs)
          @rom_basename = rom_basename
          @wram_offset  = nil
        end

        def current_state_snapshot = snapshot_state_files
        def read_next(before: nil) = read_current

        def read_current
          data = latest_state_file_data
          locate_wram(data) unless @wram_offset
          Snapshot.new(decompress(data).bytes, @wram_offset)
        end

        def try_locate_any
          @watch_dirs.each do |dir|
            Dir.glob(File.join(dir, "**", "*.state*")).sort_by { |f| -File.mtime(f).to_i }.each do |path|
              data = File.binread(path)
              return true if locate_wram(data)
            rescue
              next
            end
          end
          false
        end

        def wram_located?
          !@wram_offset.nil?
        end

        private

        def latest_state_file_data
          files = @watch_dirs.flat_map { |dir| Dir.glob(File.join(dir, "**", "*.state*")) }
          latest = files.max_by { |f| File.mtime(f) rescue Time.at(0) }
          raise "No state files found (searched: #{@watch_dirs.join(', ')})" unless latest
          File.binread(latest)
        end

        def snapshot_state_files
          result = {}
          @watch_dirs.each do |dir|
            Dir.glob(File.join(dir, "**", "*.state*")).each do |f|
              result[f] = File.mtime(f) rescue nil
            end
          end
          result
        end

        def wait_for_update(before)
          deadline = Time.now + FILE_TIMEOUT
          loop do
            @watch_dirs.each do |dir|
              Dir.glob(File.join(dir, "**", "*.state*")).each do |f|
                mtime = File.mtime(f) rescue next
                if before[f].nil? || (mtime && mtime > before[f])
                  data = File.binread(f)
                  return data if data.bytesize > 0
                end
              end
            end
            if Time.now > deadline
              raise "No state file updated within #{FILE_TIMEOUT}s " \
                    "(searched: #{@watch_dirs.join(', ')})"
            end
            sleep(POLL_INTERVAL)
          end
        end

        def decompress(data)
          raw = data.b
          return raw unless raw.start_with?(RZIP_MAGIC)

          chunk_uncompressed = raw[8, 4].unpack1("V")
          total_uncompressed = raw[12, 8].unpack1("Q<")

          pos    = 20
          result = "".b

          while pos < raw.bytesize && result.bytesize < total_uncompressed
            csize = raw[pos, 4]&.unpack1("V")
            break unless csize && csize > 0
            pos += 4
            chunk = raw[pos, csize]
            break unless chunk&.bytesize == csize
            pos += csize
            result << Zlib::Inflate.inflate(chunk)
          end

          result
        rescue Zlib::Error
          data.b
        end

        def locate_wram(data)
          raw = decompress(data)

          # Primary: RASTATE binary format used by RetroArch 1.17+
          idx = raw.index(RASTATE_RAM_MARKER)
          if idx
            wram_start = idx + RASTATE_RAM_MARKER.bytesize
            if wram_start + 0x20000 <= raw.bytesize
              @wram_offset = wram_start
              return true
            end
          end

          # Fallback: older snes9x text-based format
          TEXT_RAM_MARKERS.each do |marker|
            idx = raw.index(marker)
            next unless idx

            size_start = idx + marker.bytesize
            nl         = raw.index("\n".b, size_start)
            next unless nl

            size       = raw[size_start...nl].strip.to_i
            wram_start = nl + 1

            if size >= 0x20000 && wram_start + size <= raw.bytesize
              @wram_offset = wram_start
              return true
            end
          end

          # Last resort: scan for MK3 health-value signature
          bytes = raw.bytes
          bytes.each_index do |i|
            break if i + 0x3B00 > bytes.length
            if mk3_signature?(bytes, i)
              @wram_offset = i
              return true
            end
          end

          false
        end

        def mk3_signature?(bytes, base)
          return false if base + 0x3B00 > bytes.length
          p1_health = bytes[base + 0x36D4]
          p2_health = bytes[base + 0x3898]
          screen    = bytes[base + 0x3A7E]
          valid_screens = [*(0x00..0x09), 0x0B, 0x0C, 0x0D, 0x0F, 0x11, 0x13]
          (0..0xA6).include?(p1_health) &&
            (0..0xA6).include?(p2_health) &&
            valid_screens.include?(screen)
        end

        class Snapshot
          def initialize(bytes, wram_offset)
            @bytes  = bytes
            @offset = wram_offset
          end

          def read_u8(wram_addr)
            @bytes[@offset + wram_addr] || 0
          end

          def read_u16_le(wram_addr)
            lo = @bytes[@offset + wram_addr] || 0
            hi = @bytes[@offset + wram_addr + 1] || 0
            lo | (hi << 8)
          end
        end
      end
    end
  end
end
