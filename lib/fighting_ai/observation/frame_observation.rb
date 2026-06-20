require "chunky_png"
require_relative "provider"

module FightingAI
  module Observation
    class FrameObservation
      attr_reader :path

      def initialize(path)
        @path = path
      end

      def pixels
        @pixels ||= load && @pixels
      end

      def width
        @width ||= load && @width
      end

      def height
        @height ||= load && @height
      end

      def to_tensor
        pixels.map { |r, g, b| [r / 255.0, g / 255.0, b / 255.0] }.flatten
      end

      private

      def load
        return if @pixels

        image   = ChunkyPNG::Image.from_file(@path)
        @width  = image.width
        @height = image.height
        @pixels = Array.new(@height * @width)

        @height.times do |y|
          @width.times do |x|
            p = image[x, y]
            @pixels[y * @width + x] = [
              ChunkyPNG::Color.r(p),
              ChunkyPNG::Color.g(p),
              ChunkyPNG::Color.b(p)
            ]
          end
        end

        true
      end
    end
  end
end
