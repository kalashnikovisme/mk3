require "json"
require "open3"

module FightingAI
  module Vision
    Detection = Data.define(:template_name, :x, :y, :width, :height, :center_x, :bottom_y, :confidence) do
      ACTION_NAME_SEPARATOR = "/"

      def action
        template_name.split(ACTION_NAME_SEPARATOR).first
      end
    end

    class CharacterPositionDetector
      DEFAULT_CHARACTER = :sub_zero
      DEFAULT_SCRIPT_PATH = File.expand_path("../../../bin/vision_detect.py", __dir__).freeze
      DEFAULT_TEMPLATE_ROOT = File.expand_path("../../../data/vision/templates", __dir__).freeze
      DEFAULT_ACTION_MODE = "all"
      IDLE_ACTION_MODE    = "idle"
      PLAYER_ONE = 1
      PLAYER_TWO = 2
      IMAGE_MAX_INDEX_ADJUSTMENT = 1
      MIN_AXIS_VALUE = 0
      DEFAULT_AXIS_MAX = 255
      FIRST_DETECTION_INDEX = 0
      SECOND_DETECTION_INDEX = 1
      JSON_LINE_SEPARATOR = "\n"
      PYTHON_BIN = "python3"
      SERVER_ARG = "--server"
      AREA_ARG = "--area"
      FULL_SCREEN_ARG = "--full-screen"
      ENV_PYTHONUNBUFFERED = "PYTHONUNBUFFERED"
      ENV_PYTHONWARNINGS = "PYTHONWARNINGS"
      ENV_TRUE_VALUE = "1"
      PYTHON_WARNING_FILTER = "ignore::DeprecationWarning"
      VISION_ACTION_ENV = "VISION_ACTION"
      VISION_AREAS_ENV = "VISION_AREAS"
      VISION_FULL_SCREEN_ENV = "VISION_FULL_SCREEN"
      SEARCH_STRIDE_ENV = "SEARCH_STRIDE"
      AREA_SEPARATOR = ";"
      READY_EVENT = "ready"

      attr_reader :character

      def initialize(
        character: DEFAULT_CHARACTER,
        template_root: DEFAULT_TEMPLATE_ROOT,
        script_path: DEFAULT_SCRIPT_PATH,
        action_mode: ENV.fetch(VISION_ACTION_ENV, DEFAULT_ACTION_MODE),
        areas: ENV.fetch(VISION_AREAS_ENV, nil),
        full_screen: ENV.fetch(VISION_FULL_SCREEN_ENV, nil) == ENV_TRUE_VALUE,
        detect_timer: true,
        search_stride: nil
      )
        @character = character.to_sym
        @template_dir = File.join(template_root, character.to_s)
        @script_path = script_path
        @action_mode = action_mode
        @areas = parse_areas(areas)
        @full_screen = full_screen
        @detect_timer = detect_timer
        @search_stride = search_stride
        @stdin = nil
        @stdout = nil
        @stderr = nil
        @wait_thread = nil
        @stderr_thread = nil
        at_exit { stop }
      end

      def available?
        File.exist?(@script_path) && Dir.glob(File.join(@template_dir, "**", "*_gray.png")).any?
      end

      def detect_path(path)
        ensure_started
        request = { path: path, detect_timer: @detect_timer }.to_json
        @stdin.write(request)
        @stdin.write(JSON_LINE_SEPARATOR)
        @stdin.flush
        parse_response
      end

      def detect_raw(frame_observation)
        ensure_started
        request = { width: frame_observation.width, height: frame_observation.height, detect_timer: @detect_timer }.to_json
        @stdin.write(request)
        @stdin.write(JSON_LINE_SEPARATOR)
        @stdin.write(frame_observation.raw_bytes)
        @stdin.flush
        parse_response
      end

      def detect(frame_observation)
        frame_observation.path ? detect_path(frame_observation.path) : detect_raw(frame_observation)
      end

      def start
        ensure_started
      end

      def stop
        @stdin&.close unless @stdin&.closed?
        @stdout&.close unless @stdout&.closed?
        @stderr&.close unless @stderr&.closed?
        @stderr_thread&.kill
        @wait_thread&.kill if @wait_thread&.alive?
        @stdin = nil
        @stdout = nil
        @stderr = nil
        @wait_thread = nil
        @stderr_thread = nil
      end

      def self.scale_position(detection, image_width:, image_height:, x_max: DEFAULT_AXIS_MAX, y_max: DEFAULT_AXIS_MAX)
        return nil unless detection

        {
          x: scale_axis(detection.center_x, image_width, x_max),
          y: scale_axis(detection.bottom_y, image_height, y_max),
          confidence: detection.confidence,
          template_name: detection.template_name
        }
      end

      def self.scale_axis(value, image_size, axis_max)
        denominator = [image_size - IMAGE_MAX_INDEX_ADJUSTMENT, IMAGE_MAX_INDEX_ADJUSTMENT].max
        scaled = (value.to_f * axis_max / denominator).round
        [[scaled, MIN_AXIS_VALUE].max, axis_max].min
      end

      private

      def ensure_started
        return if @stdin && @stdout && @wait_thread&.alive?

        stop
        env = { ENV_PYTHONUNBUFFERED => ENV_TRUE_VALUE, ENV_PYTHONWARNINGS => PYTHON_WARNING_FILTER }
        env[SEARCH_STRIDE_ENV] = @search_stride.to_s if @search_stride
        command = [PYTHON_BIN, @script_path, @action_mode, SERVER_ARG]
        command << FULL_SCREEN_ARG if @full_screen
        @areas.each do |area|
          command << AREA_ARG
          command << area
        end
        @stdin, @stdout, @stderr, @wait_thread = Open3.popen3(env, *command)
        @stderr_thread = Thread.new do
          Thread.current.report_on_exception = false
          begin
            @stderr.each_line { |line| warn(line) }
          rescue IOError
            nil
          end
        end

        ready_line = @stdout.gets
        raise "Vision detector did not become ready" unless ready_line

        ready = JSON.parse(ready_line)
        raise "Vision detector startup failed: #{ready.inspect}" unless ready.fetch("ok") && ready.fetch("event") == READY_EVENT
      end

      def parse_response
        response = @stdout.gets
        raise "Vision detector exited before responding" unless response

        payload = JSON.parse(response)
        raise "Vision detector error: #{payload.fetch("error")}" unless payload.fetch("ok")

        detections = payload.fetch("detections").map { |raw_detection| build_detection(raw_detection) }
        {
          character:    @character,
          detections:   detections,
          image_width:  payload.fetch("image_width"),
          image_height: payload.fetch("image_height"),
          player1:      detections.fetch(FIRST_DETECTION_INDEX, nil),
          player2:      detections.fetch(SECOND_DETECTION_INDEX, nil),
          timer:        payload["timer"]
        }
      end

      def parse_areas(raw_areas)
        return [] unless raw_areas && !raw_areas.empty?

        raw_areas.split(AREA_SEPARATOR)
      end

      def build_detection(raw_detection)
        Detection.new(
          template_name: raw_detection.fetch("template_name"),
          x: raw_detection.fetch("x"),
          y: raw_detection.fetch("y"),
          width: raw_detection.fetch("width"),
          height: raw_detection.fetch("height"),
          center_x: raw_detection.fetch("center_x"),
          bottom_y: raw_detection.fetch("bottom_y"),
          confidence: raw_detection.fetch("confidence")
        )
      end
    end
  end
end
