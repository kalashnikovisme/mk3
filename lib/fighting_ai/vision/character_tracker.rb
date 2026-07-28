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
      PLAYER_ONE = 1
      PLAYER_TWO = 2
      DEFAULT_MAX_MOVEMENT_PER_FRAME = 15
      DEFAULT_MAX_LOST_FRAMES        = 5
      DEFAULT_FULL_SCREEN_INTERVAL   = 60
      DEFAULT_MIN_SEARCH_REGION_WIDTH  = 96
      DEFAULT_MIN_SEARCH_REGION_HEIGHT = 120
      MIN_COORDINATE                 = 0
      REGION_CENTER_DIVISOR          = 2
      FULL_SCREEN_MODE               = :full_screen
      REGIONAL_MODE                  = :regional
      Track = Struct.new(:player_index, :bounding_box, :previous_bounding_box, :frames_lost, :last_detection, keyword_init: true)

      def initialize(
        detector:,
        max_movement_per_frame: DEFAULT_MAX_MOVEMENT_PER_FRAME,
        max_lost_frames: DEFAULT_MAX_LOST_FRAMES,
        full_screen_interval: DEFAULT_FULL_SCREEN_INTERVAL,
        min_search_region_width: DEFAULT_MIN_SEARCH_REGION_WIDTH,
        min_search_region_height: DEFAULT_MIN_SEARCH_REGION_HEIGHT
      )
        @detector               = detector
        @max_movement_per_frame = max_movement_per_frame
        @max_lost_frames        = max_lost_frames
        @full_screen_interval   = full_screen_interval
        @min_search_region_width = min_search_region_width
        @min_search_region_height = min_search_region_height
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
        result.merge(player1: detection_for_player(PLAYER_ONE), player2: detection_for_player(PLAYER_TWO))
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
        active_tracks.sort_by(&:player_index).map { |t| padded_region(t.bounding_box) }
      end

      def padded_region(bbox)
        pad    = @max_movement_per_frame
        x      = [bbox[:x] - pad, MIN_COORDINATE].max
        y      = [bbox[:y] - pad, MIN_COORDINATE].max
        right  = bbox[:x] + bbox[:width] + pad
        bottom = bbox[:y] + bbox[:height] + pad
        x, right = expand_axis_range(x, right, @min_search_region_width, @last_image_width)
        y, bottom = expand_axis_range(y, bottom, @min_search_region_height, @last_image_height)
        right  = [right, @last_image_width].min  if @last_image_width
        bottom = [bottom, @last_image_height].min if @last_image_height
        { x: x, y: y, width: right - x, height: bottom - y }
      end

      def expand_axis_range(start_coord, end_coord, min_size, max_size)
        current_size = end_coord - start_coord
        return [start_coord, end_coord] if current_size >= min_size

        center = (start_coord + end_coord) / REGION_CENTER_DIVISOR
        start_coord = center - (min_size / REGION_CENTER_DIVISOR)
        end_coord = start_coord + min_size

        if max_size && end_coord > max_size
          end_coord = max_size
          start_coord = [end_coord - min_size, MIN_COORDINATE].max
        end
        if start_coord < MIN_COORDINATE
          start_coord = MIN_COORDINATE
          end_coord = [start_coord + min_size, max_size].compact.min
        end

        [start_coord, end_coord]
      end

      def update_tracks(detections, mode:)
        if mode == FULL_SCREEN_MODE
          reinitialize_tracks(detections)
        else
          update_existing_tracks(detections)
        end
      end

      def reinitialize_tracks(detections)
        if @tracks.empty?
          initialize_tracks_from_left_to_right(detections)
        else
          update_existing_tracks(detections)
        end
      end

      def update_existing_tracks(detections)
        remaining_detections = detections.dup

        @tracks.each do |track|
          area = padded_region(track.bounding_box)
          matched = best_detection_for_track(track, remaining_detections, area: area)
          if matched
            track.previous_bounding_box = track.bounding_box
            track.bounding_box = bbox_from(matched)
            track.frames_lost  = 0
            track.last_detection = matched
            remaining_detections.delete(matched)
          else
            track.frames_lost += 1
          end
        end
        @tracks.reject! { |t| t.frames_lost >= @max_lost_frames }
      end

      def initialize_tracks_from_left_to_right(detections)
        sorted = detections.sort_by(&:center_x)
        @tracks = sorted.first(PLAYER_TWO).each_with_index.map do |detection, index|
          Track.new(
            player_index: index + 1,
            bounding_box: bbox_from(detection),
            previous_bounding_box: nil,
            frames_lost: 0,
            last_detection: detection
          )
        end
      end

      def detection_for_player(player_index)
        track = active_tracks.find { |candidate| candidate.player_index == player_index }
        track&.last_detection
      end

      def best_detection_for_track(track, detections, area:)
        return nil if detections.empty?

        track_center_x, track_center_y = predicted_track_center(track)
        detections.min_by { |detection| detection_distance_squared(detection, track_center_x, track_center_y) }
      end

      def detection_distance_squared(detection, track_center_x, track_center_y)
        dx = detection.center_x - track_center_x
        detection_center_y = detection.bottom_y - (detection.height / REGION_CENTER_DIVISOR)
        dy = detection_center_y - track_center_y
        (dx * dx) + (dy * dy)
      end

      def bbox_center(bounding_box)
        center_x = bounding_box[:x] + (bounding_box[:width] / REGION_CENTER_DIVISOR)
        center_y = bounding_box[:y] + (bounding_box[:height] / REGION_CENTER_DIVISOR)
        [center_x, center_y]
      end

      def predicted_track_center(track)
        current_center_x, current_center_y = bbox_center(track.bounding_box)
        return [current_center_x, current_center_y] unless track.previous_bounding_box

        previous_center_x, previous_center_y = bbox_center(track.previous_bounding_box)
        [
          current_center_x + (current_center_x - previous_center_x),
          current_center_y + (current_center_y - previous_center_y)
        ]
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
