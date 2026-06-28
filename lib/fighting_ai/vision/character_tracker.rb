module FightingAI
  module Vision
    # Optimization layer that wraps CharacterPositionDetector to avoid scanning
    # the full screen on every frame.
    #
    # On startup (or when all tracks are lost) the tracker runs full-screen
    # detection to locate characters wherever they are on the screen.  Once
    # characters are found it switches to scanning only padded regions around
    # each character's last known bounding box, which is much faster.  Every
    # FULL_SCREEN_INTERVAL frames the tracker forces a full-screen recovery scan
    # in case the characters drifted outside their tracked regions.
    #
    # The public #detect interface matches CharacterPositionDetector so the
    # tracker can be passed directly to AsyncVisionScanner.
    class CharacterTracker
      DEFAULT_MAX_MOVEMENT_PER_FRAME = 15
      DEFAULT_MAX_LOST_FRAMES        = 5
      DEFAULT_FULL_SCREEN_INTERVAL   = 60
      MIN_COORDINATE                 = 0
      FULL_SCREEN_MODE               = :full_screen
      REGIONAL_MODE                  = :regional
Track = Struct.new(:bounding_box, :frames_lost, keyword_init: true)

      def initialize(
        detector:,
        max_movement_per_frame: DEFAULT_MAX_MOVEMENT_PER_FRAME,
        max_lost_frames: DEFAULT_MAX_LOST_FRAMES,
        full_screen_interval: DEFAULT_FULL_SCREEN_INTERVAL
      )
        @detector               = detector
        @max_movement_per_frame = max_movement_per_frame
        @max_lost_frames        = max_lost_frames
        @full_screen_interval   = full_screen_interval
        @tracks                 = []
        @frame_count            = 0
        @last_image_width       = nil
        @last_image_height      = nil
      end

      def detect(frame_observation)
        @frame_count += 1
        mode  = scan_mode
        areas = mode == REGIONAL_MODE ? build_search_areas : []

        result = @detector.detect(frame_observation, areas: areas)
        @last_image_width  = result[:image_width]
        @last_image_height = result[:image_height]
        update_tracks(result[:detections], mode: mode)
        result
      end

      def tracking?
        active_tracks.any?
      end

      def available?
        @detector.available?
      end

      def start
        @detector.start
      end

      def stop
        @detector.stop
      end

      def search_areas
        @detector.search_areas
      end

      private

      def active_tracks
        @tracks.select { |t| t.frames_lost < @max_lost_frames }
      end

      def scan_mode
        return FULL_SCREEN_MODE unless tracking?
        return FULL_SCREEN_MODE if periodic_full_screen_frame?

        REGIONAL_MODE
      end

      def periodic_full_screen_frame?
        @full_screen_interval > 0 && (@frame_count % @full_screen_interval).zero?
      end

      def build_search_areas
        active_tracks.map { |t| padded_region(t.bounding_box) }
      end

      def padded_region(bbox)
        pad    = @max_movement_per_frame
        x      = [bbox[:x] - pad, MIN_COORDINATE].max
        y      = [bbox[:y] - pad, MIN_COORDINATE].max
        right  = bbox[:x] + bbox[:width] + pad
        bottom = bbox[:y] + bbox[:height] + pad
        right  = [right, @last_image_width].min  if @last_image_width
        bottom = [bottom, @last_image_height].min if @last_image_height
        { x: x, y: y, width: right - x, height: bottom - y }
      end

      def update_tracks(detections, mode:)
        if mode == FULL_SCREEN_MODE
          reinitialize_tracks(detections)
        else
          update_existing_tracks(detections)
        end
      end

      def reinitialize_tracks(detections)
        @tracks = detections.map { |det| Track.new(bounding_box: bbox_from(det), frames_lost: 0) }
      end

      def update_existing_tracks(detections)
        @tracks.each do |track|
          area    = padded_region(track.bounding_box)
          matched = detections.find { |det| detection_center_in_area?(det, area) }
          if matched
            track.bounding_box = bbox_from(matched)
            track.frames_lost  = 0
          else
            track.frames_lost += 1
          end
        end
        @tracks.reject! { |t| t.frames_lost >= @max_lost_frames }
      end

      def detection_center_in_area?(detection, area)
        cx = detection.center_x
        cy = detection.bottom_y - (detection.height / 2)
        cx.between?(area[:x], area[:x] + area[:width]) &&
          cy.between?(area[:y], area[:y] + area[:height])
      end

      def bbox_from(detection)
        { x: detection.x, y: detection.y, width: detection.width, height: detection.height }
      end
    end
  end
end
