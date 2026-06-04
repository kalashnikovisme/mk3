require "spec_helper"

RSpec.describe FightingAI::Game::MortalKombat3::RewardFunction do
  REWARD_PLAYER_ONE = 1
  REWARD_PLAYER_TWO = 2
  PLAYER_ONE_X = 0
  CLOSE_PLAYER_TWO_X = 1
  FAR_PLAYER_TWO_X = FightingAI::Game::MortalKombat3::MemoryMap::MAX_FIGHT_DISTANCE
  DEFAULT_Y = 40
  DEFAULT_FRAME_NUMBER = 1
  DEFAULT_ROUND_NUMBER = 1
  DEFAULT_ROUND_TIME = 90
  DEFAULT_MAX_HEALTH = 144
  DAMAGE_DEALT_AMOUNT = 20
  INITIAL_HEALTH = 100
  DAMAGED_OPPONENT_HEALTH = INITIAL_HEALTH - DAMAGE_DEALT_AMOUNT
  DAMAGE_TAKEN_HEALTH = 70
  WINNER_HEALTH = 50
  LOSER_HEALTH = 10
  ZERO_HEALTH = 0

  let(:attrs) do
    {
      max_health:      DEFAULT_MAX_HEALTH,
      facing:          FightingAI::Core::FacingDirection::RIGHT,
      animation_state: FightingAI::Core::AnimationState.new(name: "idle", frame_index: 0, total_frames: 1),
      in_hitstun:      false,
      in_blockstun:    false,
      knocked_down:    false,
      airborne:        false
    }
  end

  def make_state(h1:, h2:, p1_x: PLAYER_ONE_X, p2_x: CLOSE_PLAYER_TWO_X, round_over: false, match_over: false)
    FightingAI::Core::GameState.new(
      frame_number:         DEFAULT_FRAME_NUMBER,
      fighter1:             FightingAI::Core::FighterState.new(**attrs, player_index: REWARD_PLAYER_ONE, health: h1, x: p1_x, y: DEFAULT_Y),
      fighter2:             FightingAI::Core::FighterState.new(**attrs, player_index: REWARD_PLAYER_TWO, health: h2, x: p2_x, y: DEFAULT_Y),
      round_number:         DEFAULT_ROUND_NUMBER,
      round_time_remaining: DEFAULT_ROUND_TIME,
      fight_active:         !round_over,
      round_over:           round_over,
      match_over:           match_over
    )
  end

  subject(:reward_fn) { described_class.new }

  describe "damage dealt" do
    it "gives positive reward when player deals damage" do
      prev  = make_state(h1: INITIAL_HEALTH, h2: INITIAL_HEALTH)
      after = make_state(h1: INITIAL_HEALTH, h2: DAMAGED_OPPONENT_HEALTH)
      reward = reward_fn.call(prev, after, player_index: REWARD_PLAYER_ONE)
      expect(reward.value).to be > 0
      expect(reward.components[:damage_dealt]).to eq(DAMAGE_DEALT_AMOUNT * FightingAI::Game::RewardCalculator::DAMAGE_DEALT_WEIGHT)
    end
  end

  describe "damage taken" do
    it "gives negative reward when player takes damage" do
      prev  = make_state(h1: INITIAL_HEALTH, h2: INITIAL_HEALTH)
      after = make_state(h1: DAMAGE_TAKEN_HEALTH, h2: INITIAL_HEALTH)
      reward = reward_fn.call(prev, after, player_index: REWARD_PLAYER_ONE)
      expect(reward.value).to be < 0
    end
  end

  describe "distance" do
    it "rewards close distance between fighters" do
      prev = make_state(h1: INITIAL_HEALTH, h2: INITIAL_HEALTH, p2_x: FAR_PLAYER_TWO_X)
      after = make_state(h1: INITIAL_HEALTH, h2: INITIAL_HEALTH, p2_x: CLOSE_PLAYER_TWO_X)

      reward = reward_fn.call(prev, after, player_index: REWARD_PLAYER_ONE)

      expect(reward.components[:distance]).to be > 0
    end

    it "punishes long distance between fighters" do
      prev = make_state(h1: INITIAL_HEALTH, h2: INITIAL_HEALTH, p2_x: CLOSE_PLAYER_TWO_X)
      after = make_state(h1: INITIAL_HEALTH, h2: INITIAL_HEALTH, p2_x: FAR_PLAYER_TWO_X)

      reward = reward_fn.call(prev, after, player_index: REWARD_PLAYER_ONE)

      expect(reward.components[:distance]).to be < 0
    end
  end

  describe "round win" do
    it "gives large positive reward for winning the round" do
      prev  = make_state(h1: WINNER_HEALTH, h2: LOSER_HEALTH)
      after = make_state(h1: WINNER_HEALTH, h2: ZERO_HEALTH, round_over: true)
      reward = reward_fn.call(prev, after, player_index: REWARD_PLAYER_ONE)
      expect(reward.components[:round_win]).to eq(FightingAI::Game::RewardCalculator::WIN_REWARD)
    end
  end

  describe "round loss" do
    it "gives large negative reward for losing the round" do
      prev  = make_state(h1: LOSER_HEALTH, h2: WINNER_HEALTH)
      after = make_state(h1: ZERO_HEALTH, h2: WINNER_HEALTH, round_over: true)
      reward = reward_fn.call(prev, after, player_index: REWARD_PLAYER_ONE)
      expect(reward.components[:round_loss]).to eq(FightingAI::Game::RewardCalculator::LOSS_REWARD)
    end
  end
end
