module FightingAI
  module Core
    GameState = Data.define(
      :frame_number,
      :fighter1,
      :fighter2,
      :round_number,
      :round_time_remaining,
      :fight_active,
      :round_over,
      :match_over
    ) do
      def distance
        fighter1.distance_to(fighter2)
      end

      def fight_active? = fight_active
      def round_over?   = round_over
      def match_over?   = match_over

      def fighter_for(player_index)
        case player_index
        when 1 then fighter1
        when 2 then fighter2
        else raise ArgumentError, "player_index must be 1 or 2, got #{player_index}"
        end
      end

      def opponent_of(player_index)
        fighter_for(player_index == 1 ? 2 : 1)
      end
    end
  end
end
