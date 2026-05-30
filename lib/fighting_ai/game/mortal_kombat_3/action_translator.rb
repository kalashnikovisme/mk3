require_relative "../../core/action"

module FightingAI
  module Game
    module MortalKombat3
      # Maps the normalized RL action space to MK3 game adapter action names.
      #
      # The policy selects from ACTIONS by index. The translator converts that
      # index to a Core::Action whose name the MK3 adapter understands and can
      # translate to controller button states.
      #
      # Forward/backward direction handling is already built into the game adapter:
      # Adapter#action_to_input_sequence flips walk_forward / walk_back based on
      # the fighter's actual facing direction. The policy therefore never needs to
      # reason about which side of the screen it occupies.
      module ActionTranslator
        ACTIONS = %i[
          idle
          forward
          backward
          jump
          crouch
          block
          high_punch
          low_punch
          high_kick
          low_kick
          forward_high_punch
          forward_low_kick
          backward_block
          jump_forward
          jump_backward
          crouch_block
        ].freeze

        GAME_ACTION_MAP = {
          idle:               :idle,
          forward:            :walk_forward,
          backward:           :walk_back,
          jump:               :jump,
          crouch:             :duck,
          block:              :block,
          high_punch:         :high_punch,
          low_punch:          :low_punch,
          high_kick:          :high_kick,
          low_kick:           :low_kick,
          forward_high_punch: :jump_punch,
          forward_low_kick:   :crouch_kick,
          backward_block:     :block,
          jump_forward:       :jump_punch,
          jump_backward:      :jump,
          crouch_block:       :block
        }.freeze

        def self.action_count
          ACTIONS.size
        end

        def self.to_game_action(index)
          name      = ACTIONS.fetch(index) { raise ArgumentError, "Invalid action index: #{index}" }
          game_name = GAME_ACTION_MAP.fetch(name)
          Core::Action.named(game_name)
        end

        def self.action_name(index)
          ACTIONS.fetch(index)
        end
      end
    end
  end
end
