require_relative "input_map"
require_relative "../../core/input_sequence"

module FightingAI
  module Game
    module MortalKombat3
      # Defines the discrete action space for MK3 and translates
      # Core::Action names into InputSequences consumable by the emulator.
      module ActionSpace
        IS = FightingAI::Core::InputSequence

        # Each entry: action_name => proc(player_index) => InputSequence
        ACTIONS = {
          idle: ->(_pi) { IS.empty },

          walk_forward: ->(pi) {
            # "Forward" depends on facing direction; the adapter resolves this
            # by passing the correct directional button via context.
            IS.single(:right)
          },
          walk_back: ->(_pi) { IS.single(:left) },

          jump: ->(_pi) { IS.single(:up) },
          duck: ->(_pi) { IS.new.press([:down], hold_frames: 2) },

          low_punch:  ->(_pi) { IS.single(:low_punch) },
          high_punch: ->(_pi) { IS.single(:high_punch) },
          low_kick:   ->(_pi) { IS.single(:low_kick) },
          high_kick:  ->(_pi) { IS.single(:high_kick) },
          block:      ->(_pi) { IS.new.press([:block], hold_frames: 3) },
          run:        ->(_pi) { IS.new.press([:run], hold_frames: 2) },

          # Crouch attacks
          crouch_punch: ->(_pi) { IS.new.press([:down]).press([:low_punch]) },
          crouch_kick:  ->(_pi) { IS.new.press([:down]).press([:low_kick]) },

          # Jump attacks
          jump_punch: ->(_pi) { IS.new.press([:up]).press([:high_punch]) },
          jump_kick:  ->(_pi) { IS.new.press([:up]).press([:high_kick]) },

          # Throws (forward = toward opponent)
          throw_forward: ->(_pi) { IS.new.press(%i[low_punch high_punch]) },
          throw_back:    ->(_pi) { IS.new.press(%i[low_punch high_punch]) }
        }.freeze

        def self.all_action_names
          ACTIONS.keys
        end

        def self.to_input_sequence(action_name, player_index:)
          builder = ACTIONS.fetch(action_name.to_sym) do
            raise ArgumentError, "Unknown action: #{action_name}"
          end
          builder.call(player_index)
        end

        def self.valid?(action_name)
          ACTIONS.key?(action_name.to_sym)
        end
      end
    end
  end
end
