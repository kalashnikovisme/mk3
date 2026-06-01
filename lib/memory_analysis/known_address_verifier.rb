require "csv"
require "fileutils"
require_relative "dump"

module MemoryAnalysis
  # Verifies published WRAM address candidates for P1 health, P2 health, and
  # the round timer by loading pre-recorded frame-dump sequences and checking
  # expected invariants.
  class KnownAddressVerifier
    P1_HEALTH_ADDR = 0x36D4
    P2_HEALTH_ADDR = 0x3898
    TIMER_ADDR     = 0x3BD4

    BASELINE_SEQ = "known/health/baseline"
    WALK_SEQ     = "known/health/walk"
    P1_HIT_SEQ   = "known/health/p1_hit"
    P2_HIT_SEQ   = "known/health/p2_hit"
    TIMER_SEQ    = "known/timer"

    HealthResult = Struct.new(
      :address, :label,
      :baseline_u8, :baseline_u16le,
      :walk_u8,
      :damage_u8, :damage_u16le,
      :baseline_stable,           # all frames have the same u8 value
      :walk_stable,               # health unchanged while walking
      :opposite_health_stable,    # other player's health unchanged during hit
      :decreased_after_damage,    # any frame in damage seq < baseline value
      :damage_delta,              # min(damage_u8) - baseline_u8.first
      :verdict, :verdict_reason,
      :csv_path,
      keyword_init: true
    )

    TimerResult = Struct.new(
      :address,
      :u8_values, :u16le_values,
      :bcd_values, :bcd_valid,
      :monotonicity, :avg_delta, :net_change, :direction_changes,
      :high_byte_zero,
      :format_guess,
      :verdict, :verdict_reason,
      :csv_path,
      keyword_init: true
    )

    def initialize(dump_dir:)
      @dump_dir = dump_dir
    end

    # Returns { p1_health: HealthResult, p2_health: HealthResult, timer: TimerResult }.
    def verify
      {
        p1_health: verify_health(P1_HEALTH_ADDR, "P1 Health", P1_HIT_SEQ, opposite_addr: P2_HEALTH_ADDR),
        p2_health: verify_health(P2_HEALTH_ADDR, "P2 Health", P2_HIT_SEQ, opposite_addr: P1_HEALTH_ADDR),
        timer:     verify_timer
      }
    end

    private

    # ── Dump loading ────────────────────────────────────────────────────────────

    def load_seq(name)
      dir   = File.join(@dump_dir, name)
      raise "sequence not found: #{dir}" unless Dir.exist?(dir)
      files = Dir.glob(File.join(dir, "*.bin"))
               .sort_by { |f| File.basename(f, ".bin").to_i }
      raise "no dumps in #{dir}" if files.empty?
      files.map { |f| Dump.new(f) }
    end

    def u8_series(dumps, addr)
      dumps.map { |d| d.u8(addr) }
    end

    def u16le_series(dumps, addr)
      dumps.map { |d| d.u16le(addr) }
    end

    # ── Health verification ─────────────────────────────────────────────────────

    def verify_health(addr, label, hit_seq_name, opposite_addr:)
      baseline_dumps = load_seq(BASELINE_SEQ)
      walk_dumps     = load_seq(WALK_SEQ)
      hit_dumps      = load_seq(hit_seq_name)

      base_u8    = u8_series(baseline_dumps, addr)
      base_u16   = u16le_series(baseline_dumps, addr)
      walk_u8    = u8_series(walk_dumps, addr)
      hit_u8     = u8_series(hit_dumps, addr)
      hit_u16    = u16le_series(hit_dumps, addr)
      opp_hit_u8 = u8_series(hit_dumps, opposite_addr)

      base_stable  = base_u8.uniq.size == 1
      walk_stable  = walk_u8.uniq.size == 1
      opp_stable   = opp_hit_u8.uniq.size == 1
      decreased    = hit_u8.any? { |v| v < base_u8.first }
      delta        = hit_u8.min - base_u8.first

      verdict, reason = health_verdict(base_stable, walk_stable, decreased, delta)
      csv_path        = write_health_csv(addr, label, base_u8, walk_u8, hit_u8)

      HealthResult.new(
        address:                addr,
        label:                  label,
        baseline_u8:            base_u8,
        baseline_u16le:         base_u16,
        walk_u8:                walk_u8,
        damage_u8:              hit_u8,
        damage_u16le:           hit_u16,
        baseline_stable:        base_stable,
        walk_stable:            walk_stable,
        opposite_health_stable: opp_stable,
        decreased_after_damage: decreased,
        damage_delta:           delta,
        verdict:                verdict,
        verdict_reason:         reason,
        csv_path:               csv_path
      )
    rescue => e
      HealthResult.new(
        address: addr, label: label, verdict: :error, verdict_reason: e.message,
        baseline_u8: [], baseline_u16le: [], walk_u8: [], damage_u8: [], damage_u16le: [],
        baseline_stable: false, walk_stable: false, opposite_health_stable: false,
        decreased_after_damage: false, damage_delta: 0, csv_path: nil
      )
    end

    def health_verdict(base_stable, walk_stable, decreased, delta)
      if !base_stable
        return [:rejected, "not stable during baseline — not a health register"]
      end
      unless walk_stable
        return [:uncertain, "changed during walking (unexpected for a health variable)"]
      end
      unless decreased
        return [:uncertain, "no decrease after punch — punch may not have connected"]
      end
      [:confirmed, "stable at rest; decreased by #{delta.abs} u8 units after damage"]
    end

    # ── Timer verification ──────────────────────────────────────────────────────

    def verify_timer
      dumps = load_seq(TIMER_SEQ)

      u8_vals    = u8_series(dumps, TIMER_ADDR)
      u16le_vals = u16le_series(dumps, TIMER_ADDR)

      bcd_vals  = u8_vals.map { |v| bcd_decode(v) }
      bcd_valid = bcd_vals.all?

      high_byte_zero = u16le_vals.all? { |v| (v >> 8).zero? }

      deltas    = u8_vals.each_cons(2).map { |a, b| b - a }
      abs_d     = deltas.map(&:abs)
      avg_delta = abs_d.sum.to_f / [abs_d.size, 1].max
      net       = u8_vals.last - u8_vals.first
      inc       = deltas.count { |d| d > 0 }
      dec       = deltas.count { |d| d < 0 }
      nz_deltas = deltas.reject(&:zero?)
      dir_changes = nz_deltas.each_cons(2).count { |a, b| (a > 0) != (b > 0) }
      mono        = ([inc, dec].max.to_f / [deltas.size, 1].max * 100).round(1)

      fmt           = guess_timer_format(u8_vals, bcd_vals, bcd_valid, avg_delta, net)
      verdict, reason = timer_verdict(avg_delta, net, dir_changes, fmt)
      csv_path      = write_timer_csv(u8_vals, u16le_vals, bcd_vals)

      TimerResult.new(
        address:           TIMER_ADDR,
        u8_values:         u8_vals,
        u16le_values:      u16le_vals,
        bcd_values:        bcd_valid ? bcd_vals : nil,
        bcd_valid:         bcd_valid,
        monotonicity:      mono,
        avg_delta:         avg_delta.round(5),
        net_change:        net,
        direction_changes: dir_changes,
        high_byte_zero:    high_byte_zero,
        format_guess:      fmt,
        verdict:           verdict,
        verdict_reason:    reason,
        csv_path:          csv_path
      )
    rescue => e
      TimerResult.new(
        address: TIMER_ADDR, verdict: :error, verdict_reason: e.message,
        u8_values: [], u16le_values: [], bcd_values: nil, bcd_valid: false,
        monotonicity: 0.0, avg_delta: 0.0, net_change: 0, direction_changes: 0,
        high_byte_zero: false, format_guess: :unknown, csv_path: nil
      )
    end

    # ── Helpers ─────────────────────────────────────────────────────────────────

    # Returns decoded decimal value if both nibbles are 0-9, nil otherwise.
    def bcd_decode(byte)
      hi = (byte >> 4) & 0xF
      lo = byte & 0xF
      return nil if hi > 9 || lo > 9
      hi * 10 + lo
    end

    def guess_timer_format(u8_vals, bcd_vals, bcd_valid, avg_delta, net)
      return :static if avg_delta < 0.001

      frames = u8_vals.size
      # Frame counter: changes nearly every frame, large total range
      return :frame_counter if avg_delta > 0.8 && net.abs > frames / 2

      # Slow countdown (display timer 99→0): net negative, small avg_delta
      if net < 0 && avg_delta < 0.1
        return bcd_valid ? :bcd_display_countdown : :u8_display_countdown
      end

      # Slow countup (elapsed timer 0→99): net positive, small avg_delta
      if net > 0 && avg_delta < 0.1
        return bcd_valid ? :bcd_elapsed_countup : :u8_elapsed_countup
      end

      :unknown
    end

    def timer_verdict(avg_delta, net, dir_changes, fmt)
      return [:rejected,  "value static — no timer activity observed"] if avg_delta < 0.001
      return [:rejected,  "net change is zero over the observation period"] if net == 0
      # Timers tick infrequently so monotonicity% is near zero; check direction changes instead.
      return [:uncertain, "changes in both directions (#{dir_changes} reversals) — inspect CSV"] if dir_changes > 3

      case fmt
      when :bcd_display_countdown
        [:confirmed, "BCD display timer counting down (e.g. 0x99 = 99 → 0x00 = 0)"]
      when :u8_display_countdown
        [:confirmed, "u8 display timer counting down (99 → 0)"]
      when :bcd_elapsed_countup
        [:confirmed, "BCD elapsed timer counting up"]
      when :u8_elapsed_countup
        [:confirmed, "u8 elapsed timer counting up (0 → 99)"]
      when :frame_counter
        [:confirmed, "frame-level counter (increments every SNES frame)"]
      else
        [:uncertain, "changes monotonically but encoding unclear — inspect CSV"]
      end
    end

    # ── CSV writers ─────────────────────────────────────────────────────────────

    def write_health_csv(addr, label, base_u8, walk_u8, hit_u8)
      dir = File.join(@dump_dir, "verification", "known")
      FileUtils.mkdir_p(dir)
      slug = label.downcase.tr(" ", "_")
      path = File.join(dir, "#{slug}_0x%05X.csv" % addr)
      CSV.open(path, "w") do |csv|
        csv << %w[phase frame u8_value]
        base_u8.each_with_index { |v, i| csv << ["baseline", i, v] }
        walk_u8.each_with_index { |v, i| csv << ["walk",     i, v] }
        hit_u8.each_with_index  { |v, i| csv << ["damage",   i, v] }
      end
      path
    end

    def write_timer_csv(u8_vals, u16le_vals, bcd_vals)
      dir = File.join(@dump_dir, "verification", "known")
      FileUtils.mkdir_p(dir)
      path = File.join(dir, "timer_0x%05X.csv" % TIMER_ADDR)
      CSV.open(path, "w") do |csv|
        csv << %w[frame u8 u16le bcd_decoded]
        u8_vals.each_with_index { |v, i| csv << [i, v, u16le_vals[i], bcd_vals&.at(i)] }
      end
      path
    end
  end
end
