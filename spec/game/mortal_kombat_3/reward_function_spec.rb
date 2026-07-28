require "spec_helper"

RSpec.describe FightingAI::Game::MortalKombat3::RewardFunction do
  REWARD_PLAYER_ONE = 1
  REWARD_PLAYER_TWO = 2
  PLAYER_ONE_X = 0
  TOO_CLOSE_PLAYER_TWO_X = FightingAI::Game::MortalKombat3::RewardFunction::TOO_CLOSE_DISTANCE.to_i
  PREFERRED_RANGE_PLAYER_TWO_X = FightingAI::Game::MortalKombat3::RewardFunction::PREFERRED_RANGE_MIN_DISTANCE.to_i + 10
  MID_PLAYER_TWO_X = FightingAI::Game::MortalKombat3::RewardFunction::APPROACH_RANGE_START_DISTANCE.to_i - 20
  FAR_PLAYER_TWO_X = FightingAI::Game::MortalKombat3::MemoryMap::MAX_FIGHT_DISTANCE
  RESET_DISTANCE_PLAYER_TWO_X = FightingAI::Game::MortalKombat3::RewardFunction::TOO_CLOSE_DISTANCE.to_i + 30
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

  def make_state(h1:, h2:, p1_x: PLAYER_ONE_X, p2_x: PREFERRED_RANGE_PLAYER_TWO_X, round_over: false, match_over: false)
    FightingAI::Core::GameState.new(
      frame_number:         DEFAULT_FRAME_NUMBER,
      fighter1:             FightingAI::Core::FighterState.new(player_index: REWARD_PLAYER_ONE, health: h1, max_health: DEFAULT_MAX_HEALTH, x: p1_x, y: DEFAULT_Y),
      fighter2:             FightingAI::Core::FighterState.new(player_index: REWARD_PLAYER_TWO, health: h2, max_health: DEFAULT_MAX_HEALTH, x: p2_x, y: DEFAULT_Y),
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
      expect(reward.components[:damage_dealt]).to eq(DAMAGE_DEALT_AMOUNT * FightingAI.config.reward_damage_dealt)
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

  describe "close range" do
    it "rewards maintaining the preferred spacing band" do
      close_state = make_state(h1: INITIAL_HEALTH, h2: INITIAL_HEALTH, p2_x: PREFERRED_RANGE_PLAYER_TWO_X)
      far_state = make_state(h1: INITIAL_HEALTH, h2: INITIAL_HEALTH, p2_x: FAR_PLAYER_TWO_X)

      close_reward = reward_fn.call(close_state, close_state, player_index: REWARD_PLAYER_ONE)
      far_reward = reward_fn.call(far_state, far_state, player_index: REWARD_PLAYER_ONE)

      expect(close_reward.components[:close_range]).to be > far_reward.components[:close_range]
      expect(far_reward.components[:close_range]).to eq(0.0)
    end
  end

  describe "approach" do
    it "rewards moving closer from long range" do
      prev = make_state(h1: INITIAL_HEALTH, h2: INITIAL_HEALTH, p2_x: FAR_PLAYER_TWO_X)
      after = make_state(h1: INITIAL_HEALTH, h2: INITIAL_HEALTH, p2_x: MID_PLAYER_TWO_X)

      reward = reward_fn.call(prev, after, player_index: REWARD_PLAYER_ONE)

      expect(reward.components[:approach]).to be > 0.0
    end

    it "does not reward closing distance when already inside the approach band" do
      prev = make_state(h1: INITIAL_HEALTH, h2: INITIAL_HEALTH, p2_x: PREFERRED_RANGE_PLAYER_TWO_X)
      after = make_state(h1: INITIAL_HEALTH, h2: INITIAL_HEALTH, p2_x: TOO_CLOSE_PLAYER_TWO_X)

      reward = reward_fn.call(prev, after, player_index: REWARD_PLAYER_ONE)

      expect(reward.components[:approach]).to eq(0.0)
    end
  end

  describe "distance reset" do
    it "rewards opening space after getting too close" do
      prev = make_state(h1: INITIAL_HEALTH, h2: INITIAL_HEALTH, p2_x: TOO_CLOSE_PLAYER_TWO_X)
      after = make_state(h1: INITIAL_HEALTH, h2: INITIAL_HEALTH, p2_x: RESET_DISTANCE_PLAYER_TWO_X)

      reward = reward_fn.call(prev, after, player_index: REWARD_PLAYER_ONE)

      expect(reward.components[:distance_reset]).to be > 0.0
    end

    it "does not reward walking farther away from long range" do
      prev = make_state(h1: INITIAL_HEALTH, h2: INITIAL_HEALTH, p2_x: FAR_PLAYER_TWO_X - 10)
      after = make_state(h1: INITIAL_HEALTH, h2: INITIAL_HEALTH, p2_x: FAR_PLAYER_TWO_X)

      reward = reward_fn.call(prev, after, player_index: REWARD_PLAYER_ONE)

      expect(reward.components[:distance_reset]).to eq(0.0)
    end
  end

  describe "distance escape" do
    it "rewards escaping from too close into the preferred band" do
      prev = make_state(h1: INITIAL_HEALTH, h2: INITIAL_HEALTH, p2_x: TOO_CLOSE_PLAYER_TWO_X)
      after = make_state(h1: INITIAL_HEALTH, h2: INITIAL_HEALTH, p2_x: PREFERRED_RANGE_PLAYER_TWO_X)

      reward = reward_fn.call(prev, after, player_index: REWARD_PLAYER_ONE)

      expect(reward.components[:distance_escape]).to eq(FightingAI.config.reward_distance_escape)
    end

    it "does not reward escaping if the fighters remain too close" do
      prev = make_state(h1: INITIAL_HEALTH, h2: INITIAL_HEALTH, p2_x: TOO_CLOSE_PLAYER_TWO_X)
      after = make_state(h1: INITIAL_HEALTH, h2: INITIAL_HEALTH, p2_x: TOO_CLOSE_PLAYER_TWO_X + 1)

      reward = reward_fn.call(prev, after, player_index: REWARD_PLAYER_ONE)

      expect(reward.components[:distance_escape]).to eq(0.0)
    end
  end

  describe "too close" do
    it "penalizes remaining in the too-close band" do
      close_state = make_state(h1: INITIAL_HEALTH, h2: INITIAL_HEALTH, p2_x: TOO_CLOSE_PLAYER_TWO_X)

      reward = reward_fn.call(close_state, close_state, player_index: REWARD_PLAYER_ONE)

      expect(reward.components[:too_close]).to eq(FightingAI.config.reward_too_close)
    end

    it "does not penalize preferred spacing" do
      preferred_state = make_state(h1: INITIAL_HEALTH, h2: INITIAL_HEALTH, p2_x: PREFERRED_RANGE_PLAYER_TWO_X)

      reward = reward_fn.call(preferred_state, preferred_state, player_index: REWARD_PLAYER_ONE)

      expect(reward.components[:too_close]).to eq(0.0)
    end
  end

  describe "round win" do
    it "gives large positive reward for winning the round" do
      prev  = make_state(h1: WINNER_HEALTH, h2: LOSER_HEALTH)
      after = make_state(h1: WINNER_HEALTH, h2: ZERO_HEALTH, round_over: true)
      reward = reward_fn.call(prev, after, player_index: REWARD_PLAYER_ONE)
      expect(reward.components[:round_win]).to eq(FightingAI.config.reward_win)
    end
  end

  describe "round loss" do
    it "gives large negative reward for losing the round" do
      prev  = make_state(h1: LOSER_HEALTH, h2: WINNER_HEALTH)
      after = make_state(h1: ZERO_HEALTH, h2: WINNER_HEALTH, round_over: true)
      reward = reward_fn.call(prev, after, player_index: REWARD_PLAYER_ONE)
      expect(reward.components[:round_loss]).to eq(FightingAI.config.reward_loss)
    end
  end
end
