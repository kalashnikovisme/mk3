require_relative "../../../core/input_sequence"

module FightingAI
  module Game
    module MortalKombat3
      module SubZero
        IS = Core::InputSequence

        # All moves are encoded assuming the player faces right (toward = :right,
        # away = :left). The MK3 adapter's flip_direction handles left-facing players.
        SPECIAL_MOVES = {
          # D, F + LP
          ice_ball: ->(_pi) {
            IS.new
              .press([:down],              hold_frames: 1)
              .idle(1)
              .press([:down, :right, :low_punch], hold_frames: 1)

          },
          # D, F + HP
          ice_shower: ->(_pi) {
            IS.new
              .press([:down],               hold_frames: 1)
              .press([:right, :high_punch], hold_frames: 1)
          },
          # D, B + LP
          ice_clone: ->(_pi) {
            IS.new
              .press([:down],             hold_frames: 1)
              .idle(1)
              .press([:down, :left, :low_punch], hold_frames: 1)
          },
          # B + BL + LP + LK simultaneously
          slide: ->(_pi) {
            IS.new.press([:left, :block, :low_punch, :low_kick], hold_frames: 3)
          },
          # D, F, B + HP
          ice_shower_front: ->(_pi) {
            IS.new
              .press([:down],               hold_frames: 1)
              .press([:right],              hold_frames: 1)
              .press([:left, :high_punch],  hold_frames: 1)
          },
          # D, B, F + HP
          ice_shower_back: ->(_pi) {
            IS.new
              .press([:down],               hold_frames: 1)
              .press([:left],               hold_frames: 1)
              .press([:right, :high_punch], hold_frames: 1)
          },
        }.freeze

        DIRECTION_SENSITIVE_MOVES = SPECIAL_MOVES.keys.freeze
      end
    end
  end
end
