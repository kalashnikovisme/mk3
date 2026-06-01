module MemoryAnalysis
  module Algorithms
    # Finds addresses where the value at "idle" is bracketed between "close" and
    # "far" snapshots — matches both direct (close < idle < far) and inverted
    # (close > idle > far) encodings.  Score is proportional to the total range.
    module Bracketed
      MIN_DELTA = 8  # minimum range to suppress noise

      # dumps order: [idle, far, close]
      def self.find(dumps, top_n: 20, widths: %i[u8 u16le])
        idle_dump, far_dump, close_dump = dumps
        widths.flat_map { |w| scan(idle_dump, far_dump, close_dump, w) }
              .sort_by { |c| -c.score }
              .first(top_n)
      end

      private_class_method def self.scan(idle_dump, far_dump, close_dump, width)
        max_range = width == :u16le ? 65_535.0 : 255.0
        limit     = width == :u16le ? Dump::WRAM_SIZE - 1 : Dump::WRAM_SIZE
        results   = []

        (0...limit).each do |addr|
          v_idle  = idle_dump.send(width, addr)
          v_far   = far_dump.send(width, addr)
          v_close = close_dump.send(width, addr)

          range = [v_idle, v_far, v_close].max - [v_idle, v_far, v_close].min
          next if range < MIN_DELTA

          ordered = (v_close < v_idle && v_idle < v_far) ||
                    (v_close > v_idle && v_idle > v_far)
          next unless ordered

          score = range.to_f / max_range
          results << Candidate.new(
            address: addr,
            score:   score,
            values:  [v_idle, v_far, v_close],
            width:   width
          )
        end

        results
      end
    end
  end
end
