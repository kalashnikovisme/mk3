module MemoryAnalysis
  module KnownAddressPrinter
    SAMPLE_N   = 15
    VERDICT_ICON = { confirmed: "✓", rejected: "✗", uncertain: "?", error: "!" }.freeze

    def self.print(results, output: $stdout)
      output.puts "\n#{"═" * 66}"
      output.puts "  KNOWN ADDRESS VERIFICATION"
      output.puts "#{"═" * 66}"

      print_health(results[:p1_health], "P1 HEALTH", output) if results[:p1_health]
      print_health(results[:p2_health], "P2 HEALTH", output) if results[:p2_health]
      print_timer(results[:timer], output)                    if results[:timer]

      print_summary(results, output)
    end

    # ── Health section ──────────────────────────────────────────────────────────

    private_class_method def self.print_health(r, title, output)
      output.puts "\n── #{title}  ──────────────────────────────────────────────────"
      output.puts "  address:           0x%05X" % r.address
      output.puts "  format candidates: u8  ·  u16le"

      output.puts "\n  baseline (#{r.baseline_u8.size} idle frames):"
      output.printf "    u8    mean=%-4d  range=%d..%d  stable=%s\n",
                    mean(r.baseline_u8), r.baseline_u8.min || 0, r.baseline_u8.max || 0,
                    bool_str(r.baseline_stable)
      output.printf "    u16le first=%-6d  last=%d\n",
                    r.baseline_u16le.first || 0, r.baseline_u16le.last || 0
      unless r.baseline_u8.empty?
        output.puts "    first #{[SAMPLE_N, r.baseline_u8.size].min}: [#{r.baseline_u8.first(SAMPLE_N).join(', ')}]"
      end

      output.puts "\n  idle stability (#{r.walk_u8.size} frames: P1 walks right+left):"
      output.printf "    u8    mean=%-4d  range=%d..%d  stable=%s\n",
                    mean(r.walk_u8), r.walk_u8.min || 0, r.walk_u8.max || 0,
                    bool_str(r.walk_stable)

      output.puts "\n  after damage (#{r.damage_u8.size} frames post-punch):"
      output.printf "    u8    first=%-4d  min=%-4d  delta=%+d  decreased=%s\n",
                    r.damage_u8.first || 0, r.damage_u8.min || 0,
                    r.damage_delta, bool_str(r.decreased_after_damage)
      output.printf "    u16le first=%-6d  min=%d\n",
                    r.damage_u16le.first || 0, r.damage_u16le.min || 0
      unless r.damage_u8.empty?
        output.puts "    first #{[SAMPLE_N, r.damage_u8.size].min}: [#{r.damage_u8.first(SAMPLE_N).join(', ')}]"
        output.puts "    last  #{[SAMPLE_N, r.damage_u8.size].min}: [#{r.damage_u8.last(SAMPLE_N).join(', ')}]"
      end

      output.puts "    opposite player health stable: #{bool_str(r.opposite_health_stable)}"

      output.puts "\n  CSV: #{r.csv_path}"

      icon = VERDICT_ICON.fetch(r.verdict, "?")
      output.puts "\n  verdict: #{icon} #{r.verdict.to_s.upcase}"
      output.puts "           #{r.verdict_reason}"
    end

    # ── Timer section ───────────────────────────────────────────────────────────

    private_class_method def self.print_timer(r, output)
      output.puts "\n── ROUND TIMER  ───────────────────────────────────────────────"
      output.puts "  address:           0x%05X" % r.address
      output.puts "  format candidates: u8  ·  u16le  ·  BCD  ·  frame-counter"
      output.puts "  frames observed:   #{r.u8_values.size}"

      output.puts "\n  first values:"
      unless r.u8_values.empty?
        output.puts "    u8    first #{[SAMPLE_N, r.u8_values.size].min}: [#{r.u8_values.first(SAMPLE_N).join(', ')}]"
        output.puts "    u16le first #{[SAMPLE_N, r.u16le_values.size].min}: [#{r.u16le_values.first(SAMPLE_N).join(', ')}]"
        output.puts "    BCD   first #{[SAMPLE_N, (r.bcd_values&.size || 0)].min}: [#{(r.bcd_values || []).first(SAMPLE_N).join(', ')}]" if r.bcd_valid
      end

      output.puts "\n  last values:"
      unless r.u8_values.empty?
        output.puts "    u8    last #{[SAMPLE_N, r.u8_values.size].min}: [#{r.u8_values.last(SAMPLE_N).join(', ')}]"
        output.puts "    BCD   last #{[SAMPLE_N, (r.bcd_values&.size || 0)].min}: [#{(r.bcd_values || []).last(SAMPLE_N).join(', ')}]" if r.bcd_valid
      end

      output.puts "\n  statistics:"
      output.printf "    u8    first=%-4d  last=%-4d  net_change=%+d\n",
                    r.u8_values.first || 0, r.u8_values.last || 0, r.net_change
      output.printf "    u16le high_byte_always_zero: %s\n", bool_str(r.high_byte_zero)
      output.printf "    BCD   valid: %s\n", bool_str(r.bcd_valid)
      if r.bcd_valid && r.bcd_values
        output.printf "    BCD   first=%-4d  last=%-4d  net=%+d\n",
                      r.bcd_values.first || 0, r.bcd_values.last || 0,
                      (r.bcd_values.last || 0) - (r.bcd_values.first || 0)
      end
      output.printf "    monotonicity:  %s%%  (low values are normal for slow timers)\n", r.monotonicity
      output.printf "    direction_changes: %d  (0 = purely monotonic)\n", r.direction_changes
      output.printf "    avg_delta:     %s  (per snapshot)\n", r.avg_delta

      output.puts "\n  format analysis:"
      format_label = {
        u8_display_countdown:  "u8 display timer  (counts down: 99 → 0)",
        bcd_display_countdown: "BCD display timer (counts down: 0x99 → 0x00)",
        u8_elapsed_countup:    "u8 elapsed timer  (counts up: 0 → 99)",
        bcd_elapsed_countup:   "BCD elapsed timer (counts up)",
        frame_counter:         "frame counter     (increments every SNES frame)",
        static:                "static            (no change observed)",
        unknown:               "unknown           (inspect CSV for patterns)"
      }
      output.printf "    best guess: %s\n", format_label.fetch(r.format_guess, r.format_guess.to_s)

      output.puts "\n  CSV: #{r.csv_path}"

      icon = VERDICT_ICON.fetch(r.verdict, "?")
      output.puts "\n  verdict: #{icon} #{r.verdict.to_s.upcase}"
      output.puts "           #{r.verdict_reason}"
    end

    # ── Summary ─────────────────────────────────────────────────────────────────

    private_class_method def self.print_summary(results, output)
      output.puts "\n#{"═" * 66}"
      output.puts "  SUMMARY"
      output.puts "#{"═" * 66}"

      labels = {
        p1_health: "P1 Health  0x36D4",
        p2_health: "P2 Health  0x3898",
        timer:     "Timer      0x3BD4"
      }

      results.each do |key, r|
        next unless r
        icon    = VERDICT_ICON.fetch(r.verdict, "?")
        verdict = r.verdict.to_s.upcase
        output.printf "  %-22s  %s %-12s  %s\n",
                      labels.fetch(key, key.to_s),
                      icon, verdict,
                      r.verdict_reason
      end

      output.puts "#{"═" * 66}"
      output.puts ""
    end

    private_class_method def self.mean(values)
      return 0 if values.empty?
      (values.sum.to_f / values.size).round(1)
    end

    private_class_method def self.bool_str(val)
      val ? "YES" : "NO"
    end
  end
end
