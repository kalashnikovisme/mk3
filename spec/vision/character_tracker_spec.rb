require "spec_helper"

RSpec.describe FightingAI::Vision::CharacterTracker do
  TRACKER_IMAGE_WIDTH  = 297
  TRACKER_IMAGE_HEIGHT = 216
  P1_BBOX_X = 40
  P1_BBOX_Y = 100
  P1_BBOX_W = 50
  P1_BBOX_H = 80
  P2_BBOX_X = 180
  P2_BBOX_Y = 100
  P2_BBOX_W = 50
  P2_BBOX_H = 80
  TRACKER_PAD      = 10
  TRACKER_MAX_LOST = 3
  TRACKER_INTERVAL = 5
  TRACKER_MIN_REGION_WIDTH = 72
  TRACKER_MIN_REGION_HEIGHT = 120
  TRACKER_MIN_REGION_P1_X = 29
  TRACKER_MIN_REGION_P1_Y = 80
  PARTIAL_BBOX_W = 27
  PARTIAL_BBOX_H = 51

  let(:inner_detector) { instance_double(FightingAI::Vision::CharacterPositionDetector) }
  let(:frame)          { instance_double(FightingAI::Observation::FrameObservation) }

  def make_detection(x:, y:, width:, height:)
    FightingAI::Vision::Detection.new(
      template_name: "idle/01",
      x: x, y: y,
      width: width, height: height,
      center_x: x + width / 2,
      bottom_y: y + height,
      confidence: 0.90
    )
  end

  def make_result(*detections)
    {
      character:    :sub_zero,
      detections:   detections,
      candidates:   [],
      areas:        [],
      image_width:  TRACKER_IMAGE_WIDTH,
      image_height: TRACKER_IMAGE_HEIGHT,
      player1:      detections[0],
      player2:      detections[1],
      timer:        nil,
      detect_ms:    nil
    }
  end

  subject(:tracker) do
    described_class.new(
      detector:               inner_detector,
      max_movement_per_frame: TRACKER_PAD,
      max_lost_frames:        TRACKER_MAX_LOST,
      full_screen_interval:   TRACKER_INTERVAL,
      min_search_region_width: TRACKER_MIN_REGION_WIDTH,
      min_search_region_height: TRACKER_MIN_REGION_HEIGHT
    )
  end

  describe "#detect" do
    context "on first frame with no tracks" do
      it "passes empty areas so the inner detector runs full-screen" do
        p1 = make_detection(x: P1_BBOX_X, y: P1_BBOX_Y, width: P1_BBOX_W, height: P1_BBOX_H)
        expect(inner_detector).to receive(:detect).with(frame, areas: []).and_return(make_result(p1))

        tracker.detect(frame)
      end

      it "initialises one track per detected character" do
        p1 = make_detection(x: P1_BBOX_X, y: P1_BBOX_Y, width: P1_BBOX_W, height: P1_BBOX_H)
        p2 = make_detection(x: P2_BBOX_X, y: P2_BBOX_Y, width: P2_BBOX_W, height: P2_BBOX_H)
        allow(inner_detector).to receive(:detect).with(frame, areas: []).and_return(make_result(p1, p2))

        tracker.detect(frame)

        tracks = tracker.instance_variable_get(:@tracks)
        expect(tracks.size).to eq(2)
        expect(tracks[0].bounding_box).to eq({ x: P1_BBOX_X, y: P1_BBOX_Y, width: P1_BBOX_W, height: P1_BBOX_H })
      end

      it "returns false from #tracking? before any detection" do
        expect(tracker.tracking?).to be false
      end
    end

    context "after tracks are established" do
      before do
        p1 = make_detection(x: P1_BBOX_X, y: P1_BBOX_Y, width: P1_BBOX_W, height: P1_BBOX_H)
        p2 = make_detection(x: P2_BBOX_X, y: P2_BBOX_Y, width: P2_BBOX_W, height: P2_BBOX_H)
        allow(inner_detector).to receive(:detect).with(frame, areas: []).and_return(make_result(p1, p2))
        tracker.detect(frame)  # frame 1 — full-screen, initialises tracks
      end

      it "returns true from #tracking?" do
        expect(tracker.tracking?).to be true
      end

      it "passes one padded area per track on the next frame" do
        captured_areas = nil
        allow(inner_detector).to receive(:detect) do |_, areas:|
          captured_areas = areas
          make_result
        end

        tracker.detect(frame)

        expect(captured_areas.size).to eq(2)
        expect(captured_areas).to all(be_a(Hash))
        expect(captured_areas[0].keys).to match_array(%i[x y width height])
      end

      it "pads each search area by max_movement_per_frame and expands to the minimum region" do
        expected_p1 = {
          x:      TRACKER_MIN_REGION_P1_X,
          y:      TRACKER_MIN_REGION_P1_Y,
          width:  TRACKER_MIN_REGION_WIDTH,
          height: TRACKER_MIN_REGION_HEIGHT
        }
        captured_areas = nil
        allow(inner_detector).to receive(:detect) do |_, areas:|
          captured_areas = areas
          make_result
        end

        tracker.detect(frame)

        expect(captured_areas[0]).to eq(expected_p1)
      end

      it "keeps a small partial detection inside a full-body search region" do
        partial = make_detection(x: P1_BBOX_X, y: P1_BBOX_Y, width: PARTIAL_BBOX_W, height: PARTIAL_BBOX_H)
        allow(inner_detector).to receive(:detect).and_return(make_result(partial))
        tracker.detect(frame)

        captured_areas = nil
        allow(inner_detector).to receive(:detect) do |_, areas:|
          captured_areas = areas
          make_result
        end
        tracker.detect(frame)

        expect(captured_areas.first[:width]).to be >= TRACKER_MIN_REGION_WIDTH
        expect(captured_areas.first[:height]).to be >= TRACKER_MIN_REGION_HEIGHT
      end

      it "updates the track bounding box when a detection lands in the search area" do
        moved_p1 = make_detection(x: P1_BBOX_X + 3, y: P1_BBOX_Y + 2, width: P1_BBOX_W, height: P1_BBOX_H)
        allow(inner_detector).to receive(:detect).and_return(make_result(moved_p1))

        tracker.detect(frame)

        track = tracker.instance_variable_get(:@tracks).first
        expect(track.bounding_box[:x]).to eq(P1_BBOX_X + 3)
        expect(track.bounding_box[:y]).to eq(P1_BBOX_Y + 2)
        expect(track.frames_lost).to eq(0)
      end

      it "increments frames_lost when no detection lands in the search area" do
        allow(inner_detector).to receive(:detect).and_return(make_result)

        tracker.detect(frame)

        track = tracker.instance_variable_get(:@tracks).first
        expect(track.frames_lost).to eq(1)
      end
    end

    context "when a character is lost for max_lost_frames consecutive frames" do
      before do
        p1 = make_detection(x: P1_BBOX_X, y: P1_BBOX_Y, width: P1_BBOX_W, height: P1_BBOX_H)
        allow(inner_detector).to receive(:detect).with(frame, areas: []).and_return(make_result(p1))
        tracker.detect(frame)  # frame 1 — track initialised
        allow(inner_detector).to receive(:detect).and_return(make_result)
      end

      it "removes the track after max_lost_frames misses" do
        TRACKER_MAX_LOST.times { tracker.detect(frame) }

        expect(tracker.instance_variable_get(:@tracks)).to be_empty
      end

      it "falls back to full-screen detection once all tracks are lost" do
        TRACKER_MAX_LOST.times { tracker.detect(frame) }

        expect(inner_detector).to receive(:detect).with(frame, areas: []).and_return(make_result)
        tracker.detect(frame)
      end

      it "returns false from #tracking? once all tracks are lost" do
        TRACKER_MAX_LOST.times { tracker.detect(frame) }

        expect(tracker.tracking?).to be false
      end
    end

    context "periodic full-screen recovery every full_screen_interval frames" do
      before do
        p1 = make_detection(x: P1_BBOX_X, y: P1_BBOX_Y, width: P1_BBOX_W, height: P1_BBOX_H)
        allow(inner_detector).to receive(:detect).and_return(make_result(p1))
        tracker.detect(frame)  # frame 1 — full-screen, track initialised
      end

      it "forces a full-screen scan at every multiple of full_screen_interval" do
        allow(inner_detector).to receive(:detect).and_return(make_result)

        (TRACKER_INTERVAL - 2).times { tracker.detect(frame) }

        expect(inner_detector).to receive(:detect).with(frame, areas: []).and_return(make_result)
        tracker.detect(frame)  # frame TRACKER_INTERVAL: 5 % 5 == 0
      end

      it "uses regional areas on frames between periodic full-screen scans" do
        captured_modes = []
        allow(inner_detector).to receive(:detect) do |_, areas:|
          captured_modes << (areas.empty? ? :full_screen : :regional)
          make_result
        end

        4.times { tracker.detect(frame) }  # frames 2, 3, 4 regional; frame 5 full-screen

        expect(captured_modes).to eq(%i[regional regional regional full_screen])
      end
    end

    context "with multiple characters tracked simultaneously" do
      it "maintains an independent track for each character" do
        p1 = make_detection(x: P1_BBOX_X, y: P1_BBOX_Y, width: P1_BBOX_W, height: P1_BBOX_H)
        p2 = make_detection(x: P2_BBOX_X, y: P2_BBOX_Y, width: P2_BBOX_W, height: P2_BBOX_H)
        allow(inner_detector).to receive(:detect).with(frame, areas: []).and_return(make_result(p1, p2))
        tracker.detect(frame)

        moved_p2 = make_detection(x: P2_BBOX_X + 5, y: P2_BBOX_Y, width: P2_BBOX_W, height: P2_BBOX_H)
        allow(inner_detector).to receive(:detect).and_return(make_result(p1, moved_p2))
        tracker.detect(frame)

        tracks = tracker.instance_variable_get(:@tracks)
        expect(tracks[0].bounding_box[:x]).to eq(P1_BBOX_X)
        expect(tracks[1].bounding_box[:x]).to eq(P2_BBOX_X + 5)
      end
    end

    context "search area clamping" do
      it "does not produce a negative x or y" do
        corner = make_detection(x: 0, y: 0, width: P1_BBOX_W, height: P1_BBOX_H)
        allow(inner_detector).to receive(:detect).with(frame, areas: []).and_return(make_result(corner))
        tracker.detect(frame)

        captured_areas = nil
        allow(inner_detector).to receive(:detect) do |_, areas:|
          captured_areas = areas
          make_result
        end
        tracker.detect(frame)

        expect(captured_areas[0][:x]).to eq(0)
        expect(captured_areas[0][:y]).to eq(0)
      end

      it "clamps the right and bottom edges to the last known image dimensions" do
        far = make_detection(
          x: TRACKER_IMAGE_WIDTH - P1_BBOX_W, y: TRACKER_IMAGE_HEIGHT - P1_BBOX_H,
          width: P1_BBOX_W, height: P1_BBOX_H
        )
        allow(inner_detector).to receive(:detect).with(frame, areas: []).and_return(make_result(far))
        tracker.detect(frame)

        captured_areas = nil
        allow(inner_detector).to receive(:detect) do |_, areas:|
          captured_areas = areas
          make_result
        end
        tracker.detect(frame)

        expect(captured_areas[0][:x] + captured_areas[0][:width]).to  be <= TRACKER_IMAGE_WIDTH
        expect(captured_areas[0][:y] + captured_areas[0][:height]).to be <= TRACKER_IMAGE_HEIGHT
      end
    end
  end
end
