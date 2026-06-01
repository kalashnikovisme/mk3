require_relative "dump"
require_relative "address_verification"
require "csv"
require "fileutils"

module MemoryAnalysis
  # Scans the entire WRAM for u16le addresses whose frame series correlates
  # with a reference series (e.g. confirmed P1 X at 0x1A0A) and then runs a
  # left/right cross-validation to distinguish true P2 coordinates from
  # residual P1 mirrors.
  class P2Finder
    TOP_N              = 30
    STRUCT_OFFSETS     = [0x10, 0x20, 0x30, 0x40, 0x50, 0x60].freeze
    MIN_CORRELATION    = 0.80  # minimum |r| with reference to pass initial scan
    MIRROR_THRESHOLD   = 0.98  # auto-exclude if |r| with any known mirror ≥ this

    CrossValidation = Struct.new(
      :address,
      :corr_left,  :mono_left,  :range_left,
      :corr_right, :mono_right, :range_right,
      :antisymmetric,  # true when signs differ — hallmark of a real coordinate
      keyword_init: true
    )

    def initialize(dump_dir:, sequence:, exclude: [])
      @dump_dir = dump_dir
      @sequence = sequence
      @exclude  = exclude.to_set
    end

    # Load the u16le value series for a list of addresses from a named sequence.
    # Use this to build the mirror_series argument for #scan.
    def load_mirror_series(addresses, sequence_name = @sequence)
      dumps = load_sequence(sequence_name)
      addresses.map { |addr| dumps.map { |d| d.u16le(addr) } }
    end

    # Full-WRAM scan.
    #
    # reference_series  — frame series of the anchor address (e.g. P1 X from p1_right)
    # mirror_series     — Array of series for known P1 mirror addresses; any
    #                     address whose series correlates ≥ MIRROR_THRESHOLD with
    #                     ANY of these is automatically excluded before scoring.
    def scan(reference_series:, anchor_address:, mirror_series: [], top_n: TOP_N)
      dumps   = load_sequence(@sequence)
      results = []

      (0...(Dump::WRAM_SIZE - 1)).each do |addr|
        next if @exclude.include?(addr)
        values = dumps.map { |d| d.u16le(addr) }

        # Auto-exclude addresses that mirror any known P1 address.
        next if mirror_series.any? { |ms| pearson_series(ms, values).abs >= MIRROR_THRESHOLD }

        r = pearson_series(reference_series, values)
        next if r.abs < MIN_CORRELATION

        stats    = compute_stats(values, reference_series)
        csv_path = write_csv(addr, values)

        results << AddressVerification.new(
          address:          addr,
          category:         :p2_x_scan,
          sequence:         @sequence,
          width:            :u16le,
          values:           values,
          frame_count:      dumps.size,
          csv_path:         csv_path,
          confirmed:        stats[:monotonicity] >= 75.0 &&
                            stats[:direction_changes] <= dumps.size * 0.20,
          rejection_reason: nil,
          **stats
        )
      end

      results.sort_by { |c| -c.correlation.abs }.first(top_n)
    end

    # Cross-validate addresses against P2 moving left and then right.
    # Loads the two named sequences from @dump_dir and computes Pearson r of
    # each address against the frame index for both directions.
    #
    # A true P2 coordinate has:
    #   corr_left ≈ -corr_right  (antisymmetric: moves right when P2 walks left,
    #                              or left when P2 walks left — depends on convention)
    #
    # Returns Array<CrossValidation> sorted: antisymmetric first, then by the
    # weaker of the two |r| values (highest first).
    def cross_validate(addresses:, left_sequence:, right_sequence:)
      left_dumps  = load_sequence(left_sequence)
      right_dumps = load_sequence(right_sequence)

      addresses.map do |addr|
        lv = left_dumps.map  { |d| d.u16le(addr) }
        rv = right_dumps.map { |d| d.u16le(addr) }

        cl = pearson_with_frames(lv)
        cr = pearson_with_frames(rv)

        CrossValidation.new(
          address:       addr,
          corr_left:     cl,
          mono_left:     monotonicity(lv),
          range_left:    lv.max - lv.min,
          corr_right:    cr,
          mono_right:    monotonicity(rv),
          range_right:   rv.max - rv.min,
          antisymmetric: (cl * cr) < -0.10  # opposite signs → true coordinate
        )
      end.sort_by { |r| [r.antisymmetric ? 0 : 1, -[r.corr_left.abs, r.corr_right.abs].min] }
    end

    # Probe fixed struct offsets from anchor addresses.
    def probe_struct_offsets(anchors:)
      dumps = load_sequence(@sequence)
      anchors.each_with_object({}) do |(label, base), result|
        result[label] = STRUCT_OFFSETS.filter_map do |offset|
          addr = base + offset
          next if addr >= Dump::WRAM_SIZE - 1
          values   = dumps.map { |d| d.u16le(addr) }
          stats    = compute_stats(values, nil)
          csv_path = write_csv(addr, values)
          AddressVerification.new(
            address:          addr,
            category:         :"struct_offset_#{label}",
            sequence:         @sequence,
            width:            :u16le,
            values:           values,
            frame_count:      dumps.size,
            csv_path:         csv_path,
            confirmed:        stats[:monotonicity] >= 75.0,
            rejection_reason: nil,
            **stats
          )
        end
      end
    end

    private

    def load_sequence(name)
      dir   = File.join(@dump_dir, name)
      raise "sequence not found: #{dir}" unless Dir.exist?(dir)
      files = Dir.glob(File.join(dir, "*.bin"))
               .sort_by { |f| File.basename(f, ".bin").to_i }
      raise "no dumps in #{dir}" if files.empty?
      files.map { |f| Dump.new(f) }
    end

    def compute_stats(values, reference_series)
      deltas    = values.each_cons(2).map { |a, b| b - a }
      abs_d     = deltas.map(&:abs)
      nz_deltas = deltas.reject(&:zero?)

      avg      = abs_d.sum.to_f / [abs_d.size, 1].max
      variance = abs_d.sum { |d| (d - avg)**2 }.to_f / [abs_d.size, 1].max
      moved    = deltas.count { |d| d != 0 }
      dir_chg  = nz_deltas.each_cons(2).count { |a, b| (a > 0) != (b > 0) }

      corr_ref   = reference_series ? pearson_series(reference_series, values) : 0.0
      corr_frame = pearson_with_frames(values)

      {
        motion_rate:       (moved.to_f / [deltas.size, 1].max * 100).round(1),
        monotonicity:      monotonicity(values),
        avg_delta:         avg.round(3),
        delta_variance:    variance.round(3),
        direction_changes: dir_chg,
        unique_values:     values.uniq.size,
        min_value:         values.min || 0,
        max_value:         values.max || 0,
        correlation:       corr_ref.nonzero? ? corr_ref : corr_frame
      }
    end

    def monotonicity(values)
      deltas = values.each_cons(2).map { |a, b| b - a }
      inc = deltas.count { |d| d > 0 }
      dec = deltas.count { |d| d < 0 }
      ([inc, dec].max.to_f / [deltas.size, 1].max * 100).round(1)
    end

    def pearson_with_frames(values)
      n = values.size
      return 0.0 if n < 2
      xmean = (n - 1) / 2.0
      ymean = values.sum.to_f / n
      num   = values.each_with_index.sum { |y, x| (x - xmean) * (y - ymean) }
      dx    = Math.sqrt(values.each_index.sum { |x| (x - xmean)**2 })
      dy    = Math.sqrt(values.sum { |y| (y - ymean)**2 })
      return 0.0 if dx.zero? || dy.zero?
      (num / (dx * dy)).round(4)
    end

    def pearson_series(a, b)
      n = [a.size, b.size].min
      return 0.0 if n < 2
      am = a.sum.to_f / n
      bm = b.sum.to_f / n
      num = (0...n).sum { |i| (a[i] - am) * (b[i] - bm) }
      da  = Math.sqrt((0...n).sum { |i| (a[i] - am)**2 })
      db  = Math.sqrt((0...n).sum { |i| (b[i] - bm)**2 })
      return 0.0 if da.zero? || db.zero?
      (num / (da * db)).round(4)
    end

    def write_csv(address, values)
      dir  = File.join(@dump_dir, "verification", "p2_scan")
      FileUtils.mkdir_p(dir)
      path = File.join(dir, "0x%05X_u16le.csv" % address)
      CSV.open(path, "w") do |csv|
        csv << %w[frame value]
        values.each_with_index { |v, i| csv << [i, v] }
      end
      path
    end
  end
end
