module FightingAI
  module Core
    Frame = Data.define(:number, :game_id, :game_state, :captured_at) do
      def self.create(number:, game_id:, game_state:)
        new(
          number:      number,
          game_id:     game_id,
          game_state:  game_state,
          captured_at: Time.now
        )
      end
    end
  end
end
