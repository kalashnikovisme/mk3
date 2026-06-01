module MemoryAnalysis
  module Algorithms
    # Finds addresses that changed between two snapshots and whose values are
    # drawn from a small set — characteristic of flags and direction enums.
    # Scores are highest when the transition is exactly 0↔1 and fall off as the
    # value range grows.
    module BinaryTransition
      def self.find(dumps, top_n: 20)
        before_dump, after_dump = dumps
        results_u8  = scan(before_dump, after_dump, :u8)
        results_u16 = scan(before_dump, after_dump, :u16le)
        (results_u8 + results_u16).sort_by { |c| -c.score }.first(top_n)
      end

      private_class_method def self.scan(before_dump, after_dump, width)
        limit   = width == :u16le ? Dump::WRAM_SIZE - 1 : Dump::WRAM_SIZE
        results = []

        (0...limit).each do |addr|
          v_before = before_dump.send(width, addr)
          v_after  = after_dump.send(width, addr)
          next if v_before == v_after

          max_val = [v_before, v_after].max
          score = case max_val
                  when 0..1   then 1.0   # perfect binary flag  (0 ↔ 1)
                  when 2..3   then 0.8   # small enum            (facing: 0/1/2/3)
                  when 4..7   then 0.6
                  when 8..15  then 0.4
                  when 16..31 then 0.25
                  else             0.1   # generic byte change
                  end

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
