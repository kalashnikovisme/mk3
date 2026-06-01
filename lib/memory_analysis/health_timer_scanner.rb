require "csv"
require "fileutils"

module MemoryAnalysis
  # Scans the entire WRAM to discover health and timer addresses from actual
  # in-game state changes — no prior address knowledge required.
  #
  # Uses RawDump (binary String, 128 KB/dump) instead of the standard Dump
  # (integer Array, ~1 MB/dump) so bulk-loading hundreds of dumps stays within
  # reasonable memory limits (~120 MB for 960 dumps).
  class HealthTimerScanner
    TOP_N = 20

    WRAM_SIZE          = 131_072
    FIGHT_SCREENS      = (0x00..0x09).freeze
    CONFIRMED_SCREEN   = 0x3A7E  # MK3 confirmed
    CONFIRMED_P1_X     = 0x1A0A  # u16le, confirmed
    CONFIRMED_P1_HEALTH = 0x3634 # u8, confirmed

    # ── Lightweight dump wrapper ──────────────────────────────────────────────

    class RawDump
      def initialize(path)
        data = File.binread(path)
        raise "#{path}: expected #{WRAM_SIZE} bytes, got #{data.bytesize}" \
          unless data.bytesize == WRAM_SIZE
        @data = data
      end

      def u8(addr)    = @data.getbyte(addr) || 0
      def u16le(addr) = (@data.getbyte(addr) || 0) | ((@data.getbyte(addr + 1) || 0) << 8)
    end

    # ── Result structs ────────────────────────────────────────────────────────

    SanityCheck = Struct.new(
      :screen_value, :in_fight,
      :p1_x_value,   :p1_x_nonzero,
      :p1_health_value, :p1_health_plausible,
      :passed, :notes,
      keyword_init: true
    )

    HealthCandidate = Struct.new(
      :address, :width,
      :idle_value,
      :idle_values, :hit_values,
      :min_hit_value, :delta,
      :sustained_pct,
      :cross_stable,
      :score, :csv_path,
      keyword_init: true
    )

    TimerCandidate = Struct.new(
      :address, :width,
      :values,
      :unique_count,
      :net_change, :direction_changes, :tick_count,
      :avg_frames_per_tick,
      :bcd_valid, :bcd_values,
      :score, :csv_path,
      keyword_init: true
    )

    # ── Public interface ──────────────────────────────────────────────────────

    def initialize(dump_dir:)
      @dump_dir = dump_dir
    end

    # Checks the first idle dump against known confirmed addresses to verify
    # we were actually in a fight when the scenario ran.
    def sanity_check
      dump  = load_first("scan/health/p1_dmg/idle")
      screen = dump.u8(CONFIRMED_SCREEN)
      p1_x   = dump.u16le(CONFIRMED_P1_X)
      p1_h   = dump.u8(CONFIRMED_P1_HEALTH)

      in_fight  = FIGHT_SCREENS.include?(screen)
      x_nonzero = p1_x > 0
      h_ok      = p1_h.between?(50, 166)
      passed    = in_fight && x_nonzero

      notes = []
      notes << "screen 0x#{screen.to_s(16).rjust(2, '0')} is not a fight screen — likely in menu/char-select" unless in_fight
      notes << "P1 X is zero — fighters may not be initialised" unless x_nonzero
      notes << "P1 health #{p1_h} is outside expected range" unless h_ok

      SanityCheck.new(
        screen_value:        screen,
        in_fight:            in_fight,
        p1_x_value:          p1_x,
        p1_x_nonzero:        x_nonzero,
        p1_health_value:     p1_h,
        p1_health_plausible: h_ok,
        passed:              passed,
        notes:               notes
      )
    rescue => e
      SanityCheck.new(
        passed: false, notes: ["cannot load idle dump: #{e.message}"],
        screen_value: 0, in_fight: false,
        p1_x_value: 0, p1_x_nonzero: false,
        p1_health_value: 0, p1_health_plausible: false
      )
    end

    # Scan for P1 health: looks for addresses stable at rest that decrease
    # when P2 attacks P1, but stay constant when P1 attacks P2.
    def scan_p1_health
      scan_health(
        primary_idle: "scan/health/p1_dmg/idle",
        primary_hit:  "scan/health/p1_dmg/hit",
        cross_idle:   "scan/health/p2_dmg/idle",
        cross_hit:    "scan/health/p2_dmg/hit",
        label:        "p1_health"
      )
    end

    # Scan for P2 health: same logic but with sequences swapped.
    def scan_p2_health
      scan_health(
        primary_idle: "scan/health/p2_dmg/idle",
        primary_hit:  "scan/health/p2_dmg/hit",
        cross_idle:   "scan/health/p1_dmg/idle",
        cross_hit:    "scan/health/p1_dmg/hit",
        label:        "p2_health"
      )
    end

    # Scan all WRAM for addresses that change monotonically over 600 frames,
    # consistent with a display timer, elapsed timer, or frame counter.
    def scan_timer
      dumps = load_seq("scan/timer")
      results = []

      [:u8, :u16le].each do |width|
        limit = width == :u16le ? WRAM_SIZE - 1 : WRAM_SIZE

        (0...limit).each do |addr|
          first_val = dumps.first.send(width, addr)
          last_val  = dumps.last.send(width, addr)
          next if first_val == last_val   # static

          net = last_val - first_val
          next if net.abs < 3             # trivial change

          values    = dumps.map { |d| d.send(width, addr) }
          deltas    = values.each_cons(2).map { |a, b| b - a }
          nz_deltas = deltas.reject(&:zero?)
          next if nz_deltas.empty?

          dir_changes = nz_deltas.each_cons(2).count { |a, b| (a > 0) != (b > 0) }
          tick_count  = nz_deltas.size
          avg_period  = (dumps.size.to_f / tick_count).round(2)
          avg_delta   = nz_deltas.map(&:abs).sum.to_f / tick_count

          # Score: reward monotonicity, penalise reversals
          score = case dir_changes
                  when 0    then 1.0
                  when 1..2 then 0.7
                  when 3..5 then 0.4
                  else           0.1
                  end
          # Bonus for reasonable step size (timers tick in small steps)
          score *= 1.2 if avg_delta.between?(0.5, 5.0)
          score  = [score, 1.0].min

          bcd_vals  = width == :u8 ? values.map { |v| bcd_decode(v) } : nil
          bcd_valid = bcd_vals&.all?

          csv_path = write_timer_csv(addr, width, values)

          results << TimerCandidate.new(
            address:            addr,
            width:              width,
            values:             values,
            unique_count:       values.uniq.size,
            net_change:         net,
            direction_changes:  dir_changes,
            tick_count:         tick_count,
            avg_frames_per_tick: avg_period,
            bcd_valid:          bcd_valid,
            bcd_values:         bcd_valid ? bcd_vals : nil,
            score:              score.round(4),
            csv_path:           csv_path
          )
        end
      end

      results.sort_by { |c| -c.score }.first(TOP_N)
    end

    def report
      {
        sanity:    sanity_check,
        p1_health: scan_p1_health,
        p2_health: scan_p2_health,
        timer:     scan_timer
      }
    end

    private

    # ── Health scan core ──────────────────────────────────────────────────────

    def scan_health(primary_idle:, primary_hit:, cross_idle:, cross_hit:, label:)
      idle_dumps  = load_seq(primary_idle)
      hit_dumps   = load_seq(primary_hit)
      x_idle      = load_seq(cross_idle)
      x_hit       = load_seq(cross_hit)

      results = []

      [:u8, :u16le].each do |width|
        limit   = width == :u16le ? WRAM_SIZE - 1 : WRAM_SIZE
        max_val = width == :u16le ? 65_535 : 255

        (0...limit).each do |addr|
          # Fast-path 1: skip zeros
          idle_first = idle_dumps.first.send(width, addr)
          next if idle_first.zero?

          # Fast-path 2: reasonable health range
          next unless idle_first.between?(30, max_val)

          # Fast-path 3: all idle frames must be identical (health is stable at rest)
          next unless idle_dumps.all? { |d| d.send(width, addr) == idle_first }

          # Fast-path 4: at least one hit frame is lower
          next unless hit_dumps.any? { |d| d.send(width, addr) < idle_first }

          # Full analysis
          hit_vals  = hit_dumps.map { |d| d.send(width, addr) }
          idle_vals = idle_dumps.map { |d| d.send(width, addr) }

          min_hit   = hit_vals.min
          delta     = min_hit - idle_first
          sustained = hit_vals.count { |v| v < idle_first }.to_f / hit_vals.size

          # Cross-check: this address should NOT change in the other player's hit sequence
          x_idle_val = x_idle.first.send(width, addr)
          x_stable   = x_idle.all? { |d| d.send(width, addr) == x_idle_val } &&
                       x_hit.none?  { |d| d.send(width, addr) < x_idle_val }

          # Score: weighted product of stability, delta magnitude, and sustained drop
          delta_frac = delta.abs.to_f / idle_first
          score      = delta_frac * sustained * (x_stable ? 1.5 : 1.0)
          score      = [score, 1.0].min

          next if score < 0.05

          csv_path = write_health_csv(addr, width, label, idle_vals, hit_vals)

          results << HealthCandidate.new(
            address:       addr,
            width:         width,
            idle_value:    idle_first,
            idle_values:   idle_vals,
            hit_values:    hit_vals,
            min_hit_value: min_hit,
            delta:         delta,
            sustained_pct: (sustained * 100).round(1),
            cross_stable:  x_stable,
            score:         score.round(4),
            csv_path:      csv_path
          )
        end
      end

      results.sort_by { |c| -c.score }.first(TOP_N)
    end

    # ── Dump loading ──────────────────────────────────────────────────────────

    def load_seq(name)
      dir   = File.join(@dump_dir, name)
      raise "sequence not found: #{dir}" unless Dir.exist?(dir)
      files = Dir.glob(File.join(dir, "*.bin"))
               .sort_by { |f| File.basename(f, ".bin").to_i }
      raise "no dumps in #{dir}" if files.empty?
      files.map { |f| RawDump.new(f) }
    end

    def load_first(name)
      dir  = File.join(@dump_dir, name)
      raise "sequence not found: #{dir}" unless Dir.exist?(dir)
      file = Dir.glob(File.join(dir, "*.bin"))
              .sort_by { |f| File.basename(f, ".bin").to_i }
              .first
      raise "no dumps in #{dir}" unless file
      RawDump.new(file)
    end

    # ── BCD helper ────────────────────────────────────────────────────────────

    def bcd_decode(byte)
      hi = (byte >> 4) & 0xF
      lo = byte & 0xF
      return nil if hi > 9 || lo > 9
      hi * 10 + lo
    end

    # ── CSV writers ───────────────────────────────────────────────────────────

    def write_health_csv(addr, width, label, idle_vals, hit_vals)
      dir  = File.join(@dump_dir, "verification", "scan")
      FileUtils.mkdir_p(dir)
      path = File.join(dir, "#{label}_0x%05X_#{width}.csv" % addr)
      CSV.open(path, "w") do |csv|
        csv << %w[phase frame value]
        idle_vals.each_with_index { |v, i| csv << ["idle",   i, v] }
        hit_vals.each_with_index  { |v, i| csv << ["damage", i, v] }
      end
      path
    end

    def write_timer_csv(addr, width, values)
      dir  = File.join(@dump_dir, "verification", "scan")
      FileUtils.mkdir_p(dir)
      path = File.join(dir, "timer_0x%05X_#{width}.csv" % addr)
      CSV.open(path, "w") do |csv|
        csv << %w[frame value]
        values.each_with_index { |v, i| csv << [i, v] }
      end
      path
    end
  end
end
