require "spec_helper"
require "fighting_ai/agent/ppo_agent"

RSpec.describe FightingAI::Agent::PPOAgent do
  PLAYER_INDEX = 1
  POLICY_ACTION_INDEX = 3
  RAW_REWARD_VALUE = 200.0
  EXPECTED_CLIPPED_REWARD = FightingAI::Agent::PPOAgent::TRAINING_REWARD_CLIP_MAGNITUDE *
                            FightingAI::Agent::PPOAgent::TRAINING_REWARD_SCALE
  FRAME_NUMBER = 42
  MY_HEALTH_PCT = 0.75
  OPPONENT_HEALTH_PCT = 0.5
  MY_X_NORMALIZED = 0.2
  MY_Y_NORMALIZED = 0.0
  OPPONENT_X_NORMALIZED = 0.8
  OPPONENT_Y_NORMALIZED = 0.0
  ROUND_TIME_NORMALIZED = 0.9

  let(:policy) do
    instance_double(
      "Policy",
      forward: {
        action_index: POLICY_ACTION_INDEX,
        log_prob: -1.25,
        value: 0.5
      }
    )
  end

  let(:action_translator) do
    instance_double(
      "ActionTranslator",
      action_count: 7,
      to_game_action: FightingAI::Core::Action.named(:walk_forward)
    )
  end

  let(:buffer) { instance_double("TrajectoryBuffer", push: nil) }
  let(:observation) do
    FightingAI::Core::Observation.new(
      frame_number: FRAME_NUMBER,
      my_health_pct: MY_HEALTH_PCT,
      opponent_health_pct: OPPONENT_HEALTH_PCT,
      my_x_normalized: MY_X_NORMALIZED,
      my_y_normalized: MY_Y_NORMALIZED,
      opponent_x_normalized: OPPONENT_X_NORMALIZED,
      opponent_y_normalized: OPPONENT_Y_NORMALIZED,
      round_time_normalized: ROUND_TIME_NORMALIZED,
      raw: nil
    )
  end

  subject(:agent) do
    described_class.new(
      player_index: PLAYER_INDEX,
      policy: policy,
      action_translator: action_translator,
      buffer: buffer,
      exploration: 0.0
    )
  end

  describe "#observe_reward" do
    it "clips and scales the reward before pushing a transition" do
      agent.act(observation)

      expect(buffer).to receive(:push).with(
        obs: kind_of(Array),
        action: POLICY_ACTION_INDEX,
        log_prob: -1.25,
        value: 0.5,
        reward: EXPECTED_CLIPPED_REWARD,
        done: true
      )

      reward = FightingAI::Core::Reward.compose(damage_dealt: RAW_REWARD_VALUE)
      agent.observe_reward(reward, done: true)

      expect(agent.episode_reward).to be_within(0.0001).of(EXPECTED_CLIPPED_REWARD)
      expect(agent.episode_components[:damage_dealt]).to eq(RAW_REWARD_VALUE)
    end
  end
end
