require "csv"
require "fileutils"
require_relative "dump"
require_relative "address_verification"

module MemoryAnalysis
  class CandidateVerifier
    SEQUENCE_FOR_CATEGORY = {
      p1_x:          "p1_right",
      p2_x:          "p2_left",
      distance:      "p1_right",
      facing:        "p1_right",
      health:        "p1_right",
      timer:         "p1_right",
      explicit_u16le: "p1_right"
    }.freeze

    # u16le is the primary width for coordinate/distance categories.
    PREFERRED_WIDTH = {
      p1_x:          :u16le,
      p2_x:          :u16le,
      distance:      :u16le,
      explicit_u16le: :u16le,
      facing:        :u8,
      health:        :u8,
      timer:         :u8
    }.freeze

    DISCRETE_CATEGORIES = %i[facing].freeze

    # Position confirmation thresholds.
    MIN_MONOTONICITY     = 75.0
    MIN_AVG_DELTA        = 0.5
    MAX_DIR_CHANGE_RATIO = 0.20

    # Explicit u16le confirmation: correlation-based.
    MIN_CORRELATION      = 0.85

    # Discrete-flag confirmation thresholds.
    MAX_DISCRETE_UNIQUE  = 4
    MAX_DISCRETE_DIR     = 3

    # Mirror detection: two addresses are mirrors when their value series have
    # Pearson r ≥ this threshold.
    MIRROR_CORRELATION   = 0.98

    def initialize(dump_dir:, candidates:, explicit_u16le: [])
      @dump_dir       = dump_dir
      @candidates     = candidates
      @explicit_u16le = explicit_u16le
    end

    # Returns { category => [AddressVerification, ...] }.
    # Includes :explicit_u16le if the explicit list is non-empty.
    def verify
      result = @candidates.each_with_object({}) do |(category, addresses), h|
        cat      = category.to_sym
        seq_name = SEQUENCE_FOR_CATEGORY.fetch(cat, "p1_right")
        dumps    = load_sequence(seq_name)
        h[cat]   = addresses.map { |addr| analyse(addr, cat, seq_name, dumps) }
      rescue => e
        warn "  [skip] #{category}: #{e.message}"
        h[category.to_sym] = []
      end

      unless @explicit_u16le.empty?
        seq   = SEQUENCE_FOR_CATEGORY[:explicit_u16le]
        dumps = load_sequence(seq)
        result[:explicit_u16le] = @explicit_u16le.map do |addr|
          analyse_as(addr, :explicit_u16le, seq, :u16le, dumps)
        end
      end

      result
    end

    # Groups verifications whose value series are highly correlated.
    # Returns Array<Array<AddressVerification>>.
    def detect_mirrors(results)
      active = results.values.flatten.select { |v| v.avg_delta > 0.5 }
      used   = {}
      groups = []

      active.each do |v1|
        next if used[v1.address]
        group = [v1]
        active.each do |v2|
          next if v2.address == v1.address || used[v2.address]
          next if pearson_series(v1.values, v2.values).abs < MIRROR_CORRELATION
          group << v2
        end
        if group.size > 1
          group.sort_by! { |v| -v.correlation.abs }
          group.each { |v| used[v.address] = true }
          groups << group
        end
      end

      groups
    end

    private

    # ── Dump loading ────────────────────────────────────────────────────────────

    def load_sequence(name)
      dir = File.join(@dump_dir, name)
      raise "sequence directory not found: #{dir}" unless Dir.exist?(dir)
      files = Dir.glob(File.join(dir, "*.bin"))
               .sort_by { |f| File.basename(f, ".bin").to_i }
      raise "no .bin files in #{dir}" if files.empty?
      files.map { |f| Dump.new(f) }
    end

    # ── Per-address analysis ────────────────────────────────────────────────────

    def analyse(address, category, seq_name, dumps)
      preferred = PREFERRED_WIDTH.fetch(category, :u8)

      if preferred == :u16le
        analyse_as(address, category, seq_name, :u16le, dumps)
      else
        analyse_auto(address, category, seq_name, dumps)
      end
    end

    # Always use the given width.
    def analyse_as(address, category, seq_name, width, dumps)
      values = dumps.map { |d| d.send(width, address) }
      stats  = compute_stats(values)
      confirmed, reason = if category == :explicit_u16le
                            confirm_explicit(stats, dumps.size)
                          elsif DISCRETE_CATEGORIES.include?(category)
                            confirm_discrete(stats)
                          else
                            confirm_position(stats, dumps.size)
                          end
      csv_path = write_csv(address, category, seq_name, width, values)
      build_verification(address, category, seq_name, width, values, stats, dumps.size, csv_path, confirmed, reason)
    end

    # Auto-select u8 vs u16le by motion quality.
    def analyse_auto(address, category, seq_name, dumps)
      values_u8  = dumps.map { |d| d.u8(address) }
      values_u16 = dumps.map { |d| d.u16le(address) }
      stats_u8   = compute_stats(values_u8)
      stats_u16  = compute_stats(values_u16)

      score_u8  = stats_u8[:monotonicity]  * [stats_u8[:avg_delta]  / 10.0, 1.0].min
      score_u16 = stats_u16[:monotonicity] * [stats_u16[:avg_delta] / 10.0, 1.0].min

      if score_u16 > score_u8 * 2.0 && stats_u8[:avg_delta] < 0.3
        width, values, stats = :u16le, values_u16, stats_u16
      else
        width, values, stats = :u8,    values_u8,  stats_u8
      end

      confirmed, reason = if DISCRETE_CATEGORIES.include?(category)
                            confirm_discrete(stats)
                          else
                            confirm_position(stats, dumps.size)
                          end
      csv_path = write_csv(address, category, seq_name, width, values)
      build_verification(address, category, seq_name, width, values, stats, dumps.size, csv_path, confirmed, reason)
    end

    def build_verification(address, category, seq_name, width, values, stats, frame_count, csv_path, confirmed, reason)
      AddressVerification.new(
        address:          address,
        category:         category,
        sequence:         seq_name,
        width:            width,
        values:           values,
        frame_count:      frame_count,
        csv_path:         csv_path,
        confirmed:        confirmed,
        rejection_reason: reason,
        **stats
      )
    end

    # ── Statistics ──────────────────────────────────────────────────────────────

    def compute_stats(values)
      deltas    = values.each_cons(2).map { |a, b| b - a }
      abs_d     = deltas.map(&:abs)
      nz_deltas = deltas.reject(&:zero?)

      avg      = abs_d.sum.to_f / [abs_d.size, 1].max
      variance = abs_d.sum { |d| (d - avg)**2 }.to_f / [abs_d.size, 1].max

      moved       = deltas.count { |d| d != 0 }
      motion_rate = moved.to_f / [deltas.size, 1].max * 100

      inc          = deltas.count { |d| d > 0 }
      dec          = deltas.count { |d| d < 0 }
      monotonicity = [inc, dec].max.to_f / [deltas.size, 1].max * 100

      dir_changes = nz_deltas.each_cons(2).count { |a, b| (a > 0) != (b > 0) }

      {
        motion_rate:       motion_rate.round(1),
        monotonicity:      monotonicity.round(1),
        avg_delta:         avg.round(3),
        delta_variance:    variance.round(3),
        direction_changes: dir_changes,
        unique_values:     values.uniq.size,
        min_value:         values.min || 0,
        max_value:         values.max || 0,
        correlation:       pearson_with_frames(values)
      }
    end

    # Pearson r of values against frame index (0, 1, 2, …).
    def pearson_with_frames(values)
      n = values.size
      return 0.0 if n < 2

      xmean = (n - 1) / 2.0
      ymean = values.sum.to_f / n

      num  = values.each_with_index.sum { |y, x| (x - xmean) * (y - ymean) }
      dx   = Math.sqrt(values.each_index.sum { |x| (x - xmean)**2 })
      dy   = Math.sqrt(values.sum { |y| (y - ymean)**2 })

      return 0.0 if dx.zero? || dy.zero?
      (num / (dx * dy)).round(4)
    end

    # Pearson r between two value series (for mirror detection).
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

    # ── Confirmation ────────────────────────────────────────────────────────────

    def confirm_position(stats, frame_count)
      reasons = []
      max_dir = (frame_count * MAX_DIR_CHANGE_RATIO).ceil
      reasons << "monotonicity #{stats[:monotonicity]}% < #{MIN_MONOTONICITY}%" if stats[:monotonicity]   < MIN_MONOTONICITY
      reasons << "avg_delta #{stats[:avg_delta]} < #{MIN_AVG_DELTA}"            if stats[:avg_delta]      < MIN_AVG_DELTA
      reasons << "direction_changes #{stats[:direction_changes]} > #{max_dir}"  if stats[:direction_changes] > max_dir
      reasons.empty? ? [true, nil] : [false, reasons.join("; ")]
    end

    def confirm_explicit(stats, frame_count)
      r       = stats[:correlation].abs
      max_dir = (frame_count * MAX_DIR_CHANGE_RATIO).ceil
      reasons = []
      reasons << "correlation #{r} < #{MIN_CORRELATION}" if r < MIN_CORRELATION
      reasons << "direction_changes #{stats[:direction_changes]} > #{max_dir}" if stats[:direction_changes] > max_dir
      reasons.empty? ? [true, nil] : [false, reasons.join("; ")]
    end

    def confirm_discrete(stats)
      reasons = []
      reasons << "never changed (motion_rate=0)"                                          if stats[:motion_rate]       == 0
      reasons << "unique_values #{stats[:unique_values]} > #{MAX_DISCRETE_UNIQUE}"        if stats[:unique_values]     > MAX_DISCRETE_UNIQUE
      reasons << "direction_changes #{stats[:direction_changes]} > #{MAX_DISCRETE_DIR}"   if stats[:direction_changes] > MAX_DISCRETE_DIR
      reasons.empty? ? [true, nil] : [false, reasons.join("; ")]
    end

    # ── CSV output ──────────────────────────────────────────────────────────────

    def write_csv(address, category, sequence, width, values)
      dir  = File.join(@dump_dir, "verification", category.to_s)
      FileUtils.mkdir_p(dir)
      path = File.join(dir, "0x%05X_%s_%s.csv" % [address, sequence, width])
      CSV.open(path, "w") do |csv|
        csv << %w[frame value]
        values.each_with_index { |v, i| csv << [i, v] }
      end
      path
    end
  end
end
