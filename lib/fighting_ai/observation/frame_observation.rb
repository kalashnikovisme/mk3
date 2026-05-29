require_relative "provider"

module FightingAI
  module Observation
    class FrameObservation
      attr_reader :path

      def initialize(path)
        @path = path
      end

      def pixels
        @pixels ||= load_pixels
      end

      def width
        @width ||= (load_dimensions; @width)
      end

      def height
        @height ||= (load_dimensions; @height)
      end

      def to_tensor
        pixels.map { |r, g, b| [r / 255.0, g / 255.0, b / 255.0] }.flatten
      end

      private

      def load_pixels
        load_dimensions
        @pixels
      end

      def load_dimensions
        return if @pixels

        raw = File.binread(@path)

        # PNG IHDR: bytes 16-23 are width (4 bytes BE) and height (4 bytes BE)
        @width  = raw[16, 4].unpack1("N")
        @height = raw[20, 4].unpack1("N")

        # Decompress IDAT chunks for pixel data (requires zlib)
        require "zlib"
        idat_data = "".b
        pos = 8
        while pos < raw.bytesize - 4
          chunk_len  = raw[pos, 4].unpack1("N")
          chunk_type = raw[pos + 4, 4]
          chunk_data = raw[pos + 8, chunk_len]
          idat_data << chunk_data if chunk_type == "IDAT"
          pos += 12 + chunk_len
        end

        scanline_width = @width * 3 + 1
        raw_pixels     = Zlib::Inflate.inflate(idat_data)
        @pixels = []

        @height.times do |row|
          base = row * scanline_width + 1  # skip filter byte
          @width.times do |col|
            offset = base + col * 3
            @pixels << raw_pixels[offset, 3].bytes
          end
        end
      end
    end
  end
end
