module MemoryAnalysis
  module ReportPrinter
    HEADERS = {
      p1_x:     "P1 X POSITION       (dumps: idle, r1..r5 — expect increasing)",
      p2_x:     "P2 X POSITION       (dumps: idle, l1..l5 — expect decreasing or increasing)",
      distance: "DISTANCE            (dumps: idle, far, close — expect bracketed)",
      facing:   "FACING DIRECTION    (dumps: before_cross, after_cross — expect binary toggle)",
      health:   "HEALTH              (dumps: full, damaged — expect decrease)",
      timer:    "ROUND TIMER         (dumps: t99, t98, t97 — expect step of −1)"
    }.freeze

    DUMP_LABELS = {
      p1_x:     %w[idle r1   r2   r3   r4   r5],
      p2_x:     %w[idle l1   l2   l3   l4   l5],
      distance: %w[idle far  close],
      facing:   %w[before after],
      health:   %w[full   dmgd],
      timer:    %w[t99    t98   t97]
    }.freeze

    def self.print(report, output: $stdout)
      report.each do |category, candidates|
        labels = DUMP_LABELS.fetch(category)
        header = HEADERS.fetch(category)

        output.puts "\n#{"─" * 70}"
        output.puts "  #{header}"
        output.puts "─" * 70

        if candidates.empty?
          output.puts "  (no candidates found)"
          next
        end

        val_header = labels.map { |l| l.rjust(6) }.join
        output.printf "  %-8s  %-6s  %-5s  %s\n", "ADDRESS", "SCORE", "WIDTH", val_header
        output.puts "  " + "─" * 66

        candidates.each do |c|
          val_cols = c.values.map { |v| v.to_s.rjust(6) }.join
          output.printf "  0x%05X   %5.3f  %-5s  %s\n",
                        c.address, c.score, c.width, val_cols
        end
      end

      output.puts "\n#{"─" * 70}"
      output.puts "  Done. Confirm candidates with a watch expression in the scenario."
      output.puts "─" * 70
    end
  end
end
