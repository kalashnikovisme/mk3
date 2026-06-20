require "zlib"
require_relative "provider"

module FightingAI
  module Observation
    class FrameObservation
      PNG_SIGNATURE         = "\x89PNG\r\n\x1a\n".b.freeze
      PNG_SIG_BYTES         = 8
      CHUNK_LENGTH_BYTES    = 4
      CHUNK_TYPE_BYTES      = 4
      CHUNK_CRC_BYTES       = 4
      CHUNK_HEADER_BYTES    = CHUNK_LENGTH_BYTES + CHUNK_TYPE_BYTES
      IHDR_WIDTH_OFFSET     = 0
      IHDR_HEIGHT_OFFSET    = 4
      RGB_CHANNELS          = 3
      FILTER_BYTE_SIZE      = 1
      FILTER_NONE           = 0
      FILTER_SUB            = 1
      FILTER_UP             = 2
      FILTER_AVERAGE        = 3
      FILTER_PAETH          = 4
      CHUNK_IHDR            = "IHDR"
      CHUNK_IDAT            = "IDAT"
      CHUNK_IEND            = "IEND"
      BYTE_MASK             = 0xFF

      attr_reader :path

      def initialize(path)
        @path   = path
        @parsed = false
      end

      def width
        parse unless @parsed
        @width
      end

      def height
        parse unless @parsed
        @height
      end

      def pixel_rgb(x, y)
        parse unless @parsed
        offset = x * RGB_CHANNELS
        scanline = @scanlines[y]
        [scanline.getbyte(offset), scanline.getbyte(offset + 1), scanline.getbyte(offset + 2)]
      end

      def to_tensor
        parse unless @parsed
        result = []
        @height.times do |y|
          scanline = @scanlines[y]
          @width.times do |x|
            base = x * RGB_CHANNELS
            result << scanline.getbyte(base)     / 255.0
            result << scanline.getbyte(base + 1) / 255.0
            result << scanline.getbyte(base + 2) / 255.0
          end
        end
        result
      end

      private

      def parse
        @parsed  = true
        raw_png  = File.binread(@path)
        raise "Not a PNG: #{@path}" unless raw_png.start_with?(PNG_SIGNATURE)

        idat_buf = "".b
        pos      = PNG_SIG_BYTES

        while pos < raw_png.bytesize
          length = raw_png.unpack1("@#{pos}N")
          type   = raw_png[pos + CHUNK_LENGTH_BYTES, CHUNK_TYPE_BYTES]
          pos   += CHUNK_HEADER_BYTES

          case type
          when CHUNK_IHDR
            @width  = raw_png.unpack1("@#{pos + IHDR_WIDTH_OFFSET}N")
            @height = raw_png.unpack1("@#{pos + IHDR_HEIGHT_OFFSET}N")
          when CHUNK_IDAT
            idat_buf << raw_png[pos, length]
          when CHUNK_IEND
            break
          end

          pos += length + CHUNK_CRC_BYTES
        end

        decompressed = Zlib::Inflate.inflate(idat_buf)
        stride       = @width * RGB_CHANNELS + FILTER_BYTE_SIZE
        @scanlines   = Array.new(@height)
        prev         = "\x00".b * (@width * RGB_CHANNELS)

        @height.times do |y|
          base   = y * stride
          filter = decompressed.getbyte(base)
          row    = decompressed[base + FILTER_BYTE_SIZE, @width * RGB_CHANNELS].b
          apply_filter!(filter, row, prev)
          @scanlines[y] = row
          prev = row
        end
      end

      def apply_filter!(filter, row, prev)
        case filter
        when FILTER_NONE then nil
        when FILTER_SUB
          (RGB_CHANNELS...row.bytesize).each do |i|
            row.setbyte(i, (row.getbyte(i) + row.getbyte(i - RGB_CHANNELS)) & BYTE_MASK)
          end
        when FILTER_UP
          row.bytesize.times do |i|
            row.setbyte(i, (row.getbyte(i) + prev.getbyte(i)) & BYTE_MASK)
          end
        when FILTER_AVERAGE
          row.bytesize.times do |i|
            a = i >= RGB_CHANNELS ? row.getbyte(i - RGB_CHANNELS) : 0
            row.setbyte(i, (row.getbyte(i) + ((a + prev.getbyte(i)) / 2)) & BYTE_MASK)
          end
        when FILTER_PAETH
          row.bytesize.times do |i|
            a  = i >= RGB_CHANNELS ? row.getbyte(i - RGB_CHANNELS) : 0
            b  = prev.getbyte(i)
            c  = i >= RGB_CHANNELS ? prev.getbyte(i - RGB_CHANNELS) : 0
            pa = (b - c).abs
            pb = (a - c).abs
            pc = (a + b - 2 * c).abs
            pr = pa <= pb && pa <= pc ? a : (pb <= pc ? b : c)
            row.setbyte(i, (row.getbyte(i) + pr) & BYTE_MASK)
          end
        end
      end
    end
  end
end
