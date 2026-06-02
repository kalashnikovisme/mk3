require "zlib"

module FightingAI
  module Vision
    class PngImage
      PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b.freeze
      SIGNATURE_BYTES = 8
      CHUNK_LENGTH_BYTES = 4
      CHUNK_TYPE_BYTES = 4
      CHUNK_CRC_BYTES = 4
      CHUNK_HEADER_BYTES = CHUNK_LENGTH_BYTES + CHUNK_TYPE_BYTES
      CHUNK_TOTAL_OVERHEAD = CHUNK_HEADER_BYTES + CHUNK_CRC_BYTES
      IHDR_DATA_BYTES = 13
      IHDR_WIDTH_OFFSET = 0
      IHDR_HEIGHT_OFFSET = 4
      IHDR_BIT_DEPTH_OFFSET = 8
      IHDR_COLOR_TYPE_OFFSET = 9
      EIGHT_BIT_DEPTH = 8
      NO_INTERLACE = 0
      IHDR_INTERLACE_OFFSET = 12

      COLOR_GRAYSCALE = 0
      COLOR_RGB = 2
      COLOR_GRAYSCALE_ALPHA = 4
      COLOR_RGBA = 6

      GRAYSCALE_BYTES_PER_PIXEL = 1
      RGB_BYTES_PER_PIXEL = 3
      GRAYSCALE_ALPHA_BYTES_PER_PIXEL = 2
      RGBA_BYTES_PER_PIXEL = 4

      FILTER_NONE = 0
      FILTER_SUB = 1
      FILTER_UP = 2
      FILTER_AVERAGE = 3
      FILTER_PAETH = 4

      BYTE_MIN = 0
      BYTE_MAX = 255
      BYTE_RANGE = 256
      NO_ALPHA = BYTE_MAX
      HALF_DIVISOR = 2

      RED_LUMA_WEIGHT = 299
      GREEN_LUMA_WEIGHT = 587
      BLUE_LUMA_WEIGHT = 114
      LUMA_DIVISOR = 1000

      attr_reader :width, :height, :grayscale_pixels, :alpha_pixels

      def self.load(path)
        new(File.binread(path))
      end

      def initialize(raw)
        @raw = raw.b
        @idat_data = +""
        parse_chunks
        decode_pixels
      end

      def gray_at(x, y)
        @grayscale_pixels[pixel_index(x, y)]
      end

      def alpha_at(x, y)
        @alpha_pixels[pixel_index(x, y)]
      end

      private

      def parse_chunks
        raise ArgumentError, "Invalid PNG signature" unless @raw.byteslice(BYTE_MIN, SIGNATURE_BYTES) == PNG_SIGNATURE

        position = SIGNATURE_BYTES
        while position < @raw.bytesize
          chunk_length = @raw.byteslice(position, CHUNK_LENGTH_BYTES).unpack1("N")
          chunk_type = @raw.byteslice(position + CHUNK_LENGTH_BYTES, CHUNK_TYPE_BYTES)
          chunk_data = @raw.byteslice(position + CHUNK_HEADER_BYTES, chunk_length)

          case chunk_type
          when "IHDR"
            parse_ihdr(chunk_data)
          when "IDAT"
            @idat_data << chunk_data
          when "IEND"
            break
          end

          position += chunk_length + CHUNK_TOTAL_OVERHEAD
        end
      end

      def parse_ihdr(chunk_data)
        raise ArgumentError, "Invalid IHDR length" unless chunk_data.bytesize == IHDR_DATA_BYTES

        @width = chunk_data.byteslice(IHDR_WIDTH_OFFSET, CHUNK_LENGTH_BYTES).unpack1("N")
        @height = chunk_data.byteslice(IHDR_HEIGHT_OFFSET, CHUNK_LENGTH_BYTES).unpack1("N")
        @bit_depth = chunk_data.getbyte(IHDR_BIT_DEPTH_OFFSET)
        @color_type = chunk_data.getbyte(IHDR_COLOR_TYPE_OFFSET)
        @interlace = chunk_data.getbyte(IHDR_INTERLACE_OFFSET)

        raise ArgumentError, "Only 8-bit PNGs are supported" unless @bit_depth == EIGHT_BIT_DEPTH
        raise ArgumentError, "Interlaced PNGs are not supported" unless @interlace == NO_INTERLACE
      end

      def decode_pixels
        raw_pixels = Zlib::Inflate.inflate(@idat_data).bytes
        bytes_per_pixel = bytes_per_pixel_for(@color_type)
        row_bytes = @width * bytes_per_pixel
        previous_row = Array.new(row_bytes, BYTE_MIN)
        rows = []
        offset = BYTE_MIN

        @height.times do
          filter_type = raw_pixels.fetch(offset)
          offset += GRAYSCALE_BYTES_PER_PIXEL
          filtered_row = raw_pixels.slice(offset, row_bytes)
          offset += row_bytes

          row = unfilter_row(filter_type, filtered_row, previous_row, bytes_per_pixel)
          rows << row
          previous_row = row
        end

        flatten_rows(rows, bytes_per_pixel)
      end

      def bytes_per_pixel_for(color_type)
        case color_type
        when COLOR_GRAYSCALE then GRAYSCALE_BYTES_PER_PIXEL
        when COLOR_RGB then RGB_BYTES_PER_PIXEL
        when COLOR_GRAYSCALE_ALPHA then GRAYSCALE_ALPHA_BYTES_PER_PIXEL
        when COLOR_RGBA then RGBA_BYTES_PER_PIXEL
        else
          raise ArgumentError, "Unsupported PNG color type: #{color_type}"
        end
      end

      def unfilter_row(filter_type, filtered_row, previous_row, bytes_per_pixel)
        row = []
        filtered_row.each_index do |index|
          left = index >= bytes_per_pixel ? row[index - bytes_per_pixel] : BYTE_MIN
          up = previous_row[index]
          up_left = index >= bytes_per_pixel ? previous_row[index - bytes_per_pixel] : BYTE_MIN

          predictor = case filter_type
          when FILTER_NONE then BYTE_MIN
          when FILTER_SUB then left
          when FILTER_UP then up
          when FILTER_AVERAGE then (left + up) / HALF_DIVISOR
          when FILTER_PAETH then paeth(left, up, up_left)
          else
            raise ArgumentError, "Unsupported PNG filter type: #{filter_type}"
          end

          row << ((filtered_row[index] + predictor) % BYTE_RANGE)
        end
        row
      end

      def paeth(left, up, up_left)
        estimate = left + up - up_left
        left_distance = (estimate - left).abs
        up_distance = (estimate - up).abs
        up_left_distance = (estimate - up_left).abs

        return left if left_distance <= up_distance && left_distance <= up_left_distance
        return up if up_distance <= up_left_distance

        up_left
      end

      def flatten_rows(rows, bytes_per_pixel)
        @grayscale_pixels = []
        @alpha_pixels = []

        rows.each do |row|
          row.each_slice(bytes_per_pixel) do |pixel|
            gray, alpha = gray_alpha_for(pixel)
            @grayscale_pixels << gray
            @alpha_pixels << alpha
          end
        end
      end

      def gray_alpha_for(pixel)
        case @color_type
        when COLOR_GRAYSCALE
          [pixel.fetch(BYTE_MIN), NO_ALPHA]
        when COLOR_RGB
          [luminance(pixel.fetch(BYTE_MIN), pixel.fetch(GRAYSCALE_BYTES_PER_PIXEL), pixel.fetch(GRAYSCALE_ALPHA_BYTES_PER_PIXEL)), NO_ALPHA]
        when COLOR_GRAYSCALE_ALPHA
          [pixel.fetch(BYTE_MIN), pixel.fetch(GRAYSCALE_BYTES_PER_PIXEL)]
        when COLOR_RGBA
          [
            luminance(pixel.fetch(BYTE_MIN), pixel.fetch(GRAYSCALE_BYTES_PER_PIXEL), pixel.fetch(GRAYSCALE_ALPHA_BYTES_PER_PIXEL)),
            pixel.fetch(RGB_BYTES_PER_PIXEL)
          ]
        end
      end

      def luminance(red, green, blue)
        ((red * RED_LUMA_WEIGHT) + (green * GREEN_LUMA_WEIGHT) + (blue * BLUE_LUMA_WEIGHT)) / LUMA_DIVISOR
      end

      def pixel_index(x, y)
        y * @width + x
      end
    end
  end
end
