module MemoryAnalysis
  module VerificationPrinter
    CATEGORY_LABEL = {
      p1_x:          "P1 X POSITION",
      p2_x:          "P2 X POSITION",
      distance:      "DISTANCE",
      facing:        "FACING DIRECTION",
      health:        "HEALTH",
      timer:         "ROUND TIMER",
      explicit_u16le: "EXPLICIT u16le VERIFICATION"
    }.freeze

    SAMPLE_COUNT = 20  # how many values to show at the head/tail of each series

    def self.print(results, mirror_groups: [], output: $stdout)
      confirmed_by_category = {}

      results.each do |category, verifications|
        next if verifications.empty?

        label    = CATEGORY_LABEL.fetch(category, category.to_s.upcase)
        sequence = verifications.first&.sequence || "?"
        frames   = verifications.first&.frame_count || 0

        output.puts "\n#{"═" * 72}"
        output.puts "  #{label}  (sequence: #{sequence}, #{frames} frames)"
        output.puts "═" * 72

        verifications.each { |v| print_verification(v, output) }

        confirmed = verifications.select(&:confirmed)
        confirmed_by_category[category] = confirmed if confirmed.any?
      end

      # ── Mirror groups ─────────────────────────────────────────────────────────

      unless mirror_groups.empty?
        output.puts "\n#{"═" * 72}"
        output.puts "  MIRROR GROUPS  (Pearson r ≥ #{CandidateVerifier::MIRROR_CORRELATION})"
        output.puts "═" * 72

        mirror_groups.each_with_index do |group, i|
          output.puts "\n  Group #{i + 1}  (#{group.size} addresses):"
          canonical = group.first
          group.each_with_index do |v, j|
            tag = j == 0 ? "← highest |correlation| with frame" : ""
            mean_delta = group.size > 1 ?
              (v.values.zip(canonical.values).sum { |a, b| a - b }.to_f / v.frame_count).round(1) :
              0
            offset_str = j == 0 ? "" : "  (mean offset from canonical: #{mean_delta > 0 ? '+' : ''}#{mean_delta})"
            output.printf "    0x%05X  %s  corr=%+.4f  avg_delta=%.3f%s  %s\n",
                          v.address, v.width, v.correlation, v.avg_delta, offset_str, tag
          end
        end
      end

      # ── Summary ───────────────────────────────────────────────────────────────

      output.puts "\n#{"═" * 72}"

      if confirmed_by_category.empty?
        output.puts "  No candidates confirmed."
      else
        confirmed_by_category.each do |category, verifications|
          label = CATEGORY_LABEL.fetch(category, category.to_s.upcase)
          output.puts "\n  CONFIRMED #{label}:"
          verifications.each do |v|
            output.printf "    0x%05X  (%s, avg_delta=%.3f, monotonicity=%.1f%%, correlation=%+.4f)\n",
                          v.address, v.width, v.avg_delta, v.monotonicity, v.correlation
          end
        end
      end

      output.puts "\n#{"═" * 72}"
    end

    private_class_method def self.print_verification(v, output)
      output.puts "\n  0x%05X  %s" % [v.address, v.width]
      output.printf "    motion_rate:       %5.1f%%    monotonicity:    %5.1f%%\n",
                    v.motion_rate, v.monotonicity
      output.printf "    avg_delta:       %8.3f    direction_changes:  %3d\n",
                    v.avg_delta, v.direction_changes
      output.printf "    delta_variance:  %8.3f    unique_values:      %3d\n",
                    v.delta_variance, v.unique_values
      output.printf "    min: %-8d  max: %-8d  range: %d\n",
                    v.min_value, v.max_value, v.max_value - v.min_value
      output.printf "    correlation with frame: %+.4f\n", v.correlation

      first_n = v.values.first(SAMPLE_COUNT)
      last_n  = v.values.last(SAMPLE_COUNT)
      output.puts  "    first #{SAMPLE_COUNT}: [#{first_n.join(', ')}]"
      output.puts  "    last  #{SAMPLE_COUNT}: [#{last_n.join(', ')}]"
      output.puts  "    CSV: #{v.csv_path}"

      if v.confirmed
        output.puts "    ✓ CONFIRMED"
      else
        output.puts "    ✗ REJECTED  (#{v.rejection_reason})"
      end
    end
  end
end
