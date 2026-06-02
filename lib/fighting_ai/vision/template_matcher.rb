require_relative "png_image"

module FightingAI
  module Vision
    Detection = Data.define(:template_name, :x, :y, :width, :height, :center_x, :bottom_y, :confidence)
    Template = Data.define(:name, :width, :height, :grayscale_pixels, :mask_pixels, :opaque_pixel_count)

    class TemplateMatcher
      DEFAULT_MIN_CONFIDENCE = 0.82
      DEFAULT_MAX_DETECTIONS = 2
      DEFAULT_SEARCH_STRIDE = 1
      MIN_MASK_VALUE = 1
      CONFIDENCE_MAX = 1.0
      BYTE_MAX_FLOAT = 255.0
      EMPTY_PIXEL_COUNT = 0
      FIRST_DETECTION_INDEX = 0
      SECOND_DETECTION_INDEX = 1
      CENTER_DIVISOR = 2
      NO_OVERLAP = 0.0
      IOU_REJECTION_THRESHOLD = 0.25

      GRAY_SUFFIX = "_gray.png"
      MASK_SUFFIX = "_mask.png"

      attr_reader :templates

      def initialize(template_dir:, min_confidence: DEFAULT_MIN_CONFIDENCE, max_detections: DEFAULT_MAX_DETECTIONS, search_stride: DEFAULT_SEARCH_STRIDE)
        @template_dir = template_dir
        @min_confidence = min_confidence
        @max_detections = max_detections
        @search_stride = search_stride
        @templates = load_templates
      end

      def detect(frame_observation)
        detections, = detect_with_size(frame_observation)
        detections
      end

      def detect_with_size(frame_observation)
        image = PngImage.load(frame_observation.path)
        candidates = @templates.flat_map { |template| matches_for_template(image, template) }
        detections = select_non_overlapping(candidates.sort_by { |detection| -detection.confidence }).sort_by(&:center_x)
        [detections, image.width, image.height]
      end

      private

      def load_templates
        Dir.glob(File.join(@template_dir, "*#{GRAY_SUFFIX}")).sort.map do |gray_path|
          name = File.basename(gray_path, GRAY_SUFFIX)
          mask_path = File.join(@template_dir, "#{name}#{MASK_SUFFIX}")
          next unless File.exist?(mask_path)

          gray_image = PngImage.load(gray_path)
          mask_image = PngImage.load(mask_path)
          raise ArgumentError, "Mask dimensions do not match template: #{name}" unless dimensions_match?(gray_image, mask_image)

          mask_pixels = mask_image.grayscale_pixels.map { |value| value >= MIN_MASK_VALUE }
          opaque_count = mask_pixels.count(true)
          next if opaque_count == EMPTY_PIXEL_COUNT

          Template.new(
            name: name,
            width: gray_image.width,
            height: gray_image.height,
            grayscale_pixels: gray_image.grayscale_pixels,
            mask_pixels: mask_pixels,
            opaque_pixel_count: opaque_count
          )
        end.compact
      end

      def dimensions_match?(left, right)
        left.width == right.width && left.height == right.height
      end

      def matches_for_template(image, template)
        return [] if template.width > image.width || template.height > image.height

        matches = []
        max_x = image.width - template.width
        max_y = image.height - template.height

        stepped_range(max_y).each do |y|
          stepped_range(max_x).each do |x|
            score = confidence_at(image, template, x, y)
            next if score < @min_confidence

            matches << Detection.new(
              template_name: template.name,
              x: x,
              y: y,
              width: template.width,
              height: template.height,
              center_x: x + template.width / CENTER_DIVISOR,
              bottom_y: y + template.height,
              confidence: score
            )
          end
        end

        matches
      end

      def stepped_range(max_value)
        (PngImage::BYTE_MIN..max_value).step(@search_stride)
      end

      def confidence_at(image, template, origin_x, origin_y)
        error_sum = PngImage::BYTE_MIN

        template.height.times do |template_y|
          template.width.times do |template_x|
            template_index = template_y * template.width + template_x
            next unless template.mask_pixels.fetch(template_index)

            image_gray = image.gray_at(origin_x + template_x, origin_y + template_y)
            template_gray = template.grayscale_pixels.fetch(template_index)
            error_sum += (image_gray - template_gray).abs
          end
        end

        CONFIDENCE_MAX - (error_sum / (template.opaque_pixel_count * BYTE_MAX_FLOAT))
      end

      def select_non_overlapping(candidates)
        selected = []
        candidates.each do |candidate|
          next if selected.any? { |existing| overlap_ratio(existing, candidate) >= IOU_REJECTION_THRESHOLD }

          selected << candidate
          break if selected.size >= @max_detections
        end
        selected
      end

      def overlap_ratio(left, right)
        left_x2 = left.x + left.width
        left_y2 = left.y + left.height
        right_x2 = right.x + right.width
        right_y2 = right.y + right.height

        overlap_width = [left_x2, right_x2].min - [left.x, right.x].max
        overlap_height = [left_y2, right_y2].min - [left.y, right.y].max
        return NO_OVERLAP if overlap_width <= PngImage::BYTE_MIN || overlap_height <= PngImage::BYTE_MIN

        overlap_area = overlap_width * overlap_height
        left_area = left.width * left.height
        right_area = right.width * right.height
        overlap_area.to_f / [left_area, right_area].min
      end
    end
  end
end
