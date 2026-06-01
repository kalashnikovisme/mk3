module MemoryAnalysis
  module P2ScanPrinter
    SAMPLE_N = 20

    def self.print(scan_results, struct_results, cross_validation: [],
                   reference_addr:, output: $stdout)
      print_scan(scan_results, reference_addr, output)
      print_structs(struct_results, output)   unless struct_results.empty?
      print_cross_validation(cross_validation, output) unless cross_validation.empty?
      print_top_confirmed(scan_results, output)
    end

    private_class_method def self.print_scan(results, reference_addr, output)
      output.puts "\n#{"═" * 72}"
      output.puts "  P2 X COORDINATE SCAN  (correlation against 0x%05X)" % reference_addr
      output.puts "  Ranked by |Pearson r| — P1 mirror family auto-excluded"
      output.puts "═" * 72

      if results.empty?
        output.puts "  No candidates above correlation threshold."
        return
      end

      output.printf "  %-8s  %-7s  %-6s  %-8s  %-5s  %-5s  %s\n",
                    "ADDRESS", "CORR", "MONO%", "AVG_Δ", "DIR_Δ", "CONF", "RANGE"
      output.puts "  " + "─" * 68
      results.each do |v|
        conf = v.confirmed ? "✓" : "✗"
        output.printf "  0x%05X  %+.4f  %5.1f%%  %8.3f  %5d  %-5s  %d..%d\n",
                      v.address, v.correlation, v.monotonicity,
                      v.avg_delta, v.direction_changes, conf,
                      v.min_value, v.max_value
      end
    end

    private_class_method def self.print_structs(struct_results, output)
      output.puts "\n#{"═" * 72}"
      output.puts "  STRUCT OFFSET PROBE  (offsets: #{P2Finder::STRUCT_OFFSETS.map { |o| '+0x%02X' % o }.join(', ')})"
      output.puts "═" * 72

      struct_results.each do |anchor_label, verifications|
        output.puts "\n  Anchored at #{anchor_label}:"
        output.printf "    %-8s  %-7s  %-6s  %-8s  %-5s  %s\n",
                      "ADDRESS", "CORR", "MONO%", "AVG_Δ", "DIR_Δ", "RANGE"
        output.puts "    " + "─" * 52
        verifications.each do |v|
          output.printf "    0x%05X  %+.4f  %5.1f%%  %8.3f  %5d  %d..%d\n",
                        v.address, v.correlation, v.monotonicity,
                        v.avg_delta, v.direction_changes,
                        v.min_value, v.max_value
        end
      end
    end

    private_class_method def self.print_cross_validation(cv_results, output)
      output.puts "\n#{"═" * 72}"
      output.puts "  LEFT / RIGHT CROSS-VALIDATION"
      output.puts "  True P2 coordinate: corr_left ≈ −corr_right  (antisymmetric)"
      output.puts "═" * 72

      output.printf "  %-8s  %-7s  %-6s  %-7s  %-7s  %-6s  %-6s  %s\n",
                    "ADDRESS", "CORR_L", "MONO_L", "RNG_L",
                    "CORR_R", "MONO_R", "RNG_R", "ANTISYM"
      output.puts "  " + "─" * 70

      cv_results.each do |r|
        flag = r.antisymmetric ? "✓ YES" : "✗ no"
        output.printf "  0x%05X  %+.4f  %5.1f%%  %6d  %+.4f  %5.1f%%  %6d  %s\n",
                      r.address,
                      r.corr_left,  r.mono_left,  r.range_left,
                      r.corr_right, r.mono_right, r.range_right,
                      flag
      end

      confirmed = cv_results.select(&:antisymmetric)
      unless confirmed.empty?
        output.puts "\n  Antisymmetric candidates (likely P2 coordinates):"
        confirmed.each do |r|
          output.printf "    0x%05X  corr_left=%+.4f  corr_right=%+.4f  range=%d/%d\n",
                        r.address, r.corr_left, r.corr_right,
                        r.range_left, r.range_right
        end
      end
    end

    private_class_method def self.print_top_confirmed(scan_results, output)
      top = scan_results.select(&:confirmed).first(5)
      return if top.empty?

      output.puts "\n#{"═" * 72}"
      output.puts "  TOP CONFIRMED — detail"
      output.puts "═" * 72
      top.each do |v|
        output.puts "\n  0x%05X  u16le  corr=%+.4f  mono=%.1f%%  dir_Δ=%d" %
                    [v.address, v.correlation, v.monotonicity, v.direction_changes]
        output.puts "    min=#{v.min_value}  max=#{v.max_value}  range=#{v.max_value - v.min_value}"
        output.puts "    first #{SAMPLE_N}: [#{v.values.first(SAMPLE_N).join(', ')}]"
        output.puts "    last  #{SAMPLE_N}: [#{v.values.last(SAMPLE_N).join(', ')}]"
        output.puts "    CSV: #{v.csv_path}"
      end

      output.puts "\n#{"═" * 72}"
    end
  end
end
