module FightingAI
  module Game
    module MortalKombat3
      module InputMap
        PLAYER_PREFIX = {
          1 => "P1 ",
          2 => "P2 "
        }.freeze

        # Logical button name => SNES button name (for documentation purposes)
        BUTTON_MAP = {
          up:         "Up",
          down:       "Down",
          left:       "Left",
          right:      "Right",
          low_punch:  "Y",
          high_punch: "X",
          low_kick:   "B",
          high_kick:  "A",
          block:      "L",
          run:        "R",
          start:      "Start"
        }.freeze

        # Convert an array of logical button symbols to a { logical_symbol => bool } hash.
        # player_index is accepted but ignored — logical names are universal.
        def self.to_logical(buttons_array, player_index: nil)
          BUTTON_MAP.keys.each_with_object({}) do |btn, hash|
            hash[btn] = buttons_array.map(&:to_sym).include?(btn)
          end
        end

        # When called without player_index: returns { logical_symbol => false } (new API).
        # When called with player_index: returns { "P1 Up" => false, ... } (compat shim).
        def self.all_released(player_index: nil)
          if player_index
            prefix = PLAYER_PREFIX.fetch(player_index)
            BUTTON_MAP.values.each_with_object({}) do |suffix, hash|
              hash["#{prefix}#{suffix}"] = false
            end
          else
            BUTTON_MAP.keys.each_with_object({}) do |btn, hash|
              hash[btn] = false
            end
          end
        end

        def self.logical_buttons
          BUTTON_MAP.keys
        end

        # Kept for backward compatibility with existing specs.
        def self.to_bizhawk(logical_buttons, player_index:)
          prefix = PLAYER_PREFIX.fetch(player_index) { raise ArgumentError, "Unknown player #{player_index}" }
          logical_buttons.each_with_object({}) do |btn, hash|
            bizhawk_key = BUTTON_MAP.fetch(btn.to_sym) { raise ArgumentError, "Unknown button: #{btn}" }
            hash["#{prefix}#{bizhawk_key}"] = true
          end
        end
      end
    end
  end
end
