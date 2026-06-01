require "fileutils"
require "zlib"

module FightingAI
  module Emulator
    module RetroArch
      class SaveStateReader
        FILE_TIMEOUT  = 1.0
        POLL_INTERVAL = 0.05

        # RetroArch 1.17+ wraps save states in RZIP compression.
        RZIP_MAGIC = "#RZIPv".b.freeze

        # RASTATE binary format (RetroArch + snes9x): sections tagged as
        # "RAM:SIZE:" where SIZE is decimal byte count. WRAM is 131072 bytes.
        RASTATE_RAM_MARKER = "RAM:131072:".b.freeze

        # Older snes9x text format fallback.
        TEXT_RAM_MARKERS = [":RAM\n".b, ":WRAM\n".b].freeze

        WRAM_SIZE = 131_072  # 128 KB — SNES WRAM bus address 0x7E0000

        attr_reader :watch_dirs, :wram_offset

        def initialize(watch_dirs:, rom_basename:)
          @watch_dirs   = Array(watch_dirs)
          @rom_basename = rom_basename
          @wram_offset  = nil
        end

        def current_state_snapshot = snapshot_state_files
        def read_next(before: nil) = read_current

        def read_after_update(before)
          data  = wait_for_update(before)
          build_snapshot(data)
        end

        def read_current
          build_snapshot(latest_state_file_data)
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

        def wram_source_info
          {
            source:       @wram_source || "snes9x save state (format unknown)",
            base_address: 0x7E0000,
            wram_offset:  @wram_offset,
            size:         WRAM_SIZE
          }
        end

        private

        # Decompress data, validate/re-locate WRAM offset, return Snapshot.
        # Clears @wram_offset before re-locating so a failed locate_wram never
        # leaves a stale offset that passes the nil-guard.
        def build_snapshot(data)
          bytes = decompress(data).bytes
          if @wram_offset.nil? || @wram_offset + WRAM_SIZE > bytes.size
            @wram_offset = nil
            locate_wram(data)
            raise "WRAM not found in state (#{bytes.size} decompressed bytes)" unless @wram_offset
          end
          Snapshot.new(bytes, @wram_offset)
        end

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
                next unless before[f].nil? || (mtime && mtime > before[f])
                data = File.binread(f)
                # Reject partially-written files: RetroArch writes the RZIP
                # header before the compressed payload, so a non-empty file can
                # still decompress to 0 bytes.  Spin until the decompressed
                # content is at least WRAM_SIZE bytes.
                next if decompress(data).bytesize < WRAM_SIZE
                return data
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
            if wram_start + WRAM_SIZE <= raw.bytesize
              @wram_offset = wram_start
              @wram_source = "snes9x save state (RASTATE binary)"
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

            if size >= WRAM_SIZE && wram_start + size <= raw.bytesize
              @wram_offset = wram_start
              @wram_source = "snes9x save state (text format)"
              return true
            end
          end

          # Last resort: scan for MK3 health-value signature
          bytes = raw.bytes
          bytes.each_index do |i|
            break if i + WRAM_SIZE > bytes.length
            if mk3_signature?(bytes, i)
              @wram_offset = i
              @wram_source = "snes9x save state (MK3 signature scan)"
              return true
            end
          end

          false
        end

        def mk3_signature?(bytes, base)
          return false if base + 0x3B00 > bytes.length
          p1_health = bytes[base + 0x3634]
          p2_health = bytes[base + 0x37F6]
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

          # Returns exactly WRAM_SIZE bytes of raw SNES WRAM as a binary String.
          def raw_wram
            slice = @bytes[@offset, SaveStateReader::WRAM_SIZE]
            raise "WRAM slice out of bounds (offset=#{@offset}, data=#{@bytes.size} bytes)" unless slice
            slice.pack("C*")
          end
        end
      end
    end
  end
end
