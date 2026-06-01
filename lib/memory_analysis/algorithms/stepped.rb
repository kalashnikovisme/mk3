module MemoryAnalysis
  module Algorithms
    # Finds addresses that change by a constant arithmetic step across three
    # snapshots.  Handles both decreasing (display timer: 99→98→97) and
    # increasing (elapsed timer: 0→1→2) encodings.
    #
    # Pass `expected:` (e.g. [99, 98, 97]) for an exact-match bonus.
    module Stepped
      def self.find(dumps, expected: nil, top_n: 20)
        d1, d2, d3 = dumps
        results_u8  = scan(d1, d2, d3, :u8,    expected)
        results_u16 = scan(d1, d2, d3, :u16le, nil)
        (results_u8 + results_u16).sort_by { |c| -c.score }.first(top_n)
      end

      private_class_method def self.scan(d1, d2, d3, width, expected)
        limit   = width == :u16le ? Dump::WRAM_SIZE - 1 : Dump::WRAM_SIZE
        results = []

        (0...limit).each do |addr|
          v1 = d1.send(width, addr)
          v2 = d2.send(width, addr)
          v3 = d3.send(width, addr)

          step_12 = v2 - v1
          step_23 = v3 - v2

          # Must change by the same non-zero step both times
          next if step_12 != step_23
          next if step_12 == 0

          score = if expected && width == :u8 && [v1, v2, v3] == expected
                    1.0   # exact expected sequence
                  elsif expected && width == :u8 && [v1, v2, v3] == expected.reverse
                    0.95  # inverted expected sequence
                  elsif step_12.abs == 1
                    0.8   # unit step (most likely a timer)
                  else
                    0.4   # constant but larger step
                  end

          results << Candidate.new(
            address: addr,
            score:   score,
            values:  [v1, v2, v3],
            width:   width
          )
        end

        results
      end
    end
  end
end
