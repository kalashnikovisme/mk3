module MemoryAnalysis
  module Algorithms
    # Finds addresses that decreased between two snapshots (before → after).
    # Useful for health: after taking damage the health value drops.
    module Decreasing
      MIN_DECREASE = 5  # ignore tiny fluctuations

      # dumps order: [before (higher), after (lower)]
      def self.find(dumps, top_n: 20)
        before_dump, after_dump = dumps
        results_u8  = scan(before_dump, after_dump, :u8)
        results_u16 = scan(before_dump, after_dump, :u16le)
        (results_u8 + results_u16).sort_by { |c| -c.score }.first(top_n)
      end

      private_class_method def self.scan(before_dump, after_dump, width)
        max_range = width == :u16le ? 65_535.0 : 255.0
        limit     = width == :u16le ? Dump::WRAM_SIZE - 1 : Dump::WRAM_SIZE
        results   = []

        (0...limit).each do |addr|
          v_before = before_dump.send(width, addr)
          v_after  = after_dump.send(width, addr)
          decrease = v_before - v_after
          next if decrease < MIN_DECREASE

          score = decrease.to_f / max_range
          results << Candidate.new(
            address: addr,
            score:   score,
            values:  [v_before, v_after],
            width:   width
          )
        end

        results
      end
    end
  end
end
