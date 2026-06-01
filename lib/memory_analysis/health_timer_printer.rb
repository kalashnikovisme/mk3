module MemoryAnalysis
  module HealthTimerPrinter
    SAMPLE_N     = 20
    FIGHT_SCREENS = (0x00..0x09).freeze

    SCREEN_NAMES = {
      0x00 => "Rooftop", 0x01 => "Jade's Desert", 0x02 => "Scorpion's Lair",
      0x03 => "Kahn's Kave", 0x04 => "Waterfront", 0x05 => "The Portal",
      0x06 => "Pit III", 0x09 => "Pit III"
    }.freeze

    def self.print(report, output: $stdout)
      print_sanity(report[:sanity], output)
      print_health(report[:p1_health], "P1 HEALTH CANDIDATES", output)
      print_health(report[:p2_health], "P2 HEALTH CANDIDATES", output)
      print_timer(report[:timer], output)
      print_summary(report, output)
    end

    # ── Sanity check ───────────────────────────────────────────────────────────

    private_class_method def self.print_sanity(s, output)
      output.puts "\n#{"═" * 70}"
      output.puts "  SCENARIO SANITY CHECK"
      output.puts "#{"═" * 70}"

      screen_name = SCREEN_NAMES.fetch(s.screen_value, "unknown")
      output.printf "  Screen   0x%02X  %-20s  %s\n",
                    s.screen_value, "(#{screen_name})",
                    s.in_fight ? "✓ fight screen" : "✗ NOT a fight screen"
      output.printf "  P1 X     0x1A0A  %-6d u16le    %s\n",
                    s.p1_x_value,
                    s.p1_x_nonzero ? "✓ non-zero" : "✗ ZERO — fighters may not be active"
      output.printf "  P1 health 0x3634  %-6d u8       %s\n",
                    s.p1_health_value,
                    s.p1_health_plausible ? "✓ plausible" : "? outside 50..166"

      if s.passed
        output.puts "\n  → SANITY PASSED — fight state confirmed, scan results are meaningful."
      else
        output.puts "\n  → SANITY FAILED — results may be meaningless."
        s.notes.each { |n| output.puts "    ✗ #{n}" }
        output.puts "    Check that data/matches/*.state is an active fight mid-round."
      end
    end

    # ── Health section ─────────────────────────────────────────────────────────

    private_class_method def self.print_health(candidates, title, output)
      output.puts "\n#{"═" * 70}"
      output.puts "  #{title}"
      output.puts "  Stable at rest · decreases after damage · cross-check stable"
      output.puts "#{"═" * 70}"

      if candidates.empty?
        output.puts "  No candidates found."
        output.puts "  — Sanity check may have failed, or punch did not connect."
        return
      end

      output.printf "  %-4s %-8s %-5s %-6s %-8s %-6s %-10s %-6s %s\n",
                    "#", "ADDRESS", "WIDTH", "IDLE", "MIN_HIT", "DELTA",
                    "SUSTAINED", "CROSS", "SCORE"
      output.puts "  " + "─" * 66

      candidates.each_with_index do |c, i|
        output.printf "  %-4d 0x%05X  %-5s %-6d %-8d %-6d %-10s %-6s %.4f\n",
                      i + 1, c.address, c.width, c.idle_value, c.min_hit_value,
                      c.delta, "#{c.sustained_pct}%",
                      c.cross_stable ? "YES" : "no",
                      c.score
      end

      top = candidates.first
      output.puts "\n  Top candidate — 0x%05X %s:" % [top.address, top.width]
      output.puts "    idle=#{top.idle_value}  min_hit=#{top.min_hit_value}  delta=#{top.delta}  sustained=#{top.sustained_pct}%"
      show_samples("idle",   top.idle_values, output)
      show_samples("damage", top.hit_values,  output)
      output.puts "    CSV: #{top.csv_path}"
    end

    # ── Timer section ──────────────────────────────────────────────────────────

    private_class_method def self.print_timer(candidates, output)
      output.puts "\n#{"═" * 70}"
      output.puts "  TIMER CANDIDATES"
      output.puts "  Monotonic change · periodic ticks · BCD or integer encoding"
      output.puts "#{"═" * 70}"

      if candidates.empty?
        output.puts "  No timer candidates found."
        return
      end

      output.printf "  %-4s %-8s %-5s %-7s %-6s %-5s %-7s %-4s %s\n",
                    "#", "ADDRESS", "WIDTH", "UNIQUE", "NET", "DIR_Δ",
                    "TICKS", "BCD", "SCORE"
      output.puts "  " + "─" * 66

      candidates.each_with_index do |c, i|
        output.printf "  %-4d 0x%05X  %-5s %-7d %-6d %-5d %-7d %-4s %.4f\n",
                      i + 1, c.address, c.width, c.unique_count, c.net_change,
                      c.direction_changes, c.tick_count,
                      c.bcd_valid ? "YES" : "no",
                      c.score
      end

      top = candidates.first
      output.puts "\n  Top candidate — 0x%05X %s:" % [top.address, top.width]
      output.puts "    unique=#{top.unique_count}  net=#{top.net_change}  dir_changes=#{top.direction_changes}"
      output.puts "    ticks=#{top.tick_count}  avg_period=#{top.avg_frames_per_tick} frames/tick"
      output.puts "    BCD valid: #{top.bcd_valid}"
      if top.bcd_valid && top.bcd_values
        show_samples("BCD", top.bcd_values, output)
      end
      show_samples("u8/u16", top.values, output)
      output.puts "    CSV: #{top.csv_path}"
    end

    # ── Summary ────────────────────────────────────────────────────────────────

    private_class_method def self.print_summary(report, output)
      output.puts "\n#{"═" * 70}"
      output.puts "  SUMMARY"
      output.puts "#{"═" * 70}"

      sanity_ok = report[:sanity]&.passed
      output.puts "  Sanity: #{sanity_ok ? '✓ PASSED' : '✗ FAILED'}"

      [[:p1_health, "P1 health"], [:p2_health, "P2 health"], [:timer, "Timer"]].each do |key, label|
        list = report[key] || []
        top  = list.first
        if top
          output.printf "  %-10s top candidate: 0x%05X %s  score=%.4f  delta=%s\n",
                        "#{label}:", top.address, top.width, top.score,
                        top.respond_to?(:delta) ? top.delta.to_s : top.net_change.to_s
        else
          output.printf "  %-10s no candidates found\n", "#{label}:"
        end
      end

      output.puts "#{"═" * 70}\n"
    end

    private_class_method def self.show_samples(label, values, output)
      n     = [SAMPLE_N, values.size].min
      first = values.first(n).join(", ")
      last  = values.last(n).join(", ")
      output.puts "    first #{n} #{label}: [#{first}]"
      output.puts "    last  #{n} #{label}: [#{last}]" if values.size > n
    end
  end
end
