module MemoryAnalysis
  class Dump
    WRAM_SIZE = 131_072  # 128 KB — SNES WRAM bus 0x7E0000

    attr_reader :path

    def initialize(path)
      data = File.binread(path)
      unless data.bytesize == WRAM_SIZE
        raise "#{path}: expected #{WRAM_SIZE} bytes, got #{data.bytesize}"
      end
      @bytes = data.bytes.freeze
      @path  = path
    end

    def u8(addr)
      @bytes[addr]
    end

    def u16le(addr)
      @bytes[addr] | (@bytes[addr + 1] << 8)
    end

    def self.load(dir, *names)
      names.map { |name| new(File.join(dir, "#{name}.bin")) }
    end
  end
end
