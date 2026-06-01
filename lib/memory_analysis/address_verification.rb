module MemoryAnalysis
  AddressVerification = Data.define(
    :address,           # Integer — WRAM offset
    :category,          # Symbol  — :p1_x, :explicit_u16le, etc.
    :sequence,          # String  — dump subdirectory used
    :width,             # Symbol  — :u8 or :u16le
    :values,            # Array<Integer> — one value per frame
    :motion_rate,       # Float   — % of frames where value changed
    :monotonicity,      # Float   — % of pairs in the dominant direction
    :avg_delta,         # Float   — mean absolute frame-to-frame change
    :delta_variance,    # Float   — variance of absolute deltas
    :direction_changes, # Integer — sign flips among non-zero deltas
    :unique_values,     # Integer — distinct values in the sequence
    :min_value,         # Integer — minimum value in the sequence
    :max_value,         # Integer — maximum value in the sequence
    :correlation,       # Float   — Pearson r with frame number (−1..1)
    :frame_count,       # Integer — number of frames analysed
    :csv_path,          # String  — path to the written CSV file
    :confirmed,         # Boolean
    :rejection_reason   # String or nil
  )
end
