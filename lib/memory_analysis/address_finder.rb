require_relative "dump"
require_relative "candidate"
require_relative "algorithms/monotonic"
require_relative "algorithms/bracketed"
require_relative "algorithms/binary_transition"
require_relative "algorithms/decreasing"
require_relative "algorithms/stepped"

module MemoryAnalysis
  class AddressFinder
    TOP_N = 20

    # Subdirectory name → ordered dump file basenames (without .bin)
    DUMP_NAMES = {
      p1_x:     %w[idle r1 r2 r3 r4 r5],
      p2_x:     %w[idle l1 l2 l3 l4 l5],
      distance: %w[idle far close],
      facing:   %w[before_cross after_cross],
      health:   %w[full damaged],
      timer:    %w[t99 t98 t97]
    }.freeze

    def initialize(dump_dir:)
      @dump_dir = dump_dir
    end

    def find_p1_x
      Algorithms::Monotonic.find(load(:p1_x), direction: :increasing, top_n: TOP_N, widths: [:u16le])
    end

    def find_p2_x
      dumps = load(:p2_x)
      dec   = Algorithms::Monotonic.find(dumps, direction: :decreasing, top_n: TOP_N, widths: [:u16le])
      inc   = Algorithms::Monotonic.find(dumps, direction: :increasing, top_n: TOP_N, widths: [:u16le])
      merge(dec, inc)
    end

    def find_distance
      Algorithms::Bracketed.find(load(:distance), top_n: TOP_N, widths: [:u16le])
    end

    def find_facing
      Algorithms::BinaryTransition.find(load(:facing), top_n: TOP_N)
    end

    def find_health
      Algorithms::Decreasing.find(load(:health), top_n: TOP_N)
    end

    def find_timer
      Algorithms::Stepped.find(load(:timer), expected: [99, 98, 97], top_n: TOP_N)
    end

    def report
      DUMP_NAMES.keys.each_with_object({}) do |category, result|
        result[category] = public_send(:"find_#{category}")
      rescue => e
        warn "  [skip] #{category}: #{e.message}"
        result[category] = []
      end
    end

    private

    def load(category)
      dir   = File.join(@dump_dir, category.to_s)
      names = DUMP_NAMES.fetch(category)
      missing = names.reject { |n| File.exist?(File.join(dir, "#{n}.bin")) }
      raise "missing dumps in #{dir}: #{missing.join(', ')}" if missing.any?
      names.map { |name| Dump.new(File.join(dir, "#{name}.bin")) }
    end

    def merge(*lists)
      lists.flatten.sort_by { |c| -c.score }.first(TOP_N)
    end
  end
end
