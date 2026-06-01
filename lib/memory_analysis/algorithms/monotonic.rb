module MemoryAnalysis
  module Algorithms
    # Finds addresses whose values are strictly increasing (or decreasing) across
    # a sequence of dumps.  Scores candidates by the fraction of ordered
    # consecutive pairs multiplied by a delta weight so that addresses with tiny
    # total change rank below those with meaningful motion.
    module Monotonic
      MIN_DELTA = 2   # ignore addresses that barely moved
      DELTA_CAP = 30  # delta at which the weight saturates to 1.0

      def self.find(dumps, direction:, top_n: 20, widths: %i[u8 u16le])
        widths.flat_map { |w| scan(dumps, w, direction) }
              .sort_by { |c| -c.score }
              .first(top_n)
      end

      private_class_method def self.scan(dumps, width, direction)
        limit = width == :u16le ? Dump::WRAM_SIZE - 1 : Dump::WRAM_SIZE
        results = []

        (0...limit).each do |addr|
          values = dumps.map { |d| d.send(width, addr) }
          total_delta = values.max - values.min
          next if total_delta < MIN_DELTA

          pairs = values.each_cons(2).to_a
          ordered = direction == :increasing ?
            pairs.count { |a, b| b > a } :
            pairs.count { |a, b| b < a }

          monotone_score = ordered.to_f / pairs.size
          next if monotone_score < 0.5

          delta_weight = [total_delta.to_f / DELTA_CAP, 1.0].min
          score        = monotone_score * delta_weight

          results << Candidate.new(address: addr, score: score, values: values, width: width)
        end

        results
      end
    end
  end
end
