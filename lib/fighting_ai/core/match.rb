module FightingAI
  module Core
    class Match
      attr_reader :id, :game_id, :rounds, :player1_character, :player2_character, :started_at, :finished_at

      def initialize(game_id:, player1_character:, player2_character:)
        @id                 = SecureRandom.uuid
        @game_id            = game_id
        @player1_character  = player1_character
        @player2_character  = player2_character
        @rounds             = []
        @started_at         = Time.now
        @finished_at        = nil
        @current_round      = nil
      end

      def start_round(number)
        @current_round = Round.new(number: number)
        @rounds << @current_round
        @current_round
      end

      def current_round
        @current_round
      end

      def finish!
        @finished_at = Time.now
      end

      def finished? = !@finished_at.nil?

      def winner
        wins = rounds.each_with_object(Hash.new(0)) { |r, h| h[r.winner] += 1 if r.winner }
        wins.max_by { |_, count| count }&.first
      end

      def player1_rounds_won
        rounds.count { |r| r.winner == 1 }
      end

      def player2_rounds_won
        rounds.count { |r| r.winner == 2 }
      end

      def total_frames
        rounds.sum(&:frame_count)
      end

      def duration
        return nil unless finished?
        @finished_at - @started_at
      end
    end
  end
end
