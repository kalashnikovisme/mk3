require "anyway_config"

module FightingAI
  module Emulator
    module RetroArch
      class AdapterConfig < Anyway::Config
        config_name :adapter

        attr_config(
          step_frames: 6,
          speed:       1.0
        )
      end
    end
  end
end
