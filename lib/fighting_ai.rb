require "securerandom"
require_relative "fighting_ai/version"

# Core domain
require_relative "fighting_ai/core/fighter_state"
require_relative "fighting_ai/core/game_state"
require_relative "fighting_ai/core/frame"
require_relative "fighting_ai/core/observation"
require_relative "fighting_ai/core/action"
require_relative "fighting_ai/core/input_sequence"
require_relative "fighting_ai/core/reward"
require_relative "fighting_ai/core/round"
require_relative "fighting_ai/core/match"

# DSL
require_relative "fighting_ai/dsl/game_definition"
require_relative "fighting_ai/dsl/training_definition"
require_relative "fighting_ai/dsl/match_setup"

# Emulator adapters
require_relative "fighting_ai/emulator/adapter"
require_relative "fighting_ai/emulator/bizhawk/bridge_server"
require_relative "fighting_ai/emulator/bizhawk/adapter"

# Game adapters
require_relative "fighting_ai/game/adapter"
require_relative "fighting_ai/game/mortal_kombat_3/memory_map"
require_relative "fighting_ai/game/mortal_kombat_3/input_map"
require_relative "fighting_ai/game/mortal_kombat_3/action_space"
require_relative "fighting_ai/game/mortal_kombat_3/observation_space"
require_relative "fighting_ai/game/mortal_kombat_3/reward_function"
require_relative "fighting_ai/game/mortal_kombat_3/state_extractor"
require_relative "fighting_ai/game/mortal_kombat_3/menu_navigator"
require_relative "fighting_ai/game/mortal_kombat_3/characters"
require_relative "fighting_ai/game/mortal_kombat_3/adapter"

# Agents
require_relative "fighting_ai/agent/base"
require_relative "fighting_ai/agent/rule_based"

# Training
require_relative "fighting_ai/training/recorder"
require_relative "fighting_ai/training/dataset_exporter"

# Runtime
require_relative "fighting_ai/runtime/match_runner"
require_relative "fighting_ai/runtime/human_vs_ai"
require_relative "fighting_ai/runtime/ai_vs_ai"

module FightingAI
  class << self
    def game_definitions
      @game_definitions ||= {}
    end

    def training_definitions
      @training_definitions ||= {}
    end

    # DSL entry point: FightingAI.configure_game :mortal_kombat_3 do ... end
    def configure_game(game_id, &block)
      definition = DSL::GameDefinition.new(game_id)
      definition.instance_eval(&block)
      game_definitions[game_id.to_sym] = definition
      definition
    end

    # DSL entry point: FightingAI.training :mk3_imitation do ... end
    def training(training_id, &block)
      definition = DSL::TrainingDefinition.new(training_id)
      definition.instance_eval(&block)
      training_definitions[training_id.to_sym] = definition
      definition
    end

    def game(game_id)
      game_definitions.fetch(game_id.to_sym) do
        raise ArgumentError, "No game configured for :#{game_id}. Call FightingAI.configure_game first."
      end
    end

    def build_bizhawk_adapter(host: "127.0.0.1", port: 7878)
      Emulator::BizHawk::Adapter.new(host: host, port: port)
    end

    def build_mk3_adapter(emulator_adapter:, reward_weights: {})
      game_def = game(:mortal_kombat_3)
      Game::MortalKombat3::Adapter.new(
        emulator_adapter: emulator_adapter,
        game_definition:  game_def,
        reward_weights:   reward_weights
      )
    end

    def match_setup(&block)
      setup = DSL::MatchSetup.new
      setup.instance_eval(&block)
      setup
    end

    def random_character
      DSL.random_character
    end

    def sample_from_pool(pool_name)
      DSL.sample_from_pool(pool_name)
    end
  end
end
