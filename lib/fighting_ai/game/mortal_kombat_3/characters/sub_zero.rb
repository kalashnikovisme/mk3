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
              .press([:down, :forward, :low_punch], hold_frames: 1)

          },
          # D, F + HP
          ice_shower: ->(_pi) {
            IS.new
              .press([:down],               hold_frames: 1)
              .press([:forward, :high_punch], hold_frames: 1)
          },
          # D, B + LP
          ice_clone: ->(_pi) {
            IS.new
              .press([:down],             hold_frames: 1)
              .idle(1)
              .press([:down, :back, :low_punch], hold_frames: 1)
          },
          air_ice_clone: ->(_pi) {
            IS.new
              .press([:up],             hold_frames: 1)
              .press([:down, :back, :low_punch], hold_frames: 1)
          },
          # B + BL + LP + LK simultaneously
          slide: ->(_pi) {
            IS.new.press([:back, :block, :low_punch, :low_kick], hold_frames: 3)
          },
          # D, F, B + HP
          ice_shower_front: ->(_pi) {
            IS.new
              .press([:down],               hold_frames: 1)
              .press([:forward],              hold_frames: 1)
              .press([:back, :high_punch],  hold_frames: 1)
          },
          # D, B, F + HP
          ice_shower_back: ->(_pi) {
            IS.new
              .press([:down],               hold_frames: 1)
              .press([:back],               hold_frames: 1)
              .press([:forward, :high_punch], hold_frames: 1)
          },
          # HP, HP, B + HK
          combo_1: ->(_pi) {
            IS.new
              .press([:high_punch],        hold_frames: 1)
              .idle(1)
              .press([:high_punch],        hold_frames: 1)
              .press([:back, :high_kick], hold_frames: 1)
          },
          # HP, HP, LP, B + HK
          combo_2: ->(_pi) {
            IS.new
              .press([:high_punch],        hold_frames: 1)
              .idle(1)
              .press([:high_punch],        hold_frames: 1)
              .press([:low_punch],        hold_frames: 1)
              .press([:back, :high_kick], hold_frames: 1)
          },
          # HP, HP, LK, HK, B + HK
          combo_3: ->(_pi) {
            IS.new
              .press([:high_punch],        hold_frames: 1)
              .idle(1)
              .press([:high_punch],        hold_frames: 1)
              .press([:low_kick],        hold_frames: 1)
              .press([:high_kick],        hold_frames: 1)
              .idle(1)
              .press([:back, :high_kick], hold_frames: 1)
          },
          # HP, HP, LP, LK, HK, B + HK
          combo_4: ->(_pi) {
            IS.new
              .press([:high_punch],        hold_frames: 1)
              .idle(1)
              .press([:high_punch],        hold_frames: 1)
              .press([:low_punch],        hold_frames: 1)
              .press([:low_kick],        hold_frames: 1)
              .press([:high_kick],        hold_frames: 1)
              .idle(1)
              .press([:back, :high_kick], hold_frames: 1)
          },
          # HK, HK, B + HK
          combo_5: ->(_pi) {
            IS.new
              .press([:high_kick],        hold_frames: 1)
              .idle(1)
              .press([:high_kick],        hold_frames: 1)
              .idle(1)
              .press([:back, :high_kick], hold_frames: 1)
          },
        }.freeze

        DIRECTION_SENSITIVE_MOVES = SPECIAL_MOVES.keys.freeze
      end
    end
  end
end
