module FightingAI
  module Core
    Frame = Data.define(:number, :game_id, :game_state, :raw_data, :captured_at) do
      def self.from_snapshot(number:, game_id:, game_state:, raw_data:)
        new(
          number:      number,
          game_id:     game_id,
          game_state:  game_state,
          raw_data:    raw_data,
          captured_at: Time.now
        )
      end
    end
  end
end
