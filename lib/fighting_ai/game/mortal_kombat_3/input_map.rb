module FightingAI
  module Game
    module MortalKombat3
      # Maps logical button names (from the DSL / game definition)
      # to BizHawk controller button strings for the SNES core.
      # BizHawk uses "P1 Left", "P1 Right", etc. in its Lua API.
      module InputMap
        PLAYER_PREFIX = {
          1 => "P1 ",
          2 => "P2 "
        }.freeze

        # Logical name => BizHawk button suffix
        BUTTON_MAP = {
          up:         "Up",
          down:       "Down",
          left:       "Left",
          right:      "Right",
          low_punch:  "Y",    # SNES Y button
          high_punch: "X",    # SNES X button
          low_kick:   "B",    # SNES B button
          high_kick:  "A",    # SNES A button
          block:      "L",    # SNES L trigger
          run:        "R"     # SNES R trigger
        }.freeze

        def self.to_bizhawk(logical_buttons, player_index:)
          prefix = PLAYER_PREFIX.fetch(player_index) { raise ArgumentError, "Unknown player #{player_index}" }
          logical_buttons.each_with_object({}) do |btn, hash|
            bizhawk_key = BUTTON_MAP.fetch(btn.to_sym) { raise ArgumentError, "Unknown button: #{btn}" }
            hash["#{prefix}#{bizhawk_key}"] = true
          end
        end

        def self.all_released(player_index:)
          prefix = PLAYER_PREFIX.fetch(player_index)
          BUTTON_MAP.values.each_with_object({}) do |suffix, hash|
            hash["#{prefix}#{suffix}"] = false
          end
        end

        def self.logical_buttons
          BUTTON_MAP.keys
        end
      end
    end
  end
end
