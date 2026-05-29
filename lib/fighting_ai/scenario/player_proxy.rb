module FightingAI
  module Scenario
    # DSL object exposed as P1 / P2 inside scenario files.
    # Every method sends real xdotool inputs to the live RetroArch window.
    class PlayerProxy

      def initialize(player_index, emulator)
        @player_index = player_index
        @emulator     = emulator
      end

      # ── Movement ────────────────────────────────────────────────────────────
      def right(frames = 1) = hold(:right, frames)
      def left(frames = 1)  = hold(:left,  frames)
      def up(frames = 1)    = hold(:up,    frames)
      def down(frames = 1)  = hold(:down,  frames)

      # ── Attacks ─────────────────────────────────────────────────────────────
      def low_punch(frames = 1)  = hold(:low_punch,  frames)
      def high_punch(frames = 1) = hold(:high_punch, frames)
      def low_kick(frames = 1)   = hold(:low_kick,   frames)
      def high_kick(frames = 1)  = hold(:high_kick,  frames)

      # ── Defence ─────────────────────────────────────────────────────────────
      def block(frames = 1) = hold(:block, frames)
      def run(frames = 1)   = hold(:run,   frames)

      # ── Combined inputs ──────────────────────────────────────────────────────
      def crouch_punch(frames = 1) = hold_multi(%i[down low_punch],  frames)
      def crouch_kick(frames = 1)  = hold_multi(%i[down low_kick],   frames)
      def jump_punch(frames = 1)   = hold_multi(%i[up   high_punch], frames)
      def jump_kick(frames = 1)    = hold_multi(%i[up   high_kick],  frames)
      def throw(frames = 1)        = hold_multi(%i[low_punch high_punch], frames)

      # ── Timing ──────────────────────────────────────────────────────────────
      # Release all inputs and pause for N frames.
      def wait(frames = 1)
        release_all
        sleep(frames * Scenario.frame_duration)
      end

      private

      def hold(button, frames)
        buttons = Game::MortalKombat3::InputMap.all_released
        buttons[button] = true
        send_for(buttons, frames)
        release_all
      end

      def hold_multi(button_list, frames)
        buttons = Game::MortalKombat3::InputMap.all_released
        button_list.each { |b| buttons[b] = true }
        send_for(buttons, frames)
        release_all
      end

      def send_for(buttons, frames)
        frames.times do
          @emulator.send_input(@player_index, buttons)
          sleep(Scenario.frame_duration)
        end
      end

      def release_all
        @emulator.send_input(@player_index, Game::MortalKombat3::InputMap.all_released)
        sleep(Scenario.frame_duration)
      end
    end
  end
end
