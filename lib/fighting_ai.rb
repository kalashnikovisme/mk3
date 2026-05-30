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

# Input devices
require_relative "fighting_ai/input/device"
require_relative "fighting_ai/input/keyboard_input"
require_relative "fighting_ai/input/uinput_device"
require_relative "fighting_ai/input/virtual_input"

# Observation types
require_relative "fighting_ai/observation/provider"
require_relative "fighting_ai/observation/frame_observation"
require_relative "fighting_ai/observation/memory_observation"

# Emulator adapters
require_relative "fighting_ai/emulator/adapter"
require_relative "fighting_ai/emulator/retro_arch/config_builder"
require_relative "fighting_ai/emulator/retro_arch/network_commands"
require_relative "fighting_ai/emulator/retro_arch/process"
require_relative "fighting_ai/emulator/retro_arch/frame_grabber"
require_relative "fighting_ai/emulator/retro_arch/save_state_reader"
require_relative "fighting_ai/emulator/retro_arch/adapter"

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

# Game extensions
require_relative "fighting_ai/game/side_normalizer"
require_relative "fighting_ai/game/reward_calculator"
require_relative "fighting_ai/game/mortal_kombat_3/action_translator"

# Observation providers
require_relative "fighting_ai/observation/structured_observation_provider"

# Agents
require_relative "fighting_ai/agent/base"
require_relative "fighting_ai/agent/rule_based"
require_relative "fighting_ai/agent/ppo_agent"

# Training
require_relative "fighting_ai/training/recorder"
require_relative "fighting_ai/training/dataset_exporter"
require_relative "fighting_ai/training/trajectory_buffer"
require_relative "fighting_ai/training/policy"
require_relative "fighting_ai/training/checkpoint_manager"
require_relative "fighting_ai/training/ppo_trainer"

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

    def configure_game(game_id, &block)
      definition = DSL::GameDefinition.new(game_id)
      definition.instance_eval(&block)
      game_definitions[game_id.to_sym] = definition
      definition
    end

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

    def build_retro_arch_adapter(rom_path:, core_path:, display: ":1")
      config_path       = Emulator::RetroArch::ConfigBuilder.build(core_path: core_path)
      keyboard          = Input::KeyboardInput.new
      frame_grabber     = Emulator::RetroArch::FrameGrabber.new
      save_state_reader = Emulator::RetroArch::SaveStateReader.new(
        watch_dirs:   [
          Emulator::RetroArch::ConfigBuilder.states_dir,
          File.dirname(File.expand_path(rom_path)),
          File.expand_path("~/.config/retroarch/states")
        ],
        rom_basename: File.basename(rom_path, ".*")
      )

      Emulator::RetroArch::Adapter.new(
        rom_path:          rom_path,
        core_path:         core_path,
        config_path:       config_path,
        keyboard:          keyboard,
        frame_grabber:     frame_grabber,
        save_state_reader: save_state_reader,
        display:           display
      )
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
