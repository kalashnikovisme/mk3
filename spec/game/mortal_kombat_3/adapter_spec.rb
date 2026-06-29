# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FightingAI::Game::MortalKombat3::Adapter do
  let(:emulator_adapter) { instance_double(FightingAI::Emulator::Adapter) }
  let(:game_definition) { double('GameDefinition') }
  let(:vision_detector) do
    instance_double(
      FightingAI::Vision::CharacterPositionDetector,
      available?: true
    )
  end
  let(:scanner) { instance_double(FightingAI::Vision::AsyncVisionScanner, submit: nil) }
  let(:health_detector) { instance_double(FightingAI::Vision::HealthBarDetector, detect: nil) }
  let(:frame_observation) { instance_double(FightingAI::Observation::FrameObservation) }
  let(:frame_number_one) { 1 }
  let(:frame_number_two) { 2 }
  let(:frame_number_three) { 3 }
  let(:timer_ninety_nine) { 99 }
  let(:vision_image_width) { 297 }
  let(:vision_image_height) { 216 }
  let(:player_one_detection) do
    FightingAI::Vision::Detection.new(
      template_name: 'idle_fighting_stance/01_left',
      x: 35,
      y: 150,
      width: 20,
      height: 50,
      center_x: 46,
      bottom_y: 170,
      confidence: 0.95
    )
  end
  let(:player_two_detection) do
    FightingAI::Vision::Detection.new(
      template_name: 'ice_clone_crouch/01_right',
      x: 180,
      y: 140,
      width: 24,
      height: 60,
      center_x: 192,
      bottom_y: 199,
      confidence: 0.94
    )
  end
  let(:bootstrap_result) do
    {
      detections: [player_one_detection, player_two_detection],
      areas: [],
      image_width: vision_image_width,
      image_height: vision_image_height,
      timer: timer_ninety_nine
    }
  end

  subject(:adapter) do
    described_class.new(
      emulator_adapter: emulator_adapter,
      game_definition: game_definition,
      vision_detector: vision_detector
    )
  end

  before do
    allow(FightingAI::Vision::AsyncVisionScanner).to receive(:new).with(vision_detector).and_return(scanner)
    adapter.instance_variable_set(:@health_detector, health_detector)
  end

  describe '#extract_game_state' do
    it 'bootstraps timer detection synchronously on the first frame' do
      allow(vision_detector).to receive(:detect).with(frame_observation).and_return(bootstrap_result)

      state = adapter.extract_game_state(frame_number_one, frame_observation: frame_observation)

      expect(state.round_time_remaining).to eq(timer_ninety_nine)
      expect(state.fighter1.x).not_to eq(0)
      expect(state.fighter2.x).not_to eq(0)
      expect(vision_detector).to have_received(:detect).with(frame_observation)
      expect(scanner).not_to have_received(:submit)
    end

    it 'reuses the last detected timer when an async scan omits the timer' do
      async_result_without_timer = {
        detections: [],
        areas: [],
        image_width: vision_image_width,
        image_height: vision_image_height,
        timer: nil
      }
      allow(vision_detector).to receive(:detect).with(frame_observation).and_return(bootstrap_result)
      allow(scanner).to receive(:latest_result).and_return(async_result_without_timer)

      adapter.extract_game_state(frame_number_one, frame_observation: frame_observation)
      state = adapter.extract_game_state(frame_number_two, frame_observation: frame_observation)

      expect(state.round_time_remaining).to eq(timer_ninety_nine)
      expect(scanner).to have_received(:submit).with(frame_observation)
    end

    it 'keeps action labels aligned with the assigned player detections' do
      allow(vision_detector).to receive(:detect).with(frame_observation).and_return(bootstrap_result)
      allow(scanner).to receive(:latest_result).and_return(nil)

      adapter.extract_game_state(frame_number_one, frame_observation: frame_observation)

      expect(adapter.latest_vision_actions).to eq(
        1 => 'idle_fighting_stance',
        2 => 'ice_clone_crouch'
      )
    end

    it 'reuses the last detected positions when an async scan result is not ready yet' do
      allow(vision_detector).to receive(:detect).with(frame_observation).and_return(bootstrap_result)
      allow(scanner).to receive(:latest_result).and_return(nil)

      first_state = adapter.extract_game_state(frame_number_one, frame_observation: frame_observation)
      second_state = adapter.extract_game_state(frame_number_two, frame_observation: frame_observation)

      expect(second_state.fighter1.x).to eq(first_state.fighter1.x)
      expect(second_state.fighter1.y).to eq(first_state.fighter1.y)
      expect(second_state.fighter2.x).to eq(first_state.fighter2.x)
      expect(second_state.fighter2.y).to eq(first_state.fighter2.y)
    end

    it 'preserves the other fighter position when an async scan only finds one side' do
      partial_async_result = {
        detections: [player_one_detection],
        areas: [],
        image_width: vision_image_width,
        image_height: vision_image_height,
        timer: timer_ninety_nine
      }
      allow(vision_detector).to receive(:detect).with(frame_observation).and_return(bootstrap_result)
      allow(scanner).to receive(:latest_result).and_return(partial_async_result)

      first_state = adapter.extract_game_state(frame_number_one, frame_observation: frame_observation)
      second_state = adapter.extract_game_state(frame_number_two, frame_observation: frame_observation)
      third_state = adapter.extract_game_state(frame_number_three, frame_observation: frame_observation)

      expect(second_state.fighter1.x).to eq(first_state.fighter1.x)
      expect(second_state.fighter2.x).to eq(first_state.fighter2.x)
      expect(third_state.fighter1.x).to eq(second_state.fighter1.x)
      expect(third_state.fighter2.x).to eq(second_state.fighter2.x)
    end
  end
end
